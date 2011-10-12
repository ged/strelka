#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

require 'rspec'

require 'spec/lib/helpers'

require 'strelka'
require 'strelka/httprequest/negotiation'
require 'strelka/httpresponse/negotiation'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::HTTPResponse::Negotiation do

	before( :all ) do
		setup_logging( :fatal )
		@request_factory = Mongrel2::RequestFactory.new( route: '/service/user' )
	end

	after( :all ) do
		reset_logging()
	end


	before( :each ) do
		@req = @request_factory.get( '/service/user/estark' )
		@req.extend( Strelka::HTTPRequest::Negotiation )
		@res = @req.response
	end


	it "can provide blocks for bodies of several different mediatypes" do
		pending "implementation" do
			@req.headers.accept = 'application/x-yaml, application/json; q=0.7, text/xml; q=0.2'

			@res.for( 'application/json' ) { %{["a JSON dump"]} }
			@res.for( 'application/x-yaml' ) { "---\na: YAML dump\n\n" }

			@res.body.should == "---\na: YAML dump\n\n"
			@res.content_type.should == "application/x-yaml"
		end
	end

	describe "content-type acceptance testing" do

		it "raises an exception if its originating request didn't include Negotiation" do
			req = @request_factory.get( '/service/user/athorne' )
			res = req.response
			res.extend( described_class )

			expect {
				res.acceptable?
			}.to raise_error( Strelka::PluginError, /doesn't include negotiation/i )
		end

		it "knows that it is not acceptable if its content_type isn't in the list of " +
		   "accepted types in its request" do
			@req.headers.accept = 'application/x-yaml, application/json; q=0.7'
			@res.content_type = 'application/x-ruby-marshalled'

			@res.should_not be_acceptable()
		end

		it "knows that it is acceptable if its request doesn't have accepted types" do
			@req.headers.delete( :accept )
			@res.content_type = 'application/x-ruby-marshalled'

			@res.should be_acceptable()
		end

		it "knows that it is acceptable if it doesn't have an originating request" do
			res = Strelka::HTTPResponse.new( 'appid', 88 )
			res.extend( Strelka::HTTPResponse::Negotiation )
			res.content_type = 'application/x-ruby-marshalled'

			res.should be_acceptable()
		end

	end


end

