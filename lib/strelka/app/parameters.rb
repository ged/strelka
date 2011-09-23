#!/usr/bin/env ruby

require 'strelka' unless defined?( Strelka )
require 'strelka/app' unless defined?( Strelka::App )

# Parameter declaration for Strelka::Apps
module Strelka::App::Parameters
	extend Strelka::App::Plugin

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


end # module Strelka::App::Parameters


