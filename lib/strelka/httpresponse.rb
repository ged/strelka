#!/usr/bin/env ruby

require 'mongrel2/httpresponse'
require 'strelka' unless defined?( Strelka )

# An HTTP response class.
class Strelka::HTTPResponse < Mongrel2::HTTPResponse
	include Strelka::Loggable,
	        Strelka::Constants


end # class Strelka::HTTPResponse
