# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
#encoding: utf-8

require 'strelka' unless defined?( Strelka )
require 'strelka/app' unless defined?( Strelka::App )

require 'strelka/httprequest/auth'
require 'strelka/authprovider'


# Pluggable authentication and authorization for Strelka applications.
#
# Enabling the +:auth+ plugin by default causes all requests to your
# handler to go through an authentication and authorization provider
# first. This provider checks the request for the necessary credentials,
# then either forwards it on if sufficient conditions are met, or
# responds with the appropriate 4xx status response.
#
# The conditions are broken down into two stages:
#
# * Authentication -- the client is who they say they are
# * Authorization -- the client is allowed to access the resources in question
#
# Auth providers are plugins that are named <tt>Strelka::AuthProvider::<MyType></tt>, and
# inherit from Strelka::AuthProvider. In order for them to be discoverable, each one
# should be in a file named <tt>lib/strelka/authprovider/<mytype>.rb</tt>. They
# can implement one or both of the stages; see the API docs for Strelka::AuthProvider
# for details on how to write your own plugin.
#
#
# == Applying Authentication
#
# The default authentication policy is to require authentification from every
# request, but sometimes you may wish to narrow the restrictions a bit.
#
# === Relaxing \Auth for A Few Methods
#
# Sometimes you want to expose just one or two resources to the world, say in the
# case of a REST API that includes the authentication endpoint. Obviously, clients
# can't be authenticated until after they send their request that authenticates
# them, so you can expose just the +/login+ URI by using the 'no_auth_for' directive:
#
#     class MyService < Strelka::App
#         plugins :auth
#         no_auth_for '/login'
#
#         # ...
#     end
#
# A String or a Regexp argument will be used to match against the request's
# {#app_path}[rdoc-ref:Strelka::HTTPRequest#app_path] (the path of the request
# URI with the Mongrel2 route omitted), and any requests which match are sent
# along as-is.
#
# If you require some more-complex criteria for determining if the request should
# skip the auth plugin, you can provide a block to +no_auth_for+ instead.
#
#     # Allow requests from 'localhost' without auth, but require it from
#     # everywhere else
#     no_auth_for do |request|
#         return 'internal-user' if request.header.x_forwarded_for == '127.0.0.1'
#     end
#
# If the block returns a true-ish value, it will be used in the place of the
# authenticated username and the request will be handed to your app.
#
# Returning a false-ish value will go ahead with the rest of the auth
# processing.
#
# You can also combine String and Regexp arguments with a block to further refine
# the conditions:
#
#     # Allow people to visit the seminar registration view without an account
#     # if there are still slots open
#     no_auth_for( '/register' ) do |request|
#         if Seminars.any? {|seminar| !seminar.full? }
#             'register'
#         else
#
#         end
#     end
#
#
# === Relaxing \Auth for All But a Few Methods
#
# Sometimes, though, you want just the opposite -- a few methods are available
# only to a select few, but the majority are unrestricted.
#
# To do this, use the 'require_auth_for' directive:
#
#     class MyBlog < Strelka::App
#         plugins :auth
#         require_auth_for '/admin'
#
#         # ...
#     end
#
# Note that this inverts the usual behavior of the +:auth+ plugin: resources
# will, by default, be unguarded, so be sure you keep this in mind when
# using +require_auth_for+.
#
# Like +no_auth_for+, +require_auth_for+ can also take a block, and
# a true-ish return value will cause the request to pass through the
# AuthProvider.
#
# You can't use +no_auth_for+ and +require_auth_for+ in the same application; doing
# so will result in a ScriptError being raised when the application is loaded.
#
#
# == Adding Authorization
#
# Sometimes simple authentication isn't sufficient for accessing some
# resources, especially if you have some kind of permissions system that
# dictates who can see/use what. That's where the second stage of the
# authentification process comes into play: Authorization.
#
# The AuthProvider you're using may provide some form of general authorization
# itself (especially a custom one), but typically authorization is particular to an application and
# even particular actions within the application.
#
# To provide the particulars for your app's authorization, you can declare
# a block with the +authz_callback+ directive.
#
#    authz_callback do |request, user, *other_auth_info|
#        user.can?( request.app_path )
#    end
#
# The block will be called once authentication has succeeded, and any general authorization has been
# checked. It will be called with at least the credentials object returned from the authentication
# stage and the request object. Some AuthProviders may opt to return authentication credentials
# as a User object of some kind (e.g., a database row, LDAP entry, model object, etc.), but the
# simpler ones just return the login of the authenticated +user+. The AuthProvider may also
# furnish additional useful arguments such as a database handle, permission objects, etc. to your
# authorization block. See the documentation for your chosen AuthProvider for details.
#
# == Customizing Failure
#
# As mentioned before, an authentication or authorization failure results in a
# 4xx status response. By default Strelka will present this back to the
# browser as a simple error response, but oftentimes you will want to customize
# it to look a little nicer, or to behave in a more-intuitive way.
# The easiest way to do this is to use the {:errors}[rdoc-ref:Strelka::App::Errors]
# plugin.
#
# === Redirecting to a Form
#
# If you're using form-based session authentication (as opposed to basic
# auth, which has its own UI), you can rewrite the response to instruct
# the browser to go to a static HTML form instead:
#
#    class FormAuthApp < Strelka::App
#        plugins :errors, :auth, :sessions
#        auth_provider :session
#
#        on_status HTTP::AUTH_REQUIRED do |res, status|
#            formuri = res.request.uri
#            formuri.path = '/loginform.html'
#
#            res.reset
#            res.status = HTTP::SEE_OTHER
#            res.content_type = 'text/plain'
#            res.puts "This resource requires authentication."
#            res.header.location = formuri
#
#            return res
#        end
#    end
#
# === Responding With a Form
#
# With the addition of the {:templating}[rdoc-ref:Strelka::App::Templating] plugin,
# you can respond with the form directly instead:
#
#    class TemplateFormAuthApp < Strelka::App
#        plugins :auth, :errors, :templating
#        auth_provider :session
#
#        layout 'examples/layout.tmpl'
#        templates \
#            form: 'examples/auth-form.tmpl',
#            success: 'examples/auth-success.tmpl'
#
#        on_status HTTP::AUTH_REQUIRED, :form
#
#        ### Handle any (authenticated) HTTP request
#        def handle_request( req )
#            return :success
#        end
#
#    end
#
# == Examples
#
# Here are a few more examples using a few different AuthProviders.
#
#    # Guard every request the app does behind a simple passphrase
#    class MyGuardedApp < Strelka::App
#        plugins :auth
#
#        auth_provider :passphrase
#    end
#
#    # Require LDAP authentication for one route
#    class MyGuardedApp < Strelka::App
#        plugins :auth, :routing
#
#        auth_provider :ldap
#        authz_callback do |user, request, directory|
#            authgroup = directory.ou( :appperms ).cn( :guarded_app )
#            authgroup.members.include?( user.dn )
#        end
#
#        authenticated %r{^/admin}
#    end
#
#    # Use a user table in a PostgreSQL database for authentication for
#    # all routes except one
#    class MyGuardedApp < Strelka::App
#        plugins :auth
#
#        auth_provider :sequel
#        authz_callback do |user, request, db|
#            db[:permissions].filter( :user_id => user[:id] ).
#                filter( :permname => 'guardedapp' )
#        end
#
#        unauthenticated %r{^/auth}
#
#        # Only authenticated users can use this
#        post '/servers' do
#            # ...
#        end
#    end
#
module Strelka::App::Auth
	extend Strelka::App::Plugin,
	       Strelka::MethodUtilities,
	       Configurability
	include Strelka::Loggable,
	        Strelka::Constants

	run_before :routing, :restresources
	run_after  :templating, :errors, :sessions


	# The name of the default plugin to use for authentication
	DEFAULT_AUTH_PROVIDER = :hostaccess


	# Class methods to add to app classes that enable Auth
	module ClassMethods

		@auth_provider          = nil
		@authz_callback          = nil
		@positive_auth_criteria = {}
		@negative_auth_criteria = {}

		##
		# Arrays of criteria for applying and skipping auth for a request.
		attr_reader :positive_auth_criteria, :negative_auth_criteria


		### Get/set the authentication type.
		def auth_provider( type=nil )
			if type
				@auth_provider = Strelka::AuthProvider.get_subclass( type )
			elsif type.nil?
				@auth_provider ||= Strelka::AuthProvider.get_subclass( DEFAULT_AUTH_PROVIDER )
			end

			return @auth_provider
		end


        ### Register a function to call after the user successfully authenticates to check
        ### for authorization or other criteria.  The arguments to the function depend on
        ### which authentication plugin is used. Returning +true+ from this function will
        ### cause authorization to succeed, while returning a false value causes it to fail
        ### with a FORBIDDEN response.  If no callback is set, and the provider doesn't
        ### provide authorization
		def authz_callback( callable=nil, &block )
			if callable
				@authz_callback = callable
			elsif block
				@authz_callback = block
			end

			return @authz_callback
		end


		### Returns +true+ if there are any criteria for determining whether or
		### not a request needs auth.
		def has_auth_criteria?
			return self.has_positive_auth_criteria? || self.has_negative_auth_criteria?
		end


		### Returns +true+ if the app has been set up so that only some methods
		### require auth.
		def has_positive_auth_criteria?
			return !self.positive_auth_criteria.empty?
		end


		### Returns +true+ if the app has been set up so that all methods but
		### ones that match declared criteria require auth.
		def has_negative_auth_criteria?
			return !self.negative_auth_criteria.empty?
		end


		### Constrain auth to apply only to requests which match the given +criteria+,
		### and/or the given +block+. The +criteria+ are either Strings or Regexps
		### which are tested against
		### {the request's #app_path}[rdoc-ref:Strelka::HTTPRequest#app_path]. The block
		### should return a true-ish value if the request should undergo authentication
		### and authorization.
		### *NOTE:* using this declaration inverts the default security policy of
		### restricting access to all requests.
		def require_auth_for( *criteria, &block )
			if self.has_negative_auth_criteria?
				raise ScriptError,
					"defining both positive and negative auth criteria is unsupported."
			end

			criteria << '' if criteria.empty?
			block ||= Proc.new { true }

			criteria.each do |pattern|
				self.positive_auth_criteria[ pattern ] = block
			end
		end


		### Contrain auth to apply to all requests *except* those that match the
		### given +criteria+.
		def no_auth_for( *criteria, &block )
			if self.has_positive_auth_criteria?
				raise ScriptError,
					"defining both positive and negative auth criteria is unsupported."
			end

			criteria << '' if criteria.empty?
			block ||= Proc.new { true }

			criteria.each do |pattern|
				self.negative_auth_criteria[ pattern ] = block
			end
		end


	end # module ClassMethods


	### Extension callback -- extend the HTTPRequest class with Auth
	### support when this plugin is loaded.
	def self::included( object )
		Strelka.log.debug "Extending Request with Auth mixin"
		Strelka::HTTPRequest.class_eval { include Strelka::HTTPRequest::Auth }
		super
	end


	### Add an AuthProvider instance to the app.
	def initialize( * )
		super
		@auth_provider = self.class.auth_provider.new( self )
	end


	######
	public
	######

	# The instance of (a subclass of) Strelka::AuthProvider that provides authentication
	# logic for the app.
	attr_reader :auth_provider


	### Check authentication and authorization for requests that need it before
	### sending them on.
	def handle_request( request, &block )
		self.log.debug "AuthProvider: %p" % [ self.auth_provider ]

		self.authenticate_and_authorize( request ) if self.request_should_auth?( request )

		super
	end


	#########
	protected
	#########

	### Returns +true+ if the given +request+ requires authentication.
	def request_should_auth?( request )
		self.log.debug "Checking to see if Auth(entication/orization) should be applied for %p" %
			[ request.app_path ]

		# If there are positive criteria, return true if the request matches any of them,
		# or false if they don't
		if self.class.has_positive_auth_criteria?
			criteria = self.class.positive_auth_criteria
			self.log.debug "  checking %d positive auth criteria" % [ criteria.length ]
			return criteria.any? do |pattern, block|
				self.log.debug "    %p -> %p" % [ pattern, block ]
				self.request_matches_criteria( request, pattern, &block )
			end

		# If there are negative criteria, return false if the request matches any of them,
		# or true if they don't
		elsif self.class.has_negative_auth_criteria?
			criteria = self.class.negative_auth_criteria
			self.log.debug "  checking %d negative auth criteria" % [ criteria.length ]
			return !criteria.any? do |pattern, block|
				self.log.debug "    %p -> %p" % [ pattern, block ]
				self.request_matches_criteria( request, pattern, &block )
			end

		else
			self.log.debug "  no auth criteria; default to requiring auth"
			return true
		end
	end


	### Returns +true+ if there are positive auth criteria and the +request+ matches
	### at least one of them.
	def request_matches_criteria( request, pattern )
		case pattern
		when Regexp
			self.log.debug "  matching app_path with regexp: %p" % [ pattern ]
			matchdata = pattern.match( request.app_path ) or return false
			self.log.debug "  calling the block"
			return yield( request, matchdata )

		when String
			self.log.debug "  matching app_path prefix: %p" % [ pattern ]
			request.app_path.start_with?( pattern ) or return false
			self.log.debug "  calling the block"
			return yield( request )

		else
			raise ScriptError, "don't know how to match a request with a %p" % [ pattern.class ]
		end
	end


	### Process authentication and authorization for the specified +request+.
	def authenticate_and_authorize( request )
		credentials = self.provide_authentication( request )
		request.authenticated_user = credentials
		self.provide_authorization( credentials, request )
	end


	### If the AuthProvider does authentication, try to extract authenticated credentials
	### from the +request+ and return them, throwing a :finish with
	### a properly-constructed 401 (Auth required) response if that fails.
	def provide_authentication( request )
		provider = self.auth_provider
		self.log.info "Authenticating request using provider: %p" % [ provider ]
		return provider.authenticate( request )
	end


	### Process authorization for the given +credentials+ and +request+.
	def provide_authorization( credentials, request )
		provider = self.auth_provider
		callback = self.class.authz_callback

		self.log.info "Authorizing using credentials: %p, callback: %p" % [ credentials, callback ]
		provider.authorize( credentials, request, &callback )
	end

end # module Strelka::App::Auth


