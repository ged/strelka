# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

#encoding: utf-8

require 'uri'
require 'forwardable'
require 'date'
require 'formvalidator'

require 'strelka/mixins'
require 'strelka' unless defined?( Strelka )
require 'strelka/app' unless defined?( Strelka::App )


# A validator for user parameters.
#
# == Usage
#
#   require 'strelka/app/formvalidator'
#
#	# Profile specifies validation criteria for input
#	profile = {
#     :required		=> :name,
#     :optional		=> [:email, :description],
#     :filters		=> [:strip, :squeeze],
#     :untaint_all_constraints => true,
#     :descriptions	=> {
#       :email          => "Customer Email",
#       :description    => "Issue Description",
#       :name           => "Customer Name",
#     },
#     :constraints  => {
#       :email  => :email,
#       :name   => /^[\x20-\x7f]+$/,
#       :description => /^[\x20-\x7f]+$/,
#     },
#	}
#
#	# Create a validator object and pass in a hash of request parameters and the
#	# profile hash.
#   validator = Strelka::ParamValidator.new
#	validator.validate( req_params, profile )
#
#	# Now if there weren't any errors, send the success page
#	if validator.okay?
#		return success_template
#
#	# Otherwise fill in the error template with auto-generated error messages
#	# and return that instead.
#	else
#		failure_template.errors( validator.error_messages )
#		return failure_template
#	end
#
class Strelka::ParamValidator < ::FormValidator
	extend Forwardable
	include Strelka::Loggable


	# Validation default config
	DEFAULT_PROFILE = {
		:descriptions => {},
	}

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

	# Pattern for countint the number of hash levels in a parameter key
	PARAMS_HASH_RE = /^([^\[]+)(\[.*\])?(.)?.*$/

	# The Hash of builtin constraints that are validated against a regular
	# expression.
	BUILTIN_CONSTRAINT_PATTERNS = {
		:boolean      => /^(?<boolean>t(?:rue)?|y(?:es)?|[10]|no?|f(?:alse)?)$/i,
		:integer      => /^(?<integer>[\-\+]?\d+)$/,
		:float        => /^(?<float>[\-\+]?(?:\d*\.\d+|\d+)(?:e[\-\+]?\d+)?)$/i,
		:alpha        => /^(?<alpha>[[:alpha:]]+)$/,
		:alphanumeric => /^(?<alphanumeric>[[:alnum:]]+)$/,
		:printable    => /\A(?<printable>[[:print:][:blank:]\r\n]+)\z/,
		:string       => /\A(?<string>[[:print:][:blank:]\r\n]+)\z/,
		:word         => /^(?<word>[[:word:]]+)$/,
		:email        => /^(?<email>#{RFC822_EMAIL_ADDRESS})$/,
		:hostname     => /^(?<hostname>#{RFC1738_HOSTNAME})$/,
		:uri          => /^(?<uri>#{URI::URI_REF})$/,
	}


	### Return a Regex for the built-in constraint associated with the given +name+. If
	### the builtin constraint is not pattern-based, or there is no such constraint,
	### returns +nil+.
	def self::pattern_for_constraint( name )
		return BUILTIN_CONSTRAINT_PATTERNS[ name.to_sym ]
	end


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Create a new Strelka::ParamValidator object.
	def initialize( profile, params=nil )
		@form                = {}
		@raw_form            = {}
		@profile             = DEFAULT_PROFILE.merge( profile )
		@invalid_fields      = []
		@missing_fields      = []
		@unknown_fields      = []
		@required_fields     = []
		@require_some_fields = []
		@optional_fields     = []
		@filters_array       = []
		@untaint_fields      = []

		@parsed_params       = nil

		self.validate( params ) if params
	end


	### Copy constructor.
	def initialize_copy( original )
		@form                = @form.clone
		@raw_form            = @form.clone
		@profile             = @profile.clone
		@invalid_fields      = @invalid_fields.clone
		@missing_fields      = @missing_fields.clone
		@unknown_fields      = @unknown_fields.clone
		@required_fields     = @required_fields.clone
		@require_some_fields = @require_some_fields.clone
		@optional_fields     = @optional_fields.clone
		@filters_array       = @filters_array.clone
		@untaint_fields      = @untaint_fields.clone

		@parsed_params       = @parsed_params.clone if @parsed_params
	end



	######
	public
	######

	# The raw form data Hash
	attr_reader :raw_form

	# The validated form data Hash
	attr_reader :form


	### Stringified description of the validator
	def to_s
		"%d parameters (%d valid, %d invalid, %d missing)" % [
			self.raw_form.size,
			self.form.size,
			self.invalid.size,
			self.missing.size,
		]
	end


	### Hash of field descriptions
	def descriptions
		return @profile[:descriptions]
	end


	### Set hash of field descriptions
	def descriptions=( new_descs )
		return @profile[:descriptions] = new_descs
	end


	### Validate the input in +params+. If the optional +additional_profile+ is
	### given, merge it with the validator's default profile before validating.
	def validate( params, additional_profile=nil )
		@raw_form = params.dup
		profile = @profile

		if additional_profile
			self.log.debug "Merging additional profile %p" % [additional_profile]
			profile = @profile.merge( additional_profile )
		end

		super( params, profile )
	end


	### Overridden to remove the check for extra keys.
	def check_profile_syntax( profile )
	end


	### Index operator; fetch the validated value for form field +key+.
	def []( key )
		return @form[ key.to_s ]
	end


	### Index assignment operator; set the validated value for form field +key+
	### to the specified +val+.
	def []=( key, val )
		return @form[ key.to_s ] = val
	end


	### Returns +true+ if there were no arguments given.
	def empty?
		return @form.empty?
	end


	### Returns +true+ if there were arguments given.
	def args?
		return !@form.empty?
	end
	alias_method :has_args?, :args?


	### Returns +true+ if any fields are missing or contain invalid values.
	def errors?
		return !self.okay?
	end
	alias_method :has_errors?, :errors?


	### Return +true+ if all required fields were present and validated
	### correctly.
	def okay?
		return (self.missing.empty? && self.invalid.empty?)
	end


	### Returns +true+ if the given +field+ is one that should be untainted.
	def untaint?( field )
		self.log.debug "Checking to see if %p should be untainted." % [field]
		rval = ( @untaint_all ||
			@untaint_fields.include?(field) ||
			@untaint_fields.include?(field.to_sym) )

		if rval
			self.log.debug "  ...yep it should."
		else
			self.log.debug "  ...nope; untaint fields is: %p" % [ @untaint_fields ]
		end

		return rval
	end


	### Overridden so that the presence of :untaint_constraint_fields doesn't
	### disable the :untaint_all_constraints flag.
	def untaint_all_constraints
		@untaint_all = @profile[:untaint_all_constraints] ? true : false
	end



	### Return an array of field names which had some kind of error associated
	### with them.
	def error_fields
		return self.missing | self.invalid.keys
	end


	### Get the description for the specified field.
	def get_description( field )
		return @profile[:descriptions][ field.to_s ] if
			@profile[:descriptions].key?( field.to_s )

		desc = field.to_s.
			gsub( /.*\[(\w+)\]/, "\\1" ).
			gsub( /_(.)/ ) {|m| " " + m[1,1].upcase }.
			gsub( /^(.)/ ) {|m| m.upcase }
		return desc
	end


	### Return an error message for each missing or invalid field; if
	### +includeUnknown+ is +true+, also include messages for unknown fields.
	def error_messages( include_unknown=false )
		self.log.debug "Building error messages from descriptions: %p" %
			[ @profile[:descriptions] ]
		msgs = []
		self.missing.each do |field|
			msgs << "Missing value for '%s'" % self.get_description( field )
		end

		self.invalid.each do |field, constraint|
			msgs << "Invalid value for '%s'" % self.get_description( field )
		end

		if include_unknown
			self.unknown.each do |field|
				msgs << "Unknown parameter '%s'" % self.get_description( field )
			end
		end

		return msgs
	end


	### Returns a distinct list of missing fields. Overridden to eliminate the
	### "undefined method `<=>' for :foo:Symbol" error.
	def missing
		@missing_fields.uniq.sort_by {|f| f.to_s}
	end

	### Returns a distinct list of unknown fields.
	def unknown
		(@unknown_fields - @invalid_fields.keys).uniq.sort_by {|f| f.to_s}
	end


	### Returns the valid fields after expanding Rails-style
	### 'customer[address][street]' variables into multi-level hashes.
	def valid
		if @parsed_params.nil?
			@parsed_params = {}
			valid = super()

			for key, value in valid
				value = [ value ] if key.end_with?( '[]' )
				if key.include?( '[' )
					build_deep_hash( value, @parsed_params, get_levels(key) )
				else
					@parsed_params[ key ] = value
				end
			end
		end

		return @parsed_params
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
		@missing_fields.clear
		@unknown_fields.clear
		@required_fields.clear
		@invalid_fields.clear
		@untaint_fields.clear
		@require_some_fields.clear
		@optional_fields.clear
		@form.clear

		newparams = @raw_form.merge( params )
		@raw_form.clear

		self.log.debug "  merged raw form is: %p" % [ newparams ]
		self.validate( newparams )
	end


	### Returns an array containing valid parameters in the validator corresponding to the
	### given +selector+(s).
	def values_at( *selector )
		selector.map!( &:to_s )
		return @form.values_at( *selector )
	end


	#
	# :section: Constraint methods
	#

	### Try to match the specified +val+ using the built-in constraint pattern
	### associated with +name+, returning the matched value upon success, and +nil+
	### if the +val+ didn't match. If a +block+ is given, it's called with the
	### associated MatchData on success, and its return value is returned instead of
	### the matching String.
	def match_builtin_constraint( val, name )
		self.log.debug "Validating %p using built-in constraint %p" % [ val, name ]
		re = self.class.pattern_for_constraint( name.to_sym )
		match = re.match( val ) or return nil
		self.log.debug "  matched: %p" % [ match ]

		if block_given?
			begin
				return yield( match )
			rescue ArgumentError
				return nil
			end
		else
			return match.to_s
		end
	end


	### Constrain a value to +true+ (or +yes+) and +false+ (or +no+).
	def match_boolean( val )
		return self.match_builtin_constraint( val, :boolean ) do |m|
			m.to_s.start_with?( 'y', 't', '1' )
		end
	end


	### Constrain a value to an integer
	def match_integer( val )
		return self.match_builtin_constraint( val, :integer ) do |m|
			Integer( m.to_s )
		end
	end


	### Contrain a value to a Float
	def match_float( val )
		return self.match_builtin_constraint( val, :float ) do |m|
			Float( m.to_s )
		end
	end


	### Constrain a value to a parseable Date
	def match_date( val )
		return Date.parse( val ) rescue nil
	end


	### Constrain a value to alpha characters (a-z, case-insensitive)
	def match_alpha( val )
		return self.match_builtin_constraint( val, :alpha )
	end


	### Constrain a value to alpha characters (a-z, case-insensitive and 0-9)
	def match_alphanumeric( val )
		return self.match_builtin_constraint( val, :alphanumeric )
	end


	### Constrain a value to any printable characters + whitespace, newline, and CR.
	def match_printable( val )
		return self.match_builtin_constraint( val, :printable )
	end
	alias_method :match_string, :match_printable


	### Constrain a value to any UTF-8 word characters.
	def match_word( val )
		return self.match_builtin_constraint( val, :word )
	end


	### Override the parent class's definition to (not-sloppily) match email
	### addresses.
	def match_email( val )
		return self.match_builtin_constraint( val, :email )
	end


	### Match valid hostnames according to the rules of the URL RFC.
	def match_hostname( val )
		return self.match_builtin_constraint( val, :hostname )
	end


	### Match valid URIs
	def match_uri( val )
		return self.match_builtin_constraint( val, :uri ) do |m|
			URI.parse( m.to_s )
		end
	rescue URI::InvalidURIError => err
		self.log.error "Error trying to parse URI %p: %s" % [ val, err.message ]
		return nil
	rescue NoMethodError
		self.log.debug "Ignoring bug in URI#parse"
		return nil
	end


	### Apply one or more +constraints+ to the field value/s corresponding to
	### +key+.
	def do_constraint( key, constraints )
		constraints.each do |constraint|
			case constraint
			when String
				apply_string_constraint( key, constraint )
			when Hash
				apply_hash_constraint( key, constraint )
			when Proc, Method
				apply_proc_constraint( key, constraint )
			when Regexp
				apply_regexp_constraint( key, constraint )
			else
				raise "unknown constraint type %p" % [constraint]
			end
		end
	end


	### Applies a builtin constraint to form[key].
	def apply_string_constraint( key, constraint )
		# FIXME: multiple elements
		rval = self.__send__( "match_#{constraint}", @form[key].to_s )
		self.log.debug "Tried a string constraint: %p: %p" %
			[ @form[key].to_s, rval ]
		self.set_form_value( key, rval, constraint )
	end


	### Apply a constraint given as a Hash to the value/s corresponding to the
	### specified +key+:
	###
	### constraint::
	###   A builtin constraint (as a Symbol; e.g., :email), a Regexp, or a Proc.
	### name::
	###   A description of the constraint should it fail and be listed in #invalid.
	### params::
	###   If +constraint+ is a Proc, this field should contain a list of other
	###   fields to send to the Proc.
	def apply_hash_constraint( key, constraint )
		action = constraint["constraint"]

		rval = case action
			when String
				self.apply_string_constraint( key, action )
			when Regexp
				self.apply_regexp_constraint( key, action )
			when Proc
				if args = constraint["params"]
					args.collect! {|field| @form[field] }
					self.apply_proc_constraint( key, action, *args )
				else
					self.apply_proc_constraint( key, action )
				end
			end

		# If the validation failed, and there's a name for this constraint, replace
		# the name in @invalid_fields with the name
		if !rval && constraint["name"]
			@invalid_fields[ key ] = constraint["name"]
		end

		return rval
	end


	### Apply a constraint that was specified as a Proc to the value for the given
	### +key+
	def apply_proc_constraint( key, constraint, *params )
		value = nil

		unless params.empty?
			value = constraint.to_proc.call( *params )
		else
			value = constraint.to_proc.call( @form[key] )
		end

		self.set_form_value( key, value, constraint )
	rescue => err
		self.log.error "%p while validating %p using %p: %s (from %s)" %
			[ err.class, key, constraint, err.message, err.backtrace.first ]
		self.set_form_value( key, nil, constraint )
	end


	### Applies regexp constraint to form[key]
	def apply_regexp_constraint( key, constraint )
		self.log.debug "Validating %p via regexp %p" % [ @form[key], constraint ]

		if match = constraint.match( @form[key].to_s )
			self.log.debug "  matched %p" % [match[0]]

			if match.captures.empty?
				self.log.debug "  no captures, using whole match: %p" % [match[0]]
				self.set_form_value( key, match[0], constraint )
			elsif match.names.length > 1
				self.log.debug "  extracting hash of named captures: %p" % [ match.names ]
				hash = match.names.inject( {} ) do |accum,name|
					accum[ name.to_sym ] = match[ name ]
					accum
				end

				self.set_form_value( key, hash, constraint )
			elsif match.captures.length == 1
				self.log.debug "  extracting one capture: %p" % [match.captures.first]
				self.set_form_value( key, match.captures.first, constraint )
			else
				self.log.debug "  extracting multiple captures: %p" % [match.captures]
				self.set_form_value( key, match.captures, constraint )
			end
		else
			self.set_form_value( key, nil, constraint )
		end
	end


	### Set the form value for the given +key+. If +value+ is false, add it to
	### the list of invalid fields with a description derived from the specified
	### +constraint+.
	def set_form_value( key, value, constraint )
		key.untaint

		# Have to test for nil because valid values might be false.
		if !value.nil?
			self.log.debug "Setting form value for %p to %p (constraint was %p)" %
				[ key, value, constraint ]
			if self.untaint?( key )
				if value.respond_to?( :each_value )
					value.each_value( &:untaint )
				elsif value.is_a?( Array )
					value.each( &:untaint )
				else
					value.untaint
				end
			end

			@form[key] = value
			return true

		else
			self.log.debug "Clearing form value for %p (constraint was %p)" %
				[ key, constraint ]
			@form.delete( key )
			@invalid_fields ||= {}
			@invalid_fields[ key ] ||= []

			unless @invalid_fields[ key ].include?( constraint )
				@invalid_fields[ key ].push( constraint )
			end
			return false
		end
	end


	### Formvalidator hack:
	### The formvalidator filters method has a bug where he assumes an array
	###	 when it is in fact a string for multiple values (ie anytime you have a
	###	 text-area with newlines in it).
	def filters
		@filters_array = Array(@profile[:filters]) unless(@filters_array)
		@filters_array.each do |filter|

			if respond_to?( "filter_#{filter}" )
				@form.keys.each do |field|
					# If a key has multiple elements, apply filter to each element
					@field_array = Array( @form[field] )

					if @field_array.length > 1
						@field_array.each_index do |i|
							elem = @field_array[i]
							@field_array[i] = self.send("filter_#{filter}", elem)
						end
					else
						if not @form[field].to_s.empty?
							@form[field] = self.send("filter_#{filter}", @form[field].to_s)
						end
					end
				end
			end
		end
		@form
	end


	#######
	private
	#######

	### Overridden to eliminate use of default #to_a (deprecated)
	def strify_array( array )
		array = [ array ] if !array.is_a?( Array )
		array.map do |m|
			m = (Array === m) ? strify_array(m) : m
			m = (Hash === m) ? strify_hash(m) : m
			Symbol === m ? m.to_s : m
		end
	end


	### Build a deep hash out of the given parameter +value+
	def build_deep_hash( value, hash, levels )
		if levels.length == 0
			value.untaint
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
			return [key.untaint]
		elsif bracketed
			return [main.untaint] + bracketed.slice(1...-1).split('][').collect {|k| k.untaint }
		else
			return [main.untaint]
		end
	end

end # class Strelka::ParamValidator



