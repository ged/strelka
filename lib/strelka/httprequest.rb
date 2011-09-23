#!/usr/bin/env ruby

require 'uri'

require 'mongrel2/httprequest'
require 'strelka' unless defined?( Strelka )

# An HTTP request class.
class Strelka::HTTPRequest < Mongrel2::HTTPRequest
	include Strelka::Loggable,
	        Strelka::Constants

	# Set Mongrel2 to use Strelka's request class for HTTP requests
	register_request_type( self, *HTTP::RFC2616_VERBS )


	### Initialize some additional stuff for Strelka requests.
	def initialize( * ) # :notnew:
		super
		@uri = nil
		@verb = self.headers[:method].to_sym
	end


	######
	public
	######

	# The HTTP verb of the request (as a Symbol)
	attr_accessor :verb


	### Return a URI object parsed from the URI of the request.
	def uri
		return @uri ||= URI( self.headers.uri )
	end


	### Return the portion of the Request's path that was routed by Mongrel2. This and the
	### #app_path make up the #path.
	def pattern
		return self.headers.pattern
	end


	### Return the portion of the Request's path relative to the application's
	### Mongrel2 route.
	def app_path
		return self.path[ self.pattern.length .. -1 ]
	end

end # class Strelka::HTTPRequest
