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
# 		param :username, /\w+/, :required, :untaint
# 		param :id, /\d+/
# 
# 		# :username gets validated and merged into query args; URI parameters
# 		# clobber query params
# 		get '/info/:username', :params => { :id => /[XRT]\d{4}-\d{8}/ } do |req|
# 			req.params.okay?
# 			req.params[:username]
# 			req.params.values_at( :id, :username )
# 			req.params.username
# 
# 			req.error_messages
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
			:untaint     => false,
			:description => nil,
		}


		# Default parameters hash
		@parameters = {}

		# The hash of declared parameters
		attr_reader :parameters


		### Declare a parameter with the specified +name+ that will be validated using the given
		### +regexp+.
		def param( name, regexp=nil, *flags )
			Strelka.log.debug "New param %p" % [ name ]
			name = name.to_sym

			regexp = Regexp.compile( "(?<#{name}>" + regexp.to_s + ")" ) unless
				regexp.names.include?( name.to_s )
			Strelka.log.debug "  param constraint is: %p" % [ regexp ]

			options = PARAMETER_DEFAULT_OPTIONS.dup
			options[ :constraint ] = regexp
			options[ :required ]   = true if flags.include?( :required )
			options[ :untaint ]    = true if flags.include?( :untaint )
			Strelka.log.debug "  param options are: %p" % [ options ]

			self.parameters[ name ] = options
		end


		### Inheritance hook -- inheriting classes inherit their parents' parameter
		### declarations, too.
		def inherited( subclass )
			super
			subclass.instance_variable_set( :@parameters, self.parameters.dup )
		end

	end # module ClassMethods



	### Add a ParamValidator to the given +request+ before passing it on.
	def handle_request( request )
		profile = self.make_validator_profile( self.class.parameters )
		validator = Strelka::App::ParamValidator.new( profile )
	end

end # module Strelka::App::Parameters


