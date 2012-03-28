# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:

require 'configurability'

require 'strelka' unless defined?( Strelka )
require 'strelka/app' unless defined?( Strelka::App )
require 'strelka/authprovider'
require 'strelka/mixins'

# HTTP Basic AuthProvider class -- a base class for RFC2617 Basic HTTP Authentication
# providers for {the Streka :auth plugin}[rdoc-ref:Strelka::App::Auth].
#
# == Configuration
#
# The configuration for this provider is read from the 'auth' section of the config, and
# may contain the following keys:
#
# [realm]::   the HTTP Basic realm. Defaults to the app's application ID
# [users]::   a Hash of username: SHA1+Base64'ed passwords
#
# An example:
#
#   --
#   auth:
#     realm: Acme Admin Console
#     users:
#       mgranger: "9d5lIumnMJXmVT/34QrMuyj+p0E="
#       jblack: "1pAnQNSVtpL1z88QwXV4sG8NMP8="
#       kmurgen: "MZj9+VhZ8C9+aJhmwp+kWBL76Vs="
#
class Strelka::AuthProvider::Basic < Strelka::AuthProvider
	include Configurability,
	        Strelka::Constants,
	        Strelka::Loggable,
	        Strelka::MethodUtilities


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Create a new Default AuthProvider.
	def initialize( * )
		super

		# Default the authentication realm to the application's ID
		@default_realm = @realm = self.app.conn.app_id
		@users = {}

		# Register this instance with Configurability
		config_key :auth
	end


	######
	public
	######

	# The authentication realm
	attr_accessor :realm

	# The Hash of users and their SHA1+Base64'ed passwords
	attr_accessor :users


	### Configurability API -- configure the auth provider instance.
	def configure( config=nil )
		if config
			self.realm = config['realm'] if config['realm']
			self.users = config['users'] if config['users']
		else
			self.realm = @default_realm
			self.users.clear
		end
	end


	# Check the authentication present in +request+ (if any) for validity, returning the
	# authenticating user's name if authentication succeeds.
	def authenticate( request )
		authheader = request.header.authorization or
			self.log_failure "No authorization header in the request."

		# Extract the credentials bit
		base64_userpass = authheader[ /^\s*Basic\s+(\S+)$/i, 1 ] or
			self.log_failure "Invalid Basic Authorization header (%p)" % [ authheader ]

		# Unpack the username and password
		credentials = base64_userpass.unpack( 'm' ).first
		self.log_failure "Malformed credentials %p" % [ credentials ] unless
			credentials.index(':')

		# Split the credentials, check for valid user
		username, password = credentials.split( ':', 2 )
		digest = self.users[ username ] or
			self.log_failure "No such user %p." % [ username ]

		# Fail if the password's hash doesn't match
		self.log_failure "Password mismatch." unless
			digest == Digest::SHA1.base64digest( password )

		# Success!
		self.log.info "Authentication for %p succeeded." % [ username ]
		return true
	end


	### Always returns true -- authentication is sufficient authorization.
	def authorize( * )
		return true
	end


	#########
	protected
	#########

	### Syntax sugar to allow returning 'false' while logging a reason for doing so.
	### Log a message at 'info' level and return false.
	def log_failure( reason )
		self.log.warn "Auth failure: %s" % [ reason ]
		header = "Basic realm=%s" % [ self.realm ]
		finish_with( HTTP::AUTH_REQUIRED, "Requires authentication.", www_authenticate: header )
	end

end # class Strelka::AuthProvider::Basic
