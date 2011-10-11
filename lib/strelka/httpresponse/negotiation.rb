#!usr/bin/env ruby

require 'strelka/httpresponse'


# The mixin that adds methods to Strelka::HTTPResponse for content-negotiation.
# 
#    response = request.response
#    response.for( 'text/html' ) {...}
#    response.for( :json ) {...}
#    response.for_encoding( :en ) {...}
#    response.for_language( :en ) {...}
#
module Strelka::HTTPResponse::Negotiation

	

end # module Strelka::HTTPResponse::Negotiation