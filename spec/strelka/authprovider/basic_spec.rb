# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# frozen-string-literal: true

require_relative '../../helpers'

require 'rspec'
require 'ipaddr'

require 'strelka'
require 'strelka/authprovider/basic'


#####################################################################
###	C O N T E X T S
#####################################################################

RSpec.describe Strelka::AuthProvider::Basic do

	before( :all ) do
		@request_factory = Mongrel2::RequestFactory.new( route: '/admin' )
	end

	before( :each ) do
		@app = double( "Strelka::App", :conn => double("Connection", :app_id => 'test-app') )
		@provider = Strelka::AuthProvider.create( :basic, @app )
		@config = {
			:realm => 'Pern',
			:users => {
				"lessa" => "8wiomemUvH/+CX8UJv3Yhu+X26k=",
				"f'lar" => "NSeXAe7J5TTtJUE9epdaE6ojSYk=",
			}
		}
	end

	after( :each ) do
		described_class.users = {}
		described_class.realm = nil
	end


	#
	# Helpers
	#

	# Make a valid basic authorization header field
	def make_authorization_header( username, password )
		creds = [ username, password ].join( ':' )
		return "Basic %s" % [ creds ].pack( 'm' )
	end


	#
	# Examples
	#

	it "can be configured via the Configurability API" do
		described_class.configure( @config )
		expect( described_class.realm ).to eq( @config[:realm] )
		expect( described_class.users ).to eq( @config[:users] )
	end


	context "unconfigured" do

		it "rejects a request with no Authorization header" do
			req = @request_factory.get( '/admin/console' )

			expect {
				@provider.authenticate( req )
			}.to finish_with( HTTP::UNAUTHORIZED, /requires authentication/i ).
			     and_header( www_authenticate: "Basic realm=test-app" )
		end

		it "rejects a request with credentials" do
			req = @request_factory.get( '/admin/console' )
			req.header.authorization = make_authorization_header( 'lessa', 'ramoth' )

			expect {
				@provider.authenticate( req )
			}.to finish_with( HTTP::UNAUTHORIZED, /requires authentication/i ).
			     and_header( www_authenticate: "Basic realm=test-app" )
		end

	end


	context "configured with at least one user" do

		before( :each ) do
			described_class.configure( @config )
		end

		it "rejects a request with no Authorization header" do
			req = @request_factory.get( '/admin/console' )
			expect {
				@provider.authenticate( req )
			}.to finish_with( HTTP::UNAUTHORIZED, /requires authentication/i ).
			     and_header( www_authenticate: "Basic realm=Pern" )
		end

		it "rejects a request with an authorization header for some other auth scheme" do
			req = @request_factory.get( '/admin/console' )
			req.header.authorization = %{Digest username="Mufasa",
			  realm="testrealm@host.com",
			  nonce="dcd98b7102dd2f0e8b11d0f600bfb0c093",
			  uri="/dir/index.html",
			  qop=auth,
			  nc=00000001,
			  cnonce="0a4f113b",
			  response="6629fae49393a05397450978507c4ef1",
			  opaque="5ccc069c403ebaf9f0171e9517f40e41"}

			expect {
				@provider.authenticate( req )
			}.to finish_with( HTTP::UNAUTHORIZED, /requires authentication/i ).
			     and_header( www_authenticate: "Basic realm=Pern" )
		end

		it "rejects a request with malformed credentials (no ':')" do
			req = @request_factory.get( '/admin/console' )
			req.header.authorization = "Basic %s" % ['fax'].pack('m')

			expect {
				@provider.authenticate( req )
			}.to finish_with( HTTP::UNAUTHORIZED, /requires authentication/i ).
			     and_header( www_authenticate: "Basic realm=Pern" )
		end

		it "rejects a request with malformed credentials (invalid base64)" do
			req = @request_factory.get( '/admin/console' )
			req.header.authorization = "Basic \x06\x06\x18\x08\x36\x18\x02\x00"

			expect {
				@provider.authenticate( req )
			}.to finish_with( HTTP::UNAUTHORIZED, /requires authentication/i ).
			     and_header( www_authenticate: "Basic realm=Pern" )
		end

		it "rejects a request with non-existant user credentials" do
			req = @request_factory.get( '/admin/console' )
			req.header.authorization = make_authorization_header( 'kendyl', 'charnoth' )

			expect {
				@provider.authenticate( req )
			}.to finish_with( HTTP::UNAUTHORIZED, /requires authentication/i ).
			     and_header( www_authenticate: "Basic realm=Pern" )
		end

		it "rejects a request with a valid user, but the wrong password" do
			req = @request_factory.get( '/admin/console' )
			req.header.authorization = make_authorization_header( 'lessa', 'charnoth' )

			expect {
				@provider.authenticate( req )
			}.to finish_with( HTTP::UNAUTHORIZED, /requires authentication/i ).
			     and_header( www_authenticate: "Basic realm=Pern" )
		end

		it "accepts a request with valid credentials" do
			req = @request_factory.get( '/admin/console' )
			req.header.authorization = make_authorization_header( 'lessa', 'ramoth' )

			expect( @provider.authenticate(req) ).to be_truthy()
		end
	end

end

