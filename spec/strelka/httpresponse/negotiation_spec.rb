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
		@res = @req.response
		@res.extend( described_class )
	end


	describe "mediatype negotiated response extensions" do

		it "can provide blocks for bodies of several different mediatypes" do
			pending "implementation" do
				@req.headers.accept = 'application/x-yaml, application/json; q=0.7, text/xml; q=0.2'

				@res.for( 'application/json' ) { %{["a JSON dump"]} }
				@res.for( 'application/x-yaml' ) { "---\na: YAML dump\n\n" }

				@res.body.should == "---\na: YAML dump\n\n"
				@res.content_type.should == "application/x-yaml"
			end
		end


	end

end