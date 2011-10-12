#!usr/bin/env ruby

require 'strelka/httpresponse'
require 'strelka/exceptions'


# The mixin that adds methods to Strelka::HTTPResponse for content-negotiation.
# 
#    response = request.response
#    response.for( 'text/html' ) {...}
#    response.for( :json ) {...}
#    response.for_encoding( :en ) {...}
#    response.for_language( :en ) {...}
#
# If the response was created from a request, it also knows whether or not it
# is acceptable according to its request's `Accept*` headers.
#
module Strelka::HTTPResponse::Negotiation

	######
	public
	######

	### Return true if the receiver satisfies all of its originating request's
	### Accept* headers, or it has no originating request.
	def acceptable?
		req = self.request or return true
		raise Strelka::PluginError, "request doesn't include Negotiation" unless
			req.respond_to?( :accepts? )

		return self.acceptable_content_type? &&
		       self.acceptable_charset? &&
		       self.acceptable_language? &&
		       self.acceptable_encoding?
	end
	alias_method :is_acceptable?, :acceptable?


	### Returns true if the content-type of the response is set to a
	### mediatype that was designated as acceptable by the originating
	### request, or if there was no originating request.
	def acceptable_content_type?
		req = self.request or return true
		return req.accepts?( self.content_type )
	end
	alias_method :has_acceptable_content_type?, :acceptable_content_type?


	### Returns true if the receiver's #charset is set to a value that was
	### designated as acceptable by the originating request, or if there
	### was no originating request.
	def acceptable_charset?
		req = self.request or return true
		return req.accepts_charset?( self.charset )
	end
	alias_method :has_acceptable_charset?, :acceptable_charset?


	### Returns true if at least one of the receiver's #languages is set
	### to a value that was designated as acceptable by the originating
	### request, if there was no originating request, or if no #languages
	### have been set.
	def acceptable_language?
		req = self.request or return true
		return true if self.languages.empty?
		return self.languages.any? {|lang| req.accepts_language?(lang) }
	end
	alias_method :has_acceptable_language?, :acceptable_language?


	### Returns true if all of the receiver's #encodings were designated 
	### as acceptable by the originating request, if there was no originating
	### request, or if no #encodings have been set.
	def acceptable_encoding?
		req = self.request or return true
		return true if self.encodings.empty?
		return self.encodings.all? {|enc| req.accepts_encoding?(enc) }
	end
	alias_method :has_acceptable_encoding?, :acceptable_encoding?

end # module Strelka::HTTPResponse::Negotiation

