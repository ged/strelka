#!/usr/bin/env ruby

require 'strelka' unless defined?( Strelka )
require 'strelka/app' unless defined?( Strelka::App )

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
#       add_content_type :tnetstring, 'text/x-tnetstring' do |response|
#           tnetstr = nil
#           begin
#               tnetstr = TNetString.dump( response.body )
#           rescue => err
#               self.log.error "%p while transforming entity body to a TNetString: %s" %
#                   [ err.class, err.message ]
#               return false
#           else
#               response.body = tnetstr
#               response.content_type = 'text/x-tnetstring'
#               return true
#           end
#       end
# 
#   end # class UserService
# 
module Strelka::App::Negotiation
	extend Strelka::App::Plugin

	run_before :routing, :filters, :templating


	### Class methods to add to classes with content-negotiation.
	module ClassMethods

		# Content-type tranform registry, keyed by name
		@content_type_transforms = {}
		attr_reader :content_type_transforms

		# Content-type transform names, keyed by mimetype
		@transform_names = {}
		attr_reader :transform_names


		### Define a new media-type associated with the specified +name+ and +mimetype+. Responses
		### whose requests accept content of the given +mimetype+ will pass their response to the
		### specified +transform_block+, which should re-write the response's entity body if it can
		### transform it to its mimetype. If it successfully does so, it should return +true+, else
		### the next-best mimetype's transform will be called, etc.
		def add_content_type( name, mimetype, &transform_block )
			self.transform_names[ mimetype ] = name
			self.content_type_transforms[ name ] = transform_block
		end

	end # module ClassMethods


	### Add content-negotiation to incoming requests, then handle any necessary
	### conversion of the resulting response's entity body.
	def handle_request( request, &block )
		request.extend( Strelka::HTTPRequest::Negotiation )
		# The response object is extended by the request.

		response = super

		# Ensure the response is acceptable; if it isn't respond with the appropriate
		# status.
		unless response.acceptable?
			
		end

		return response
	end

end # module Strelka::App::Negotiation


