# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# frozen-string-literal: true

require 'strelka' unless defined?( Strelka )
require 'strelka/app' unless defined?( Strelka::App )
require 'strelka/plugins'
require 'strelka/paramvalidator'


# Parameter validation for Strelka apps.
#
# When you include the +:parameters+ plugin, you can declare valid parameters and specify
# constraints that describe what incoming values should match.
#
# == Parameter Declaration
#
# Parameters are declared using the +param+ declarative:
#
#   class UserManager < Strelka::App
#
#       plugin :parameters
#
#       param :email
#       param :id, /\d+/, "The user's numeric ID"
#       param :mode, /^\s*(?<prefix>[A-Z]{2})-(?<sku>\p{Print}+)/
#
#       # ...
#
#   end # class UserManager
#
# The first item is the parameter _key_, which corresponds to the field 'name' attribute for
# a form, or the key for JSON or YAML data.
#
# The second item is the _constraint_, which specifies what the value in that parameter should
# look like if it's valid. This can be one of several things:
#
# [a Regexp]::
#   The parameter value, as a String, is matched against the Regexp and validates if the
#   pattern matches. If the Regexp contains one match group, and the pattern matches, the
#   validated value will be the capture from that group. If it contains two or more match
#   groups, the new value is an Array of the captures from the match. If the pattern contains
#   at least one named capture group, the value will be a Hash of the captures from the named
#   capture groups. Note that you cannot intermix named and positional capture groups.
# [a Symbol]::
#   The parameter value is matched using a built-in constraint. The current built-in
#   constraints are documented in the ParamValidator API documentation. As a shortcut, if the
#   parameter's _key_ is the same as a built-in constraint, you can omit the _constraint_ from
#   the declaration.
# [a Proc or Method]::
#   The parameter (or parameters in the case where there are more than one value) are passed to
#   the given Proc, and the Proc should return what the validated value of the parameter should
#   be. If it's invalid, the Proc should raise a RuntimeError.
#
# == Parameter Routing
#
# The inclusion of this plugin also allows you to use parameters in your routes:
#
#   # :username gets validated and merged into query args; URI parameters
#   # clobber query params
#   get '/info/:username' do |req|
#       req.params.add( :id, /[XRT]\d{4}-\d{8}/ )
#       req.params.okay?
#       req.params[:username]
#       req.params.values_at( :id, :username )
#       req.params.username
#
#       req.params.error_messages
#   end
#
# [:FIXME:] Add more docs.
module Strelka::App::Parameters
	extend Strelka::Plugin

	run_outside :routing, :filters


	# Class methods to add to classes with routing.
	module ClassMethods # :nodoc:

		##
		# Default ParamValidator
		@paramvalidator = Strelka::ParamValidator.new
		attr_reader :paramvalidator


		### :call-seq:
		###    param( name, *flags )
		###    param( name, constraint, *flags )
		###    param( name, description, *flags )
		###    param( name, constraint, description, *flags )
		###
		### Declare a parameter with the specified +name+ that will be validated using the given
		### +constraint+. The +constraint+ can be any of the types supported by
		### Strelka::ParamValidator.
		def param( name, *args, &block )
			self.log.debug "New param %p" % [ name ]
			self.log.debug "  adding parameter %p to %p" % [ name, self.paramvalidator ]
			self.paramvalidator.add( name, *args, &block )
		end


		### Inheritance hook -- inheriting classes inherit their parents' parameter
		### declarations, too.
		def inherited( subclass )
			super
			subclass.instance_variable_set( :@paramvalidator, self.paramvalidator.dup )
			self.log.debug "Adding param validator: %p" % [ self.paramvalidator ]
		end

	end # module ClassMethods



	### Add a ParamValidator to the given +request+ before passing it on.
	def handle_request( request, &block )
		self.log.debug "[:parameters] Wrapping request with parameter validation."

		validator = self.class.paramvalidator.dup
		validator.validate( request.params )
		request.params = validator

		super
	end

end # module Strelka::App::Parameters


