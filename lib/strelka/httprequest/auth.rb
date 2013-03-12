#!/usr/bin/env ruby

require 'strelka/constants'
require 'strelka/httprequest' unless defined?( Strelka::HTTPRequest )


# The mixin that adds methods to Strelka::HTTPRequest for
# authentication/authorization.
module Strelka::HTTPRequest::Auth
	include Strelka::Constants


	### Extension callback -- add instance variables to extended objects.
	def initialize( * )
		super
		@authenticated_user = nil
	end


	######
	public
	######

	# The current session namespace
	attr_accessor :authenticated_user
	alias_method :authenticated?, :authenticated_user


end # module Strelka::HTTPRequest::Auth


