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
				@session = request.session
			else
				self.log.debug "No session loaded in the request; creating it in the response."
				sessionclass = Strelka::App::Sessions.session_class
				@session = sessionclass.load_or_create( self.request )
				@session.namespace = self.session_namespace
				request.session = @session
			end
		end

		return @session
	end


	### Set the request's session object.
	def session=( new_session )
		new_session.namespace = self.session_namespace
		@session = new_session
		request.session = new_session
	end


	### Returns +true+ if the response already has an associated session object.
	def session?
		return @session || self.request.session?
	end


	### Tell the associated session to save itself and set up the session ID in the
	### response, if one exists.
	def save_session
		if self.session?
			session = self.session
			self.log.debug "Saving session: %p" % [ @session ]
			session.save( self )
		else
			self.log.debug "No session to save."
		end
	end

end # module Strelka::HTTPResponse::Session

