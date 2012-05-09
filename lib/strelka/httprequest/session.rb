#!/usr/bin/env ruby

require 'configurability'

require 'strelka/constants'
require 'strelka/session' unless defined?( Strelka::Session )
require 'strelka/httprequest' unless defined?( Strelka::HTTPRequest )


# The mixin that adds methods to Strelka::HTTPRequest for session management.
#
#   request.session?
#   request.session
#
module Strelka::HTTPRequest::Session
	extend Configurability
	include Strelka::Constants


	### Extension callback -- add instance variables to extended objects.
	def initialize( * )
		super
		@session_namespace = nil
		@session = nil
	end


	######
	public
	######

	# The current session namespace
	attr_reader :session_namespace


	### The namespace that will be used when creating a session for this request
	def session_namespace=( namespace )
		self.log.debug "Setting session namespace to %p" % [ namespace ]
		@session_namespace = namespace

		# If the session has already been created, switch its current namespace
		@session.namespace = namespace if @session
	end


	### Returns +true+ if the request has an associated session object.
	def session?
		return @session || Strelka::App::Sessions.session_class.has_session_for?( self )
	end
	alias_method :has_session?, :session?


	### Returns +true+ if the request has loaded its session.
	def session_loaded?
		return @session ? true : false
	end


	### Return the session associated with the request, creating it if necessary.
	def session
		unless @session
			@session = Strelka::App::Sessions.session_class.load_or_create( self )
			@session.namespace = self.session_namespace
		end

		return @session
	end


	### Purge the request's session from the session store.
	def destroy_session
		self.log.debug "Removing session id %s" % [ self.session.session_id ]
		Strelka::App::Sessions.session_class.delete_session_data( self.session.session_id )
		@session = nil
	end


	### Set the request's session object.
	def session=( new_session )
		new_session.namespace = self.session_namespace
		@session = new_session
	end

end # module Strelka::HTTPRequest::Session


