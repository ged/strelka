# -*- rspec -*-
# vim: set nosta noet ts=4 sw=4:

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent.parent
	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
}

require 'rspec'
require 'ipaddr'

require 'spec/lib/helpers'

require 'strelka'
require 'strelka/authprovider/hostaccess'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::AuthProvider::HostAccess do

	before( :all ) do
		@request_factory = Mongrel2::RequestFactory.new( route: '/admin' )
		setup_logging( :fatal )
	end

	before( :each ) do
		@app = stub( "Strelka::App" )
		@provider = Strelka::AuthProvider.create( :hostaccess, @app )
	end

	after( :all ) do
		reset_logging()
	end


	it "knows what its allowed netblocks are" do
		@provider.allowed_netblocks.should be_an( Array )
		@provider.allowed_netblocks.should include( IPAddr.new('127.0.0.0/8') )
	end

	it "allows its netblocks to be set" do
		@provider.allowed_netblocks = %w[10.5.2.0/22 10.6.2.0/24]
		@provider.allowed_netblocks.should have( 2 ).members
		@provider.allowed_netblocks.should include( IPAddr.new('10.5.2.0/22'), IPAddr.new('10.6.2.0/24') )
	end

	it "can be configured via the Configurability API" do
		@provider.configure( 'allowed_netblocks' => %w[10.5.2.0/22 10.6.2.0/24] )
		@provider.allowed_netblocks.should include( IPAddr.new('10.5.2.0/22'), IPAddr.new('10.6.2.0/24') )
	end


	it "allows a request that originates from one of its allowed netblocks" do
		req = @request_factory.get( '/admin/console', :x_forwarded_for => '127.0.0.1' )
		@provider.authorize( nil, req, nil ).should be_true()
	end


	it "doesn't allow a request which is not from one of its allowed netblocks" do
		req = @request_factory.get( '/admin/console', :x_forwarded_for => '8.8.8.8' )
		@provider.authorize( nil, req, nil ).should be_false()
	end


end

