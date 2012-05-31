#!/usr/bin/env ruby

require 'loggability'

require 'strelka' unless defined?( Strelka )
require 'strelka/app' unless defined?( Strelka::App )

require 'strelka/mixins'
require 'strelka/exceptions'
require 'strelka/plugins'

require 'strelka/httprequest/session'
require 'strelka/httpresponse/session'

# Sessions for Strelka apps
#
# This plugin adds a persistant storage mechanism to Strelka applications
# that can be used to store data about a user's session.
#
# == Examples
#
#   class HelloWorld < Strelka::App
#
#       # Use the default session store and id-generator
#       plugins :routing, :sessions
#
#       session_namespace :foo  # defaults to the app's ID
#
#       get '' do
#           finish_with HTTP::FORBIDDEN, "no session!" unless req.session?
#
#           username = req.session[:username]
#       end
#
#   end # class HelloWorld
#
# == Components
#
# This plugin is split up into four parts:
#
# [Strelka::Session]
#   The abstract base class for the session object;
#   provides the interface for getting and setting session data,
#   writing the resulting data structure to permanent storage (if
#   necessary), and generating the token that associates the request
#   with the session.
# [Strelka::HTTPRequest::Session]
#   A mixin module that's added to HTTPRequest when the :sessions plugin
#   is installed. Provides the API on HTTPRequest for fetching and
#   interacting with the Session object.
# [Strelka::HTTPResponse::Session]
#   A mixin module that's added to HTTPResponse when the :sessions plugin
#   is installed. Provides the API on HTTPResponse for fetching and
#   interacting with the Session object.
# [Strelka::App::Sessions]
#   This module; stitches the whole system together in your application.
#
# == Configuration
#
# To specify which Session class to use with your application, add a
# ':sessions' section with at least the 'type' key to your config.yml:
#
#   # Use the default session class, but change the name of the cookie
#   # it uses
#   sessions:
#     session_class: default
#
#   defaultsession:
#       cookie_name: acme-session
#
#   # Use the database-backed session type and point it
#   # at a database
#   sessions:
#     session_class: db
#
#   dbsession:
#       connect: "postgres://pg.example.com/db01"
#       table_name: sessions
#
# The +type+ value will be used to look up the class (see Strelka::Session
# for more information about how this works), and the +options+ section
# is passed to the session class's ::configure method (if it has one).
#
module Strelka::App::Sessions
	extend Strelka::Plugin,
	       Strelka::MethodUtilities,
	       Configurability,
	       Loggability
	include Strelka::Constants

	# Loggability API -- set up logging under the 'strelka' log host
	log_to :strelka

	# Configurability API -- specify which section of the config this class gets
	config_key :sessions

	# Plugins API -- Specify load order; run as late as possible so other plugins
	# can use the session
	run_after :templating, :filters, :parameters


	# Class methods and instance variables to add to classes with sessions.
	module ClassMethods # :nodoc:

		# The namespace of the session that will be exposed to instances of this
		# application
		@session_namespace = nil


		### Extension callback -- add instance variables to extending objects.
		def inherited( subclass )
			super
			subclass.instance_variable_set( :@session_namespace, @session_namespace )
		end


		### Get/set the key that will determine which namespace in the session object
		### the application will see.
		def session_namespace( new_namespace=nil )
			@session_namespace = new_namespace if new_namespace
			@session_namespace ||= self.default_appid
			return @session_namespace
		end

	end # module ClassMethods


	# Default options to pass to the session object
	CONFIG_DEFAULTS = {
		session_class: 'default',
	}


	##
	# What session class to use (String, Symbol, or Class); passed to
	# Strelka::Session.create.
	singleton_attr_reader :session_class


	### Configurability API -- set up session type and options with values from
	### the +config+.
	def self::configure( config=nil )
		# Figure out which session class is going to be used, or choose a default one
		if config
			self.session_class = config[:session_class]
		else
			self.session_class = CONFIG_DEFAULTS[:session_class]
		end

	end


	### Get the configured session class (Strelka::Session subclass)
	def self::session_class=( newclass )
		@session_class = Strelka::Session.get_subclass( newclass )
	end


	### Extension callback -- extend the HTTPRequest classes with Session
	### support when this plugin is loaded.
	def self::included( object )
		self.log.debug "Extending Request with Session mixin"
		Strelka::HTTPRequest.class_eval { include Strelka::HTTPRequest::Session }
		self.log.debug "Extending Response with Session mixin"
		Strelka::HTTPResponse.class_eval { include Strelka::HTTPResponse::Session }
		super
	end


	### Set the session namespace on the HTTPRequest before running the application.
	def fixup_request( request )
		request.session_namespace = self.class.session_namespace
		return super
	end


	### Save the session after the app and plugins are done with the HTTPResponse.
	def fixup_response( response )
		self.log.debug "Saving the session in the response."
		response.save_session
		return super
	end


	### This is just here for logging.
	def handle_request( * ) # :nodoc:
		self.log.debug "[:sessions] Adding sessions to the transaction."
		super
	end

end # module Strelka::App::Sessions


