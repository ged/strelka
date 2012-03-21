# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
#encoding: utf-8

require 'strelka' unless defined?( Strelka )
require 'strelka/app' unless defined?( Strelka::App )

require 'strelka/authprovider'


# Pluggable authentification for Strelka applications.
#
# Enabling the ':auth' plugin by default causes all requests to your handler to
# go through an authentification provider first. This provider checks the request
# for the necessary credentials, then either forwards it on if sufficient
# conditions are met, or responds with the appropriate 4xx status response.
#
# The conditions are broken down into two stages:
#
# * Authentication -- the client is who they say they are
# * Authorization -- the client is allowed to access the resources in question
#
# Auth providers are plugins that are named +Strelka::AuthProvider::<MyType>+, and
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
# === Relaxing Auth for A Few Methods
#
# Sometimes you want to expose just one or two resources to the world, say in the
# case of a REST API that includes the authentication endpoint. Obviously, clients
# can't be authenticated until after they send their request that authenticates
# them, so you can expose just the +/login+ URI by using the 'no_auth_for' directive:
#
#     class MyService < Strelka::App
#
#         plugins :auth
#
#         no_auth_for '/login'
#
#     end # class MyService
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
#
# === Relaxing Auth for All But a Few Methods
#
# Sometimes, though, you want just the opposite -- a few methods are available
# only to a select few, but the majority are unrestricted.
#
# To do this, use the 'require_auth_for' directive:
#
#     class MyBlog < Strelka::App
#
#         plugins :auth
#
#         require_auth_for '/admin'
#
#     end # class MyService
#
# Note that this inverts the usual behavior of the +:auth+ plugin: resources
# will, by default, be unguarded, so be sure you keep this in mind when
# using +require_auth_for+.
#
# Like +no_auth_for+, +require_auth_for+ can also take a block, and
# a true-ish return value will cause the request to pass through the
# AuthProvider.
#
# You can't use +no_auth_for+ and +require_auth_for+ in the same App; doing
# so will result in a ScriptError being raised when the App is loaded.
#
#
# == Adding Authorization
#
# Sometimes simple authentication isn't sufficient for accessing some
# resources, especially if you have some kind of permissions system that
# dictates who can see/use what. That's where the second stage of the
# authentification process comes into play: Authorization.
#
# To facilitate this, you can declare a block with the +auth_callback+
# directive.
#
#
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
#        auth_callback do |user, directory|
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
#        auth_callback do |user, db|
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
	DEFAULT_AUTH_TYPE = :passphrase


	# Class methods to add to app classes that enable Auth
	module ClassMethods

		@auth_provider = nil
		@auth_callback = nil


		### Get/set the authentication type.
		def auth_provider( type=nil )
			if type
				@auth_provider = Strelka::AuthProvider.get_subclass( type )
			elsif type.nil?
				@auth_provider ||= Strelka::AuthProvider.get_subclass( DEFAULT_AUTH_TYPE )
			end

			return @auth_provider
		end


		### Register a function to call when the user successfully authenticates
		### to check for authorization or other criteria. The arguments to the
		### function depend on which authentication plugin is used. Returning
		### +true+ from this function will cause authorization to succeed, while
		### returning a false value causes it to fail with a FORBIDDEN response.
		def auth_callback( callable=nil, &block )
			if callable
				self.auth_callback = callable
			elsif block
				self.auth_callback = block
			end

			return self.auth_callback
		end


		### Wrap methods 
		def with_authentication( &block )
			
		end
		


	end # module ClassMethods


	### Check authentication and authorization for requests that need it before
	### sending them on.
	def handle_request( request )
		self.authenticate( request ) if self.request_should_auth?( request )

		return super
	end


	### Returns +true+ if the given +request+ requires authentication.
	def request_should_auth?( request )
		
	end


	### Process authentication for the specified +request+.
	def authenticate( request )
		
	end


end # module Strelka::App::Auth


