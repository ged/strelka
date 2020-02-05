# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# frozen-string-literal: true

require 'uri'
require 'forwardable'
require 'date'
require 'loggability'

require 'strelka/mixins'
require 'strelka' unless defined?( Strelka )
require 'strelka/app' unless defined?( Strelka::App )


# A validator for user parameters.
#
# == Usage
#
#	require 'strelka/paramvalidator'
#
#	validator = Strelka::ParamValidator.new
#
#	# Add validation criteria for input parameters
#	validator.add( :name, /^(?<lastname>\S+), (?<firstname>\S+)$/, "Customer Name" )
#	validator.add( :email, "Customer Email" )
#	validator.add( :feedback, :printable, "Customer Feedback" )
#	validator.override( :email, :printable, "Your Email Address" )
#
#	# Now pass in values in a hash (e.g., from an HTML form)
#	validator.validate( req.params )
#
#	# Now if there weren't any errors, use some form values to fill out the
#	# success page template
#	if validator.okay?
#		tmpl = template :success
#		tmpl.firstname = validator[:name][:firstname]
#		tmpl.lastname  = validator[:name][:lastname]
#		tmpl.email	   = validator[:email]
#		tmpl.feedback  = validator[:feedback]
#		return tmpl
#
#	# Otherwise fill in the error template with auto-generated error messages
#	# and return that instead.
#	else
#		tmpl = template :feedback_form
#		tmpl.errors = validator.error_messages
#		return tmpl
#	end
#
class Strelka::ParamValidator
	extend Forwardable,
		   Loggability,
		   Strelka::MethodUtilities
	include Strelka::DataUtilities

	# Loggability API -- log to the 'strelka' logger
	log_to :strelka


	# Pattern for countint the number of hash levels in a parameter key
	PARAMS_HASH_RE = /^([^\[]+)(\[.*\])?(.)?.*$/

	# Pattern to use to strip binding operators from parameter patterns so they
	# can be used in the middle of routing Regexps.
	PARAMETER_PATTERN_STRIP_RE = Regexp.union( '^', '$', '\\A', '\\z', '\\Z' )



	# The base constraint type.
	class Constraint
		extend Loggability,
		       Strelka::MethodUtilities

		# Loggability API -- log to the 'strelka' logger
		log_to :strelka


		# Flags that are passed as Symbols when declaring a parameter
		FLAGS = [ :required, :multiple ]

		# Map of constraint specification types to their equivalent Constraint class.
		TYPES = { Proc => self }


		### Register the given +subclass+ as the Constraint class to be used when
		### the specified +syntax_class+ is given as the constraint in a parameter
		### declaration.
		def self::register_type( syntax_class )
			self.log.debug "Registering %p as the constraint class for %p objects" %
				[ self, syntax_class ]
			TYPES[ syntax_class ] = self
		end


		### Return a Constraint object appropriate for the given +field+ and +spec+.
		def self::for( field, spec=nil, *options, &block )
			self.log.debug "Building Constraint for %p (%p)" % [ field, spec ]

			# Handle omitted constraint
			if spec.is_a?( String ) || FLAGS.include?( spec )
				options.unshift( spec )
				spec = nil
			end

			spec ||= block

			subtype = TYPES[ spec.class ] or
				raise "No constraint type for a %p validation spec" % [ spec.class ]

			return subtype.new( field, spec, *options, &block )
		end


		### Create a new Constraint for the field with the given +name+, configuring it with the
		### specified +args+. The +block+ is what does the actual validation, at least in the
		### base class.
		def initialize( name, *args, &block )
			@name		 = name
			@block		 = block

			@description = args.shift if args.first.is_a?( String )

			@required	 = args.include?( :required )
			@multiple	 = args.include?( :multiple )
		end


		######
		public
		######

		# The name of the field the constraint governs
		attr_reader :name

		# The constraint's check block
		attr_reader :block

		# The field's description
		attr_writer :description

		##
		# Returns true if the field can have multiple values.
		attr_predicate :multiple?

		##
		# Returns true if the field associated with the constraint is required in
		# order for the parameters to be valid.
		attr_predicate :required?


		### Check the given value against the constraint and return the result if it passes.
		def apply( value )
			if self.multiple?
				return self.check_multiple( value )
			else
				return self.check( value )
			end
		end


		### Comparison operator – Constraints are equal if they’re for the same field,
		### they’re of the same type, and their blocks are the same.
		def ==( other )
			return self.name == other.name &&
				other.instance_of?( self.class ) &&
				self.block == other.block
		end


		### Get the description of the field.
		def description
			return @description || self.generate_description
		end


		### Return the constraint expressed as a String.
		def to_s
			desc = self.validator_description

			flags = []
			flags << 'required' if self.required?
			flags << 'multiple' if self.multiple?

			desc << " (%s)" % [ flags.join(',') ] unless flags.empty?

			return desc
		end


		#########
		protected
		#########

		### Return a description of the validation provided by the constraint object.
		def validator_description
			desc = 'a custom validator'

			if self.block
				location = self.block.source_location
				desc += " on line %d of %s" % [ location[1], location[0] ]
			end

			return desc
		end


		### Check the specified value against the constraint and return the results. By
		### default, this just calls to_proc and the block and calls the result with the
		### value as its argument.
		def check( value )
			return self.block.to_proc.call( value ) if self.block
			return value
		end


		### Check the given +values+ against the constraint and return the results if
		### all of them succeed.
		def check_multiple( values )
			values = [ values ] unless values.is_a?( Array )
			results = []

			values.each do |value|
				result = self.check( value ) or return nil
				results << result
			end

			return results
		end


		### Generate a description from the name of the field.
		def generate_description
			self.log.debug "Auto-generating description for %p" % [ self ]
			desc = self.name.to_s.
				gsub( /.*\[(\w+)\]/, "\\1" ).
				gsub( /_(.)/ ) {|m| " " + m[1,1].upcase }.
				gsub( /^(.)/ ) {|m| m.upcase }
			self.log.debug "  generated: %p" % [ desc ]
			return desc
		end

	end # class Constraint


	# A constraint expressed as a regular expression.
	class RegexpConstraint < Constraint

		# Use this for constraints expressed as Regular Expressions
		register_type Regexp


		### Create a new RegexpConstraint that will validate the field of the given
		### +name+ with the specified +pattern+.
		def initialize( name, pattern, *args, &block )
			@pattern = pattern

			super( name, *args, &block )
		end


		######
		public
		######

		# The constraint's pattern
		attr_reader :pattern


		### Check the +value+ against the regular expression and return its
		### match groups if successful.
		def check( value )
			self.log.debug "Validating %p via regexp %p" % [ value, self.pattern ]
			match = self.pattern.match( value.to_s ) or return nil

			if match.captures.empty?
				self.log.debug "  no captures, using whole match: %p" % [match[0]]
				return super( match[0] )

			elsif match.names.length > 1
				self.log.debug "  extracting hash of named captures: %p" % [ match.names ]
				rhash = self.matched_hash( match )
				return super( rhash )

			elsif match.captures.length == 1
				self.log.debug "  extracting one capture: %p" % [match.captures.first]
				return super( match.captures.first )

			else
				self.log.debug "  extracting multiple captures: %p" % [match.captures]
				values = match.captures
				return super( values )
			end
		end


		### Return a Hash of the given +match+ object's named captures.
		def matched_hash( match )
			return match.names.inject( {} ) do |accum,name|
				value = match[ name ]
				accum[ name.to_sym ] = value
				accum
			end
		end


		### Return the constraint expressed as a String.
		def validator_description
			return "a value matching the pattern %p" % [ self.pattern ]
		end


	end # class RegexpConstraint


	# A constraint class that uses a collection of predefined patterns.
	class BuiltinConstraint < RegexpConstraint

		# Use this for constraints expressed as Symbols or who are missing a constraint spec (nil)
		register_type Symbol
		register_type NilClass


		#
		# RFC822 Email Address Regex
		# --------------------------
		#
		# Originally written by Cal Henderson
		# c.f. http://iamcal.com/publish/articles/php/parsing_email/
		#
		# Translated to Ruby by Tim Fletcher, with changes suggested by Dan Kubb.
		#
		# Licensed under a Creative Commons Attribution-ShareAlike 2.5 License
		# http://creativecommons.org/licenses/by-sa/2.5/
		#
		RFC822_EMAIL_ADDRESS = begin
			qtext = '[^\\x0d\\x22\\x5c\\x80-\\xff]'
			dtext = '[^\\x0d\\x5b-\\x5d\\x80-\\xff]'
			atom = '[^\\x00-\\x20\\x22\\x28\\x29\\x2c\\x2e\\x3a-' +
				'\\x3c\\x3e\\x40\\x5b-\\x5d\\x7f-\\xff]+'
			quoted_pair = '\\x5c[\\x00-\\x7f]'
			domain_literal = "\\x5b(?:#{dtext}|#{quoted_pair})*\\x5d"
			quoted_string = "\\x22(?:#{qtext}|#{quoted_pair})*\\x22"
			domain_ref = atom
			sub_domain = "(?:#{domain_ref}|#{domain_literal})"
			word = "(?:#{atom}|#{quoted_string})"
			domain = "#{sub_domain}(?:\\x2e#{sub_domain})*"
			local_part = "#{word}(?:\\x2e#{word})*"
			addr_spec = "#{local_part}\\x40#{domain}"
			/\A#{addr_spec}\z/n
		end

		# Pattern for (loosely) matching a valid hostname. This isn't strictly RFC-compliant
		# because, in practice, many hostnames used on the Internet aren't.
		RFC1738_HOSTNAME = begin
			alphadigit = /[a-z0-9]/i
			# toplabel		 = alpha | alpha *[ alphadigit | "-" ] alphadigit
			toplabel = /[a-z]((#{alphadigit}|-)*#{alphadigit})?/i
			# domainlabel	 = alphadigit | alphadigit *[ alphadigit | "-" ] alphadigit
			domainlabel = /#{alphadigit}((#{alphadigit}|-)*#{alphadigit})?/i
			# hostname		 = *[ domainlabel "." ] toplabel
			hostname = /\A(#{domainlabel}\.)*#{toplabel}\z/
		end

		# Validation regexp for JSON
		# Converted to oniguruma syntax from the PCRE example at:
		#   http://stackoverflow.com/questions/2583472/regex-to-validate-json
		JSON_VALIDATOR_RE = begin
			pair     = ''

			json     = /^
				(?<json> \s* (?:
					# number
					(?: 0 | -? [1-9]\d* (?:\.\d+)? (?:[eE][+-]?\d+)? )
					 |
					# boolean
					(?: true | false | null )
					 |
					# string
					"(?: [^"\\[:cntrl:]]* | \\["\\bfnrt\/] | \\u\p{XDigit}{4} )*"
					 |
					# array
					\[ (?: \g<json> (?: , \g<json> )* )? \s* \]
					 |
					# object
					\{
						(?:
							# first pair
							\s* "(?: [^"\\]* | \\["\\bfnrt\/] | \\u\p{XDigit}{4} )*" \s* : \g<json>
							# following pairs
						    (?: , \s* "(?: [^"\\]* | \\["\\bfnrt\/] | \\u\p{XDigit}{4} )*" \s* : \g<json> )*
						)?
						\s*
					\}
				) \s* )
			\z/ux
		end

		# The Hash of builtin constraints that are validated against a regular
		# expression.
		# :TODO: Document that these are the built-in constraints that can be used in a route
		BUILTIN_CONSTRAINT_PATTERNS = {
			:boolean	  => /^(?<boolean>t(?:rue)?|y(?:es)?|[10]|no?|f(?:alse)?)$/i,
			:integer	  => /^(?<integer>[\-\+]?\d+)$/,
			:float		  => /^(?<float>[\-\+]?(?:\d*\.\d+|\d+)(?:e[\-\+]?\d+)?)$/i,
			:alpha		  => /^(?<alpha>[[:alpha:]]+)$/,
			:alphanumeric => /^(?<alphanumeric>[[:alnum:]]+)$/,
			:printable	  => /\A(?<printable>[[:print:][:space:]]+)\z/,
			:string		  => /\A(?<string>[[:print:][:space:]]+)\z/,
			:word		  => /^(?<word>[[:word:]]+)$/,
			:email		  => /^(?<email>#{RFC822_EMAIL_ADDRESS})$/,
			:hostname	  => /^(?<hostname>#{RFC1738_HOSTNAME})$/,
			:uri		  => /^(?<uri>#{URI::URI_REF})$/,
			:uuid		  => /^(?<uuid>[[:xdigit:]]{8}(?:-[[:xdigit:]]{4}){3}-[[:xdigit:]]{12})$/i,
			:date         => /.*\d.*/,
			:datetime     => /.*\d.*/,
			:json         => JSON_VALIDATOR_RE,
			:md5sum       => /^(?<md5sum>[[:xdigit:]]{32})$/i,
			:sha1sum      => /^(?<sha1sum>[[:xdigit:]]{40})$/i,
			:sha256sum    => /^(?<sha256sum>[[:xdigit:]]{64})$/i,
			:sha384sum    => /^(?<sha384sum>[[:xdigit:]]{96})$/i,
			:sha512sum    => /^(?<sha512sum>[[:xdigit:]]{128})$/i,
		}

		# Field values which result in a valid ‘true’ value for :boolean constraints
		TRUE_VALUES = %w[t true y yes 1]


		#
		# Class methods
		#

		##
		# Hash of named constraint patterns
		singleton_attr_reader :constraint_patterns
		@constraint_patterns = BUILTIN_CONSTRAINT_PATTERNS.dup


		### Return true if name is the name of a built-in constraint.
		def self::valid?( name )
			return BUILTIN_CONSTRAINT_PATTERNS.key?( name.to_sym )
		end


		### Reset the named patterns to the defaults. Mostly used for testing.
		def self::reset_constraint_patterns
			@constraint_patterns.replace( BUILTIN_CONSTRAINT_PATTERNS )
		end



		#
		# Instance methods
		#

		### Create a new BuiltinConstraint using the pattern named name for the specified field.
		def initialize( field, name, *options, &block )
			name ||= field
			@pattern_name = name
			pattern = BUILTIN_CONSTRAINT_PATTERNS[ name.to_sym ] or
				raise ScriptError, "no such builtin constraint %p" % [ name ]

			super( field, pattern, *options, &block )
		end


		######
		public
		######

		# The name of the builtin pattern the field should be constrained by
		attr_reader :pattern_name


		### Check for an additional post-processor method, and if it exists, return it as
		### a Method object.
		def block
			if custom_block = super
				return custom_block
			else
				post_processor = "post_process_%s" % [ @pattern_name ]
				return nil unless self.respond_to?( post_processor, true )
				return self.method( post_processor )
			end
		end


		### Return the constraint expressed as a String.
		def validator_description
			return "a '%s'" % [ self.pattern_name ]
		end


		#########
		protected
		#########

		### Post-process a :boolean value.
		def post_process_boolean( val )
			return TRUE_VALUES.include?( val.to_s.downcase )
		end


		### Constrain a value to a parseable Date
		def post_process_date( val )
			return Date.parse( val )
		rescue ArgumentError
			return nil
		end


		### Constrain a value to a parseable Date
		def post_process_datetime( val )
			return Time.parse( val )
		rescue ArgumentError
			return nil
		end


		### Constrain a value to a Float
		def post_process_float( val )
			return Float( val.to_s )
		end


		### Post-process a valid :integer field.
		def post_process_integer( val )
			return Integer( val.to_s )
		end


		### Post-process a valid :uri field.
		def post_process_uri( val )
			return URI.parse( val.to_s )
		rescue URI::InvalidURIError => err
			self.log.error "Error trying to parse URI %p: %s" % [ val, err.message ]
			return nil
		rescue NoMethodError
			self.log.debug "Ignoring bug in URI#parse"
			return nil
		end

	end # class BuiltinConstraint



	#################################################################
	### I N S T A N C E	  M E T H O D S
	#################################################################

	### Create a new Strelka::ParamValidator object.
	def initialize
		@constraints = {}
		@fields      = {}

		self.reset
	end


	### Copy constructor.
	def initialize_copy( original )
		fields       = deep_copy( original.fields )
		self.reset
		@fields      = fields
		@constraints = deep_copy( original.constraints )
	end


	######
	public
	######

	# The constraints hash
	attr_reader :constraints

	# The Hash of raw field data (if validation has occurred)
	attr_reader :fields

	##
	# Returns +true+ if the paramvalidator has been given parameters to validate. Adding or
	# overriding constraints resets this.
	attr_predicate_accessor :validated?


	### Reset the validation state.
	def reset
		self.log.debug "Resetting validation state."
		@validated     = false
		@valid         = {}
		@parsed_params = nil
		@missing       = []
		@unknown       = []
		@invalid       = {}
	end


	### :call-seq:
	###	   add( name, *flags )
	###	   add( name, constraint, *flags )
	###	   add( name, description, *flags )
	###	   add( name, constraint, description, *flags )
	###
	### Add a validation for a parameter with the specified +name+. The +args+ can include
	### a constraint, a description, and one or more flags.
	def add( name, *args, &block )
		name = name.to_sym
		constraint = Constraint.for( name, *args, &block )

		# No-op if there's already a parameter with the same name and constraint
		if self.constraints.key?( name )
			return if self.constraints[ name ] == constraint
			raise ArgumentError,
				"parameter %p is already defined as %s; perhaps you meant to use #override?" %
					[ name.to_s, self.constraints[name] ]
		end

		self.log.debug "Adding parameter %p: %p" % [ name, constraint ]
		self.constraints[ name ] = constraint

		self.validated = false
	end


	### Replace the existing parameter with the specified name. The args replace the
	### existing description, constraints, and flags. See #add for details.
	def override( name, *args, &block )
		name = name.to_sym
		raise ArgumentError,
			"no parameter %p defined; perhaps you meant to use #add?" % [ name.to_s ] unless
			self.constraints.key?( name )

		self.log.debug "Overriding parameter %p" % [ name ]
		self.constraints[ name ] = Constraint.for( name, *args, &block )

		self.validated = false
	end


	### Return the Array of parameter names the validator knows how to validate (as Strings).
	def param_names
		return self.constraints.keys.map( &:to_s ).sort
	end


	### Stringified description of the validator
	def to_s
	    "%d parameters (%d valid, %d invalid, %d missing)" % [
	        self.fields.size,
	        self.valid.size,
	        self.invalid.size,
	        self.missing.size,
	    ]
	end


	### Return a human-readable representation of the validator, suitable for debugging.
	def inspect
		required, optional = self.constraints.partition do |_, constraint|
			constraint.required?
		end

		return "#<%p:0x%016x %s, profile: [required: %s, optional: %s]>" % [
			self.class,
			self.object_id / 2,
			self.to_s,
			required.empty? ? "(none)" : required.map( &:last ).map( &:name ).join(','),
			optional.empty? ? "(none)" : optional.map( &:last ).map( &:name ).join(','),
		]
	end


	### Hash of field descriptions
	def descriptions
		return self.constraints.each_with_object({}) do |(field,constraint), hash|
			hash[ field ] = constraint.description
		end
	end


	### Set field descriptions en masse to new_descs.
	def descriptions=( new_descs )
		new_descs.each do |name, description|
			raise NameError, "no parameter named #{name}" unless
				self.constraints.key?( name.to_sym )
			self.constraints[ name.to_sym ].description = description
		end
	end


	### Get the description for the specified +field+.
	def get_description( field )
		constraint = self.constraints[ field.to_sym ] or return nil
		return constraint.description
	end


	### Validate the input in +params+. If the optional +additional_constraints+ is
	### given, merge it with the validator's existing constraints before validating.
	def validate( params=nil, additional_constraints=nil )
		self.log.debug "Validating."
		self.reset

		# :TODO: Handle the additional_constraints

		params ||= @fields
		params = stringify_keys( params )
		@fields = deep_copy( params )

		self.log.debug "Starting validation with fields: %p" % [ @fields ]

		# Use the constraints list to extract all the parameters that have corresponding
		# constraints
		self.constraints.each do |field, constraint|
			self.log.debug "  applying %s to any %p parameter/s" % [ constraint, field ]
			value = params.delete( field.to_s )
			self.log.debug "  value is: %p" % [ value ]
			self.apply_constraint( constraint, value )
		end

		# Any left over are unknown
		params.keys.each do |field|
			self.log.debug "  unknown field %p" % [ field ]
			@unknown << field
		end

		@validated = true
	end


	### Apply the specified +constraint+ (a Strelka::ParamValidator::Constraint object) to
	### the given +value+, and add the field to the appropriate field list based on the
	### result.
	def apply_constraint( constraint, value )
		if !( value.nil? || value == '' )
			result = constraint.apply( value )

			if !result.nil?
				self.log.debug "  constraint for %p passed: %p" % [ constraint.name, result ]
				self[ constraint.name ] = result
			else
				self.log.debug "  constraint for %p failed" % [ constraint.name ]
				@invalid[ constraint.name.to_s ] = value
			end
		elsif constraint.required?
			self.log.debug "  missing parameter for %p" % [ constraint.name ]
			@missing << constraint.name.to_s
		end
	end


	### Clear existing validation information, merge the specified +params+ with any existing
	### raw fields, and re-run the validation.
	def revalidate( params={} )
		merged_fields = self.fields.merge( params )
		self.reset
		self.validate( merged_fields )
	end


	## Fetch the constraint/s that apply to the parameter named +name+ as a Regexp, if possible.
	def constraint_regexp_for( name )
		self.log.debug "  searching for a constraint for %p" % [ name ]

		# Fetch the constraint's regexp
		constraint = self.constraints[ name.to_sym ] or
			raise NameError, "no such parameter %p" % [ name ]
		raise ScriptError,
			"can't route on a parameter with a %p" % [ constraint.class ] unless
			constraint.respond_to?( :pattern )

		re = constraint.pattern
		self.log.debug "  bounded constraint is: %p" % [ re ]

		# Unbind the pattern from beginning or end of line.
		# :TODO: This is pretty ugly. Find a better way of modifying the regex.
		re_str = re.to_s.
			sub( %r{\(\?[\-mix]+:(.*)\)}, '\1' ).
			gsub( PARAMETER_PATTERN_STRIP_RE, '' )
		self.log.debug "  stripped constraint pattern down to: %p" % [ re_str ]

		return Regexp.new( "(?<#{name}>#{re_str})", re.options )
	end


	### Returns the valid fields after expanding Rails-style
	### 'customer[address][street]' variables into multi-level hashes.
	def valid
		self.validate unless self.validated?

		self.log.debug "Building valid fields hash from raw data: %p" % [ @valid ]
		unless @parsed_params
			@parsed_params = {}
			for key, value in @valid
				self.log.debug "  adding %s: %p" % [ key, value ]
				value = [ value ] if key.to_s.end_with?( '[]' )
				if key.to_s.include?( '[' )
					build_deep_hash( value, @parsed_params, get_levels(key.to_s) )
				else
					@parsed_params[ key ] = value
				end
			end
		end

		return @parsed_params
	end


	### Index fetch operator; fetch the validated (and possible parsed) value for
	### form field +key+.
	def []( key )
		self.validate unless self.validated?
		return @valid[ key.to_sym ]
	end


	### Index assignment operator; set the validated value for form field +key+
	### to the specified +val+.
	def []=( key, val )
		@parsed_params = nil
		@valid[ key.to_sym ] = val
	end


	### Returns +true+ if there were no arguments given.
	def empty?
		return self.fields.empty?
	end


	### Returns +true+ if there were arguments given.
	def args?
		return !self.fields.empty?
	end
	alias_method :has_args?, :args?


	### The names of fields that were required, but missing from the parameter list.
	def missing
		self.validate unless self.validated?
		return @missing
	end


	### The Hash of fields that were present, but invalid (didn't match the field's constraint)
	def invalid
		self.validate unless self.validated?
		return @invalid
	end


	### The names of fields that were present in the parameters, but didn't have a corresponding
	### constraint.
	def unknown
		self.validate unless self.validated?
		return @unknown
	end


	### Returns +true+ if any fields are missing or contain invalid values.
	def errors?
		return !self.okay?
	end
	alias_method :has_errors?, :errors?


	### Return +true+ if all required fields were present and all present fields validated
	### correctly.
	def okay?
		return (self.missing.empty? && self.invalid.empty?)
	end


	### Return an array of field names which had some kind of error associated
	### with them.
	def error_fields
		return self.missing | self.invalid.keys
	end


	### Return an error message for each missing or invalid field; if
	### +includeUnknown+ is +true+, also include messages for unknown fields.
	def error_messages( include_unknown=false )
		msgs = []

		msgs += self.missing_param_errors + self.invalid_param_errors
		msgs += self.unknown_param_errors if include_unknown

		return msgs
	end


	### Return an Array of error messages, one for each field missing from the last validation.
	def missing_param_errors
		return self.missing.collect do |field|
			constraint = self.constraints[ field.to_sym ] or
				raise NameError, "no such field %p!" % [ field ]
			"Missing value for '%s'" % [ constraint.description ]
		end
	end


	### Return an Array of error messages, one for each field that was invalid from the last
	### validation.
	def invalid_param_errors
		return self.invalid.collect do |field, _|
			constraint = self.constraints[ field.to_sym ] or
				raise NameError, "no such field %p!" % [ field ]
			"Invalid value for '%s'" % [ constraint.description ]
		end
	end


	### Return an Array of error messages, one for each field present in the parameters in the last
	### validation that didn't have a constraint associated with it.
	def unknown_param_errors
		self.log.debug "Fetching unknown param errors for %p." % [ self.unknown ]
		return self.unknown.collect do |field|
			"Unknown parameter '%s'" % [ field.capitalize ]
		end
	end


	### Return a new ParamValidator with the additional +params+ merged into
	### its values and re-validated.
	def merge( params )
		copy = self.dup
		copy.merge!( params )
		return copy
	end


	### Merge the specified +params+ into the receiving ParamValidator and
	### re-validate the resulting values.
	def merge!( params )
		return if params.empty?
		self.log.debug "Merging parameters for revalidation: %p" % [ params ]
		self.revalidate( params )
	end


	### Returns an array containing valid parameters in the validator corresponding to the
	### given +selector+(s).
	def values_at( *selector )
		selector.map!( &:to_sym )
		return self.valid.values_at( *selector )
	end



	#######
	private
	#######

	### Build a deep hash out of the given parameter +value+
	def build_deep_hash( value, hash, levels )
		if levels.length == 0
			value
		elsif hash.nil?
			{ levels.first => build_deep_hash(value, nil, levels[1..-1]) }
		else
			hash.update({ levels.first => build_deep_hash(value, hash[levels.first], levels[1..-1]) })
		end
	end


	### Get the number of hash levels in the specified +key+
	### Stolen from the CGIMethods class in Rails' action_controller.
	def get_levels( key )
		all, main, bracketed, trailing = PARAMS_HASH_RE.match( key ).to_a
		if main.nil?
			return []
		elsif trailing
			return [key]
		elsif bracketed
			return [main] + bracketed.slice(1...-1).split('][')
		else
			return [main]
		end
	end

end # class Strelka::ParamValidator



