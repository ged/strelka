# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# frozen-string-literal: true

require_relative '../../helpers'

require 'rspec'
require 'ipaddr'

require 'strelka'
require 'strelka/authprovider/hostaccess'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::AuthProvider::HostAccess do

	before( :all ) do
		@request_factory = Mongrel2::RequestFactory.new( route: '/admin' )
	end

	before( :each ) do
		@app = double( "Strelka::App" )
		@provider = Strelka::AuthProvider.create( :hostaccess, @app )
	end


	it "knows what its allowed netblocks are" do
		expect( @provider.allowed_netblocks ).to be_an( Array )
		expect( @provider.allowed_netblocks ).to include( IPAddr.new('127.0.0.0/8') )
	end

	it "allows its netblocks to be set" do
		@provider.allowed_netblocks = %w[10.5.2.0/22 10.6.2.0/24]
		expect( @provider.allowed_netblocks.size ).to eq(  2  )
		expect( @provider.allowed_netblocks ).to include( IPAddr.new('10.5.2.0/22'), IPAddr.new('10.6.2.0/24') )
	end

	it "can be configured via the Configurability API" do
		@provider.configure( 'allowed_netblocks' => %w[10.5.2.0/22 10.6.2.0/24] )
		expect( @provider.allowed_netblocks ).to include( IPAddr.new('10.5.2.0/22'), IPAddr.new('10.6.2.0/24') )
	end


	it "allows a request that originates from one of its allowed netblocks" do
		req = @request_factory.get( '/admin/console', :x_forwarded_for => '127.0.0.1' )
		expect( @provider.authorize( nil, req, nil ) ).to be_truthy()
	end


	it "doesn't allow a request which is not from one of its allowed netblocks" do
		req = @request_factory.get( '/admin/console', :x_forwarded_for => '8.8.8.8' )
		expect( @provider.authorize( nil, req, nil ) ).to be_falsey()
	end


end

