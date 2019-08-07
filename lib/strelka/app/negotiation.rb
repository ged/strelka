# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# frozen-string-literal: true

require 'strelka' unless defined?( Strelka )
require 'strelka/app' unless defined?( Strelka::App )

require 'strelka/constants'
require 'strelka/httprequest/negotiation'
require 'strelka/httpresponse/negotiation'


# HTTP Content negotiation for Strelka applications.
#
# The application can test the request for which types are accepted, set
# different response blocks for different acceptable content types, provides
# tranformations for entity bodies and set transformations for new content
# types.
#
#   class UserService < Strelka::App
#
#       plugins :routing, :negotiation
#
#       add_content_type :tnetstring, 'text/x-tnetstring', TNetstring.method( :dump )
#
#   end # class UserService
#
module Strelka::App::Negotiation
	include Strelka::Constants
	extend Strelka::Plugin

	run_outside :routing, :filters
	run_inside  :templating, :parameters


	# Class methods to add to classes with content-negotiation.
	module ClassMethods # :nodoc:

		### Define a new media-type associated with the specified +name+ and +mimetype+. Responses
		### whose requests accept content of the given +mimetype+ will #call the
		### specified +callback+ with the current response body, and should return the
		### transformed body. If the conversion failed, the callback can either raise an
		### exception or return +nil+, either of which will continue on to any remaining
		### transforms. If no +callback+ is given, the method's block will be used.
		def add_content_type( name, mimetype, callback=nil ) # :yield: response.body
			callback ||= Proc.new # Use the block
			Strelka::HTTPResponse::Negotiation.mimetype_map[ name.to_sym ] = mimetype
			Strelka::HTTPResponse::Negotiation.stringifiers[ mimetype ] = callback
		end

	end # module ClassMethods


	### Extension callback -- extend the HTTPRequest and HTTPResponse classes with Negotiation
	### support when this plugin is loaded.
	def self::included( object )
		self.log.debug "Extending Request and Response with Negotiation mixins"
		Strelka::HTTPRequest.class_eval { include Strelka::HTTPRequest::Negotiation }
		Strelka::HTTPResponse.class_eval { include Strelka::HTTPResponse::Negotiation }
		super
	end


	### Start content-negotiation when the response has returned.
	def handle_request( request )
		self.log.debug "[:negotiation] Wrapping response with HTTP content negotiation."

		response = super
		response.negotiate

		return response
	end


	### Check to be sure the response is acceptable after the request is handled.
	def fixup_response( response )
		response = super

		# Ensure the response is acceptable; if it isn't respond with the appropriate
		# status.
		unless response.acceptable?
			body = self.make_not_acceptable_body( response )
			finish_with( HTTP::NOT_ACCEPTABLE, body ) # throw
		end

		return response
	end


	### Create an HTTP entity body describing the variants of the given response.
	def make_not_acceptable_body( response )
		# :TODO: Unless it was a HEAD request, the response SHOULD include
		# an entity containing a list of available entity characteristics and
		# location(s) from which the user or user agent can choose the one
		# most appropriate. The entity format is specified by the media type
		# given in the Content-Type header field. Depending upon the format
		# and the capabilities of the user agent, selection of the most
		# appropriate choice MAY be performed automatically. However, this
		# specification does not define any standard for such automatic
		# selection. [RFC2616]
		return "No way to respond given the requested acceptance criteria."
	end

end # module Strelka::App::Negotiation


