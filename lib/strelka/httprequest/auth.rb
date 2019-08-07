# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# frozen-string-literal: true

require 'strelka/constants'
require 'strelka/httprequest' unless defined?( Strelka::HTTPRequest )


# The mixin that adds methods to Strelka::HTTPRequest for
# authentication/authorization.
module Strelka::HTTPRequest::Auth
	include Strelka::Constants


	### Extension callback -- add instance variables to extended objects.
	def initialize( * )
		super
		@auth_provider = nil
		@authenticated_user = nil
	end


	######
	public
	######

	# The current session namespace
	attr_accessor :authenticated_user
	alias_method :authenticated?, :authenticated_user

	# The Strelka::AuthProvider the app uses for authentication (if any)
	attr_accessor :auth_provider


	### Try to authenticate the request using the specified +block+. If a +block+ is not provided,
	### the #authenticate method of the app's AuthProvider is used instead.
	###
	### Valid +options+ are:
	###
	### [+:optional+]  if this is set to a true value, don't throw a 401 Requires Authentication
	###                if the authentication fails.
	###
	def authenticate( options={}, &block )
		block ||= self.auth_provider.method( :authenticate )
		result = block.call( self )

		finish_with( HTTP::UNAUTHORIZED, "Authorization failed" ) unless result || options[:optional]
		self.authenticated_user = result

		return result
	end


	### Try to check authorization using the specified +block+.  If a +block+ is not
	### provided, the #authorize method of the app's AuthProvider is used instead.
	### If the request doesn't already have an +authenticated_user+ set,
	### #authenticate will be called with no arguments to try to provide one.
	### The provided +perms+ are passed either to the block or the AuthProvider if
	### no block is given. If successful, the authenticated user that was used is returned.
	def authorize( *perms, &block )
		if block
			results = block.call or
				finish_with( HTTP::FORBIDDEN, "You are not authorized to access this resource." )
			return results
		else
			self.log.debug "Deferred authorization via %p" % [ self.auth_provider ]
			credentials = self.authenticated_user || self.authenticate
			self.auth_provider.authorize( credentials, self, perms )
			return credentials
		end
	end

end # module Strelka::HTTPRequest::Auth


