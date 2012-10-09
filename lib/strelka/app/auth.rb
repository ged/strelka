# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
#encoding: utf-8

require 'loggability'

require 'strelka' unless defined?( Strelka )
require 'strelka/app' unless defined?( Strelka::App )
require 'strelka/plugins'

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
# The provider for an application can be specified in the Configurability config file
# under the 'auth' section:
#
#     ---
#     auth:
#       provider: basic
#
#
# == Applying Authentication
#
# The default authentication policy is to require authentication from every
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
# along as-is. A String will match the path exactly, with any leading or trailing
# '/' characters removed, and a Regexp will be tested against the \#app_path as-is.
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
# auth process comes into play: Authorization.
#
# The AuthProvider you're using may provide some form of general
# authorization itself (especially a custom one), but typically
# authorization is particular to an application and even particular
# actions within the application.
#
# To facilitate mapping out what actions are available to whom, there is a
# declaration similar to require_auth_for that can define a set of permissions
# that are necessary for a request to be allowed:
#
#    # The app ID, which is the default permission
#    ID = 'gemserver'
#
#    # GET /app/admin/upload/install would require:
#    #   :gemserver, :admin, :upload, and :install
#    # permissions. What those mean is up to the AuthProvider.
#    require_perms_for ''
#    require_perms_for %r{^/admin.*}, :admin
#    require_perms_for %r{/upload}, :upload
#    require_perms_for %r{/install}, :install
#
# and its negative corollary:
#
#    no_perms_for '/login'
#
# Incoming requests are matched against +require_perms_for+ patterns, and the union
# of all matching permissions is gathered, then any +no_auth_for+ patterns
# are used to remove permissions from that set.
#
# If no require_perms_for patterns are declared, authorization is not checked, unless there is
# at least one no_perms_for pattern, in which case all requests that don't match the negative
# patterns are checked (with the permission set to the ID of the app).
#
# Authorization will be checked once authentication has succeeded. It will be called with at least the
# credentials object returned from the authentication stage and the request object. Some AuthProviders
# may opt to return authentication credentials as a User object of some kind (e.g., a database row,
# LDAP entry, model object, etc.), but the simpler ones just return the login of the authenticated
# +user+. The AuthProvider may also furnish additional useful arguments such as a database handle,
# permission objects, etc. to your authorization block. See the documentation for your chosen
# AuthProvider for details.
#
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
# the browser to go to a static HTML form instead using the <tt>:errors</tt> plugin:
#
#    class FormAuthApp < Strelka::App
#        plugins :errors, :auth, :sessions
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
module Strelka::App::Auth
	extend Strelka::Plugin,
	       Strelka::MethodUtilities,
	       Loggability,
		   Configurability
	include Strelka::Constants

	# Loggability API -- set up logging under the 'strelka' log host
	log_to :strelka

	# Configurability API -- configure the auth plugin via the 'auth' section of the config
	config_key :auth

	# Plugins API -- Set up load order
	run_before :routing, :restresources
	run_after  :templating, :errors, :sessions


	# The name of the default plugin to use for authentication
	DEFAULT_AUTH_PROVIDER = :hostaccess

	# Configuration defaults
	CONFIG_DEFAULTS = {
		provider: DEFAULT_AUTH_PROVIDER,
	}



	##
	# The Array of apps that have had the auth plugin installed; this is used to
	# set up the AuthProvider when the configuration loads later.
	singleton_attr_accessor :extended_apps
	self.extended_apps = []


	### Configurability API -- configure the Auth plugin via the 'auth' section of the
	### unified config.
	def self::configure( config=nil )
		if config && config[:provider]
			self.log.debug "Setting up the %p AuthProvider for apps: %p" %
				[ config[:provider], self.extended_apps ]
			self.extended_apps.each {|app| app.auth_provider = config[:provider] }
		else
			self.log.warn "Setting up the default AuthProvider for apps %p" % [ self.extended_apps ]
			self.extended_apps.each {|app| app.auth_provider = DEFAULT_AUTH_PROVIDER }
		end
	end


	# Class methods to add to app classes that enable Auth
	module ClassMethods

		### Extension callback -- register objects that are extended so when the
		### auth plugin is configured, it can set the configured auto provider.
		def self::extended( obj )
			super
			Strelka::App::Auth.extended_apps << obj
			obj.auth_provider = Strelka::App::Auth::DEFAULT_AUTH_PROVIDER
		end


		@auth_provider           = nil

		@positive_auth_criteria  = {}
		@negative_auth_criteria  = {}

		@positive_perms_criteria = {}
		@negative_perms_criteria = {}


		##
		# The Strelka::AuthProvider subclass that will be used to provide authentication and
		# authorization to instances of the app.
		attr_reader :auth_provider

		##
		# Hashes of criteria for applying and skipping auth for a request, keyed by request pattern
		attr_reader :positive_auth_criteria, :negative_auth_criteria

		##
		# Hashes of criteria for applying and skipping authorization for a request, keyed by request pattern
		attr_reader :positive_perms_criteria, :negative_perms_criteria


		### Extension callback -- add instance variables to extending objects.
		def inherited( subclass )
			super
			Strelka::App::Auth.extended_apps << subclass
			subclass.instance_variable_set( :@auth_provider, @auth_provider )
			subclass.instance_variable_set( :@positive_auth_criteria, @positive_auth_criteria.dup )
			subclass.instance_variable_set( :@negative_auth_criteria, @negative_auth_criteria.dup )
			subclass.instance_variable_set( :@positive_perms_criteria, @positive_perms_criteria.dup )
			subclass.instance_variable_set( :@negative_perms_criteria, @negative_perms_criteria.dup )
		end


		### Get/set the AuthProvider for the app to +type+, where +type+ can be an AuthProvider
		### class object or the name of one.
		def auth_provider=( type )
			@auth_provider = Strelka::AuthProvider.get_subclass( type )
			self.log.debug "Auth provider set to %p" % [ @auth_provider ]
			return @auth_provider
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

		### :call-seq:
		###   require_auth_for( string )
		###   require_auth_for( regexp )
		###   require_auth_for { |request| ... }
		###   require_auth_for( string ) { |request| ... }
		###   require_auth_for( regexp ) { |request, matchdata| ... }
		###
		### Constrain authentication to apply only to requests whose
		### {#app_path}[rdoc-ref:Strelka::HTTPRequest#app_path] matches
		### the given +string+ or +regexp+, and/or for which the given +block+ returns
		### a true value. +regexp+ patterns are matched as-is, and +string+ patterns are
		### matched exactly via <tt>==</tt> after stripping leading and trailing '/' characters
		### from both it and the #app_path.
		### *NOTE:* using this declaration inverts the default security policy of
		### restricting access to all requests.
		def require_auth_for( *criteria, &block )
			if self.has_negative_auth_criteria?
				raise ScriptError,
					"defining both positive and negative auth criteria is unsupported."
			end

			criteria << nil if criteria.empty?
			block ||= Proc.new { true }

			criteria.each do |pattern|
				pattern.gsub!( %r{^/+|/+$}, '' ) if pattern.respond_to?( :gsub! )
				self.log.debug "  adding require_auth for %p" % [ pattern ]
				self.positive_auth_criteria[ pattern ] = block
			end
		end


		### :call-seq:
		###   no_auth_for( string )
		###   no_auth_for( regexp )
		###   no_auth_for { |request| ... }
		###   no_auth_for( string ) { |request| ... }
		###   no_auth_for( regexp ) { |request, matchdata| ... }
		###
		### Constrain authentication to apply to requests *except* those whose
		### {#app_path}[rdoc-ref:Strelka::HTTPRequest#app_path] matches
		### the given +string+ or +regexp+, and/or for which the given +block+ returns
		### a true value.
		def no_auth_for( *criteria, &block )
			if self.has_positive_auth_criteria?
				raise ScriptError,
					"defining both positive and negative auth criteria is unsupported."
			end

			criteria << nil if criteria.empty?
			block ||= Proc.new { true }

			criteria.each do |pattern|
				pattern.gsub!( %r{^/+|/+$}, '' ) if pattern.respond_to?( :gsub! )
				self.log.debug "  adding no_auth for %p" % [ pattern ]
				self.negative_auth_criteria[ pattern ] = block
			end
		end


		### Constrain authorization to apply only to requests which match the given
		### +pattern+. The +pattern+ is either a String or a Regexp which is tested against
		### {the request's #app_path}[rdoc-ref:Strelka::HTTPRequest#app_path]. The +perms+ should
		### be Symbols which indicate a set of permission types that must have been granted
		### in order to carry out the request. The block should also return one or more
		### permissions (as Symbols) if the request should undergo authorization, or nil
		### if it should not.
		### *NOTE:* using this declaration inverts the default security policy of
		### restricting access to all requests.
		def require_perms_for( pattern=nil, *perms, &block )
			block ||= Proc.new { perms }

			pattern.gsub!( %r{^/+|/+$}, '' ) if pattern.respond_to?( :gsub! )
			self.log.debug "  adding require_perms (%p) for %p" % [ perms, pattern ]
			self.positive_perms_criteria[ pattern ] = block
		end


		### Register one or more exceptions to the permissions policy in effect for
		### requests whose {#app_path}[rdoc-ref:Strelka::HTTPRequest#app_path]
		### matches the specified +pattern+. The +block+ form should return +true+ if the request
		### it's called with should be allowed without authorization checks.
		def no_perms_for( pattern=nil, &block )
			raise LocalJumpError, "no block or pattern given" unless pattern || block

			block   ||= Proc.new { true }
			pattern ||= /(?##{block.object_id})/

			pattern.gsub!( %r{^/+|/+$}, '' ) if pattern.respond_to?( :gsub! )
			self.log.debug "  adding no_auth for %p" % [ pattern ]
			self.negative_perms_criteria[ pattern ] = block
		end

	end # module ClassMethods


	### Extension callback -- extend the HTTPRequest class with Auth
	### support when this plugin is loaded.
	def self::included( object )
		self.log.debug "Extending Request with Auth mixin"
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
		self.log.debug "[:auth] Wrapping request in auth with a %p" % [ self.auth_provider ]

		self.authenticate_and_authorize( request )

		super
	end


	### Process authentication and authorization for the specified +request+.
	def authenticate_and_authorize( request )
		credentials = nil
		credentials = self.provide_authentication( request ) if self.request_should_auth?( request )
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
	### The +credentials+ argument is the opaque return value from a valid authentication, or
	### +nil+ if the request didn't require authentication.
	def provide_authorization( credentials, request )
		provider = self.auth_provider
		perms = self.required_perms_for( request )
		self.log.debug "Perms required: %p" % [ perms ]
		provider.authorize( credentials, request, perms ) unless perms.empty?
	end


	### Returns +true+ if the given +request+ requires authentication.
	def request_should_auth?( request )
		self.log.debug "Checking to see if Auth(entication/orization) should be applied for app_path: %p" %
			[ request.app_path ]

		# If there are positive criteria, return true if the request matches any of them,
		# or false if they don't
		if self.class.has_positive_auth_criteria?
			criteria = self.class.positive_auth_criteria
			self.log.debug "  checking %d positive auth criteria" % [ criteria.length ]
			return criteria.any? do |pattern, block|
				self.request_matches_criteria( request, pattern, &block )
			end
			return false

		# If there are negative criteria, return false if the request matches any of them,
		# or true if they don't
		elsif self.class.has_negative_auth_criteria?
			criteria = self.class.negative_auth_criteria
			self.log.debug "  checking %d negative auth criteria" % [ criteria.length ]
			return false if criteria.any? do |pattern, block|
				rval = self.request_matches_criteria( request, pattern, &block )
				self.log.debug "    matched: %p -> %p" % [ pattern, block ] if rval
				rval
			end
			return true

		else
			self.log.debug "  no auth criteria; default to requiring auth"
			return true
		end
	end


	### Return a permission Symbol derived from the app's ID.
	def default_permission
		return self.app_id.downcase.gsub(/\W+/, '_' ).to_sym
	end


	### Gather the set of permissions that apply to the specified +request+ and return
	### them.
	def required_perms_for( request )
		self.log.debug "Gathering required perms for: %s %s" % [ request.verb, request.app_path ]

		# Return the empty set if any negative auth criteria match
		return [] if self.negative_perms_criteria_match?( request )

		# If there aren't any positive criteria, default to requiring authorization with
		# the app's ID as the permission
		if self.class.positive_perms_criteria.empty?
			return [ self.default_permission ]
		end

		# Apply positive auth criteria
		return self.union_positive_perms_criteria( request )
	end


	#########
	protected
	#########

	### Returns +true+ if there are positive auth criteria and the +request+ matches
	### at least one of them.
	def request_matches_criteria( request, pattern )
		self.log.debug "Testing request '%s %s' against pattern: %p" %
			[ request.verb, request.app_path, pattern ]

		case pattern
		when nil
			self.log.debug "  no pattern; calling the block"
			return yield( request )

		when Regexp
			self.log.debug "  checking app_path with regexp: %p" % [ pattern ]
			matchdata = pattern.match( request.app_path ) or return false
			self.log.debug "  matched: calling the block"
			return yield( request, matchdata )

		when String
			self.log.debug "  checking app_path: %p" % [ pattern ]
			request.app_path.gsub( %r{^/+|/+$}, '' ) == pattern or return false
			self.log.debug "  matched: calling the block"
			return yield( request )

		else
			raise ScriptError, "don't know how to match a request with a %p" % [ pattern.class ]
		end
	end


	### Returns +true+ if the +request+ matches at least one negative perms criteria
	### whose block also returns +true+ when called.
	def negative_perms_criteria_match?( request )
		self.log.debug "  negative perm criteria: %p" % [ self.class.negative_perms_criteria ]
		return self.class.negative_perms_criteria.any? do |pattern, block|
			self.request_matches_criteria( request, pattern, &block )
		end
	end


	### Find all positive perm criteria, calling each one's block with +request+ if its
	### pattern matches +path+, and assembling a union of all the permission sets
	### that result.
	def union_positive_perms_criteria( request )
		perms = []

		self.log.debug "  positive perm criteria: %p" % [ self.class.positive_perms_criteria ]
		self.class.positive_perms_criteria.each do |pattern, block|
			newperms = self.request_matches_criteria( request, pattern, &block ) or next
			newperms = Array( newperms )
			newperms << self.default_permission if newperms.empty?

			raise TypeError, "Permissions must be Symbols; got: %p" % [newperms] unless
				newperms.all? {|perm| perm.is_a?(Symbol) }

			self.log.debug "  found new perms: %p" % [ newperms ]
			perms += newperms
		end

		return perms.compact.uniq
	end


end # module Strelka::App::Auth


