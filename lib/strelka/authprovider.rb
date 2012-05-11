# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require 'pluginfactory'

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
	       Strelka::Delegation
	include PluginFactory,
	        Strelka::Constants,
	        Strelka::AbstractClass,
	        Strelka::ResponseHelpers

	# Loggability API -- set up logging under the 'strelka' log host
	log_to :strelka


	### PluginFactory API -- return the Array of directories to search for concrete
	### AuthProvider classes.
	def self::derivative_dirs
		return ['strelka/authprovider']
	end


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
	### return a credentials object if authentication is successful, or throw an auth_required
	### response if it fails.
	def authenticate( request )
		self.log.debug "No authentication provided, returning anonymous credentials."
		return 'anonymous'
	end


	### If the +callback+ is set, call it with the specified +credentials+, and +request. Override this in
	### your own AuthProvider to provide +additional_arguments+ to the +callback+, and/or to provide
	### additional generic authorization.
	def authorize( credentials, request, *additional_arguments, &callback )
		return true unless callback
		return true if callback.call( credentials, request, *additional_arguments )
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

