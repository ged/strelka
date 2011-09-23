#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent

	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
}

require 'rspec'
require 'spec/lib/helpers'
require 'strelka/httprequest'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::HTTPRequest do

	before( :all ) do
		setup_logging( :fatal )
		@request_factory = Mongrel2::RequestFactory.new( route: '/directory' )
	end

	after( :all ) do
		reset_logging()
	end


	before( :each ) do
		@req = @request_factory.get( '/directory/userinfo/ged' )
	end

	it "knows what the request's parsed URI is" do
		@req.uri.should be_a( URI )
		@req.uri.path.should == '/directory/userinfo/ged'
		@req.uri.query.should be_nil()
	end

	it "knows what Mongrel2 route it followed" do
		@req.pattern.should == '/directory'
	end

	it "knows what the path of the request past its route is" do
		@req.app_path.should == '/userinfo/ged'
	end

	it "knows what HTTP verb the request used" do
		@req.verb.should == :GET
	end

end

