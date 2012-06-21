# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require 'strelka/constants'
require 'strelka/exceptions'
require 'strelka/httpresponse' unless defined?( Strelka::HTTPResponse )


# The mixin that adds methods to Strelka::HTTPResponse for session persistance.
# If you create a response via the Request#response method, the session will
# added to the response as well, and automatically saved after the handler and
# all plugins have run. Or you can do so manually:
#
#    response = request.response
#    response.save_session
#
# You can also clear the session with #destroy_session.
#
#
#
module Strelka::HTTPResponse::Session
	include Strelka::Constants


	### Initialize instance variables for session data in the response.
	def initialize( * )
		super
		@session = nil
		@session_namespace = nil
	end


	######
	public
	######

	# The current session namespace
	attr_reader :session_namespace


	### The namespace that will be used when creating a session for this response
	def session_namespace=( namespace )
		self.log.debug "Setting session namespace to %p" % [ namespace ]
		@session_namespace = namespace

		# If the session has already been created, switch its current namespace
		@session.namespace = namespace if @session
	end


	### Return the session associated with the response, creating it if necessary.
	def session
		unless @session
			# Load the session from the associated request if there is one.
			# If there isn't an associated request, this will just create a
			# new blank session.
			if self.request.session?
				self.log.debug "Getting the request's session."
				self.session = request.session
			else
				self.log.debug "No session loaded in the request; creating it in the response."
				self.session = Strelka::App::Sessions.session_class.new
			end
		end

		return @session
	end


	### Set the request's session object.
	def session=( new_session )
		self.log.debug "Setting session to %p in namespace %p" % [ new_session, self.session_namespace ]
		new_session.namespace = self.session_namespace
		@session = new_session
		self.log.debug "  session is: %p" % [ @session ]
		# request.session = new_session # should it set the session in the request too?
	end


	### Returns +true+ if the response already has an associated session object.
	def session?
		return @session || self.request.session?
	end
	alias_method :has_session?, :session?


	### Returns +true+ if the response or its request has already loaded the session.
	def session_loaded?
		return @session || self.request.session_loaded?
	end


	### Purge the response's session from the session store and expire its ID.
	def destroy_session
		if self.session?
			self.log.debug "Destroying session: %p" % [ self.session ]
			self.session.destroy( self )
			self.request.session = @session = nil
		else
			self.log.debug "No session to destroy."
		end
	end


	### Tell the associated session to save itself and set up the session ID in the
	### response, if one exists.
	def save_session
		if self.session_loaded?
			self.log.debug "Saving session: %p" % [ self.session ]
			self.session.save( self )
		else
			self.log.debug "No session to save."
		end
	end

end # module Strelka::HTTPResponse::Session

