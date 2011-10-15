#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent
	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
}

require 'rspec'
require 'zmq'
require 'mongrel2'

require 'spec/lib/helpers'

require 'strelka'
require 'strelka/exceptions'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka, "exception classes" do

	before( :all ) do
		setup_logging( :fatal )
		@request_factory = Mongrel2::RequestFactory.new( route: '/exceptions' )
	end

	after( :all ) do
		reset_logging()
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

			exception.request.should == req
		end

	end

end

