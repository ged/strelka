# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require_relative '../helpers'

require 'rspec'
require 'mongrel2'

require 'strelka'
require 'strelka/exceptions'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka, "exception classes" do

	before( :all ) do
		@request_factory = Mongrel2::RequestFactory.new( route: '/exceptions' )
	end


	describe Strelka::RequestError do

		it "keeps track of the request that had the error" do
			req = @request_factory.get( '/exceptions/spec' )
			exception = nil

			begin
				raise Strelka::RequestError.new( req, "invalid request" )
			rescue Strelka::RequestError => err
				exception = err
			end

			expect( exception.request ).to eq( req )
		end

	end

end

