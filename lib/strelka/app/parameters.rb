#!/usr/bin/env ruby

require 'strelka' unless defined?( Strelka )
require 'strelka/app' unless defined?( Strelka::App )
require 'strelka/app/plugins'
require 'strelka/app/paramvalidator'


# Parameter validation and untainting for Strelka apps.
#
# The application can declare parameters globally, and then override them on a
# per-route basis:
# 
# 	class UserManager < Strelka::App
# 
#       plugins :routing, :parameters
# 
# 		param :username, /\w+/, "User login", :required
#       param :email
# 		param :id, /\d+/, "The user's numeric ID"
#       param :mode, ['add', 'remove']
# 
# 		# :username gets validated and merged into query args; URI parameters
# 		# clobber query params
# 		get '/info/:username', :params => { :id => /[XRT]\d{4}-\d{8}/ } do |req|
# 			req.params.okay?
# 			req.params[:username]
# 			req.params.values_at( :id, :username )
# 			req.params.username
# 
# 			req.params.error_messages
# 		end
# 
# 	end # class UserManager
# 
#
# == To-Do
# 
# _We may add support for other ways of passing parameters later,
# e.g., via structured entity bodies like JSON, XML, YAML, etc_.
# 
# 
module Strelka::App::Parameters
	extend Strelka::App::Plugin

	run_before :routing
	run_after :filters


	### Class methods to add to classes with routing.
	module ClassMethods

		# Pattern for matching route parameters
		PARAMETER_PATTERN = %r{/:(?<paramname>[a-z]\w*)}i

		# Param defaults
		PARAMETER_DEFAULT_OPTIONS = {
			:constraint  => //,
			:required    => false,
			:description => nil,
		}

		# Options that are passed as Symbols to .param
		FLAGS = [ :required, :untaint ]


		# Default parameters hash
		@parameters = {}
		@untaint_all_constraints = false

		# The hash of declared parameters
		attr_reader :parameters

		# The flag for untainting constrained parameters that match their constraints
		attr_writer :untaint_all_constraints


		### Declare a parameter with the specified +name+ that will be validated using the given
		### +constraint+. The +constraint+ can be any of the types supported by 
		### Strelka::App::ParamValidator.
		### :call-seq:
		#   param( name, *flags )
		#   param( name, constraint, *flags )
		#   param( name, description, *flags )
		#   param( name, constraint, description, *flags )
		def param( name, *args )
			Strelka.log.debug "New param %p" % [ name ]
			name = name.to_sym

			# Consume the arguments
			constraint = args.shift unless args.first.is_a?( String ) || FLAGS.include?( args.first )
			constraint ||= name
			description = args.shift if args.first.is_a?( String )
			# description ||= name.to_s.capitalize
			flags = args

			# Give a regexp constraint a named capture group for the constraint name if it 
			# doesn't already have one
			if constraint.is_a?( Regexp )
				constraint = Regexp.compile( "(?<#{name}>" + constraint.to_s + ")" ) unless
					constraint.names.include?( name.to_s )
				Strelka.log.debug "  regex constraint is: %p" % [ constraint ]
			end

			# Merge the param into the parameters hash
			options = PARAMETER_DEFAULT_OPTIONS.dup
			options[ :constraint ]  = constraint
			options[ :description ] = description
			options[ :required ]    = true if flags.include?( :required )
			options[ :untaint ]     = true if flags.include?( :untaint )
			Strelka.log.debug "  param options are: %p" % [ options ]

			self.parameters[ name ] = options
		end


		### Get/set the untainting flag. If set, all parameters which match their constraints
		### will also be untainted.
		def untaint_all_constraints( newval=nil )
			Strelka.log.debug "Untaint all constraints: %p:%p" % [ newval, @untaint_all_constraints ]
			@untaint_all_constraints = newval unless newval.nil?
			return @untaint_all_constraints
		end


		### Inheritance hook -- inheriting classes inherit their parents' parameter
		### declarations, too.
		def inherited( subclass )
			super
			subclass.instance_variable_set( :@parameters, self.parameters.dup )
		end

	end # module ClassMethods



	### Add a ParamValidator to the given +request+ before passing it on.
	def handle_request( request, &block )
		profile = self.make_validator_profile( request )
		self.log.debug "Applying validator profile: %p" % [ profile ]
		validator = Strelka::App::ParamValidator.new( profile, request.params )
		self.log.debug "  validator: %p" % [ validator ]

		request.params = validator
		super
	end



	### Make a validator profile for Strelka::App::ParamValidator for the specified
	### +request+ using the declared parameters in the App, returning it as a Hash.
	def make_validator_profile( request )
		profile = {
			:required     => [],
			:optional     => [],
			:descriptions => {},
			:constraints  => {},
			:untaint_constraint_fields => [],
			:untaint_all_constraints => self.class.untaint_all_constraints,
		}
		return self.class.parameters.inject( profile ) do |accum, (name, opts)|
			self.log.debug "  adding parameter: %p: %p" % [ name, opts ]
			if opts[:required]
				accum[:required] << name
			else
				accum[:optional] << name
			end

			accum[:untaint_constraint_fields] << name if opts[:untaint]
			accum[:descriptions][ name ] = opts[:description] if opts[:description]
			accum[:constraints][ name ] = opts[:constraint]

			accum
		end
	end


end # module Strelka::App::Parameters


