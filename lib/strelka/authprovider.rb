# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# frozen-string-literal: true

require 'pluggability'

require 'strelka' unless defined?( Strelka )
require 'strelka/mixins'


# This is the abstract base class for authentication and/or authorization providers
# for the {:auth plugin}[Strelka::App::Auth].
#
# To define your own authentication provider, you'll need to inherit this class (either
# directly or via a subclass), name it <tt>Strelka::AuthProvider::{Something}</tt>,
# save it in a file named <tt>strelka/authprovider/{something}.rb</tt>, and
# override the required methods.
#
# Which methods you'll need to provide implementations for depends on whether
# your provider provides *authentication*, *authorization*, or both.
#
# == Authentication Providers
#
# Authentication providers should override either one or both of the following methods,
# depending on whether they will provide authentication, authorization, or both:
#
# * #authenticate
# * #authorize
#
class Strelka::AuthProvider
	extend Loggability,
	       Pluggability,
	       Strelka::AbstractClass,
	       Strelka::Delegation

	prepend Strelka::Constants,
	        Strelka::ResponseHelpers


	# Loggability API -- set up logging under the 'strelka' log host
	log_to :strelka


	# Pluggability API -- Specify the list of prefixes to try when loading plugins
	plugin_prefixes 'strelka/authprovider'


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Create a new AuthProvider for the given +app+.
	def initialize( app )
		@app = app
	end


	######
	public
	######

	##
	# The Strelka::App that the AuthProvider belongs to.
	attr_reader :app


	### You should override this method if you want to authenticate the +request+. It should
	### return a credentials object if authentication is successful, or a false value if it fails.
	def authenticate( request )
		self.log.debug "No authentication provided, returning anonymous credentials."
		return 'anonymous'
	end


	### Callback for auth success; the auth provider should use this to add cookies, headers, or
	### whatever to the request or response when the client becomes authenticated. This is a no-op
	### by default.
	def auth_succeeded( request, credentials )
		self.log.info "Authentication for %p succeeded." % [ credentials ]
		# No-op by default
	end


	### You should override this method if you want to provide authorization in your
	### provider. The +credentials+ will be the same object as the one returned by #authenticate,
	### the +request+ is the current Strelka::HTTPRequest, and +perms+ is the Array of Symbols
	### the represents the permissions that apply to the request as specified by the
	### application's +require_perms_for+ and +no_perms_for+ declarations, as an Array of
	### Symbols.
	###
	### The default behavior is to throw an 403 FORBIDDEN response if any +perms+ were
	### required.
	def authorize( credentials, request, perms )
		return true if perms.empty?
		self.require_authorization
	end


	#########
	protected
	#########

	### Throw a 401 (Unauthorized) response with the specified +challenge+ as the
	### www-Authenticate header.
	def require_authentication( challenge )
		finish_with( HTTP::AUTH_REQUIRED, "Requires authentication.", www_authenticate: challenge )
	end


	### Throw a 403 (Forbidden) response with the specified +message+.
	def require_authorization( message="You are not authorized to access this resource." )
		finish_with( HTTP::FORBIDDEN, message )
	end


end # class Strelka::AuthProvider

