# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require 'strelka' unless defined?( Strelka )
require 'strelka/app' unless defined?( Strelka::App )
require 'strelka/app/plugins'
require 'strelka/paramvalidator'


# Parameter validation and untainting for Strelka apps.
#
# The application can declare parameters globally, and then override them on a
# per-route basis:
#
#   class UserManager < Strelka::App
#
#       plugins :routing, :parameters
#
#       param :username, /\w+/, "User login", :required
#       param :email
#       param :id, /\d+/, "The user's numeric ID"
#       param :mode, ['add', 'remove']
#
#       # :username gets validated and merged into query args; URI parameters
#       # clobber query params
#       get '/info/:username', :params => { :id => /[XRT]\d{4}-\d{8}/ } do |req|
#           req.params.okay?
#           req.params[:username]
#           req.params.values_at( :id, :username )
#           req.params.username
#
#           req.params.error_messages
#       end
#
#   end # class UserManager
#
module Strelka::App::Parameters
	extend Strelka::App::Plugin

	run_before :routing
	run_after :filters


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
		def param( name, *args )
			Strelka.log.debug "New param %p" % [ name ]
			self.paramvalidator.add( name, *args )
		end


		### Get/set the untainting flag. If set, all parameters which match their constraints
		### will also be untainted.
		def untaint_all_constraints( newval=nil )
			self.paramvalidator.untaint_all = newval unless newval.nil?
			return self.paramvalidator.untaint_all?
		end


		### Inheritance hook -- inheriting classes inherit their parents' parameter
		### declarations, too.
		def inherited( subclass )
			super
			subclass.instance_variable_set( :@paramvalidator, self.paramvalidator.dup )
		end

	end # module ClassMethods



	### Add a ParamValidator to the given +request+ before passing it on.
	def handle_request( request, &block )
		self.log.debug "  cloning the class's validator: %p" % [ self.class.paramvalidator ]
		validator = self.class.paramvalidator.dup
		self.log.debug "  duplicated validator: %p" % [ validator ]
		validator.validate( request.params )

		self.log.debug "  replacing raw params hash with validator: %p" % [ validator ]
		request.params = validator

		super
	end

end # module Strelka::App::Parameters


