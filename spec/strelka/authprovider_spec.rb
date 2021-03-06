# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# frozen-string-literal: true

require_relative '../helpers'

require 'rspec'

require 'strelka'
require 'strelka/authprovider'


#####################################################################
###	C O N T E X T S
#####################################################################

RSpec.describe Strelka::AuthProvider do

	before( :all ) do
		@request_factory = Mongrel2::RequestFactory.new( route: '/admin' )
	end


	it "looks for plugins under strelka/authprovider" do
		expect( described_class.plugin_prefixes ).to include( 'strelka/authprovider' )
	end


	it "is abstract" do
		expect {
			described_class.new
		}.to raise_error( /private method/i )
	end


	describe "a subclass" do

		before( :all ) do
			@appclass = Class.new( Strelka::App ) do
				def initialize( appid='authprovider-test', sspec=TEST_SEND_SPEC, rspec=TEST_RECV_SPEC )
					super
				end
			end
		end

		before( :each ) do
			@subclass = Class.new( described_class )
			@app = @appclass.new
			@provider = @subclass.new( @app )
		end


		context "Authentication" do

			it "returns 'anonymous' as credentials if asked to authenticate" do
				req = @request_factory.get( '/admin/console' )
				expect( @provider.authenticate(req) ).to eq( 'anonymous' )
			end

			it "has a callback for adding authentication information to the request" do
				req = @request_factory.get( '/admin/console' )
				@provider.auth_succeeded( req, 'anonymous' ) # No-op by default
			end

		end


		context "Authorization" do

			it "doesn't fail if the application doesn't require any perms" do
				req = @request_factory.get( '/admin/console' )
				expect {
					@provider.authorize( 'anonymous', req, [] )
				}.to_not throw_symbol()
			end

			it "fails with a 403 (Forbidden) if the app does require perms" do
				req = @request_factory.get( '/admin/console' )

				expect {
					@provider.authorize( 'anonymous', req, [:write] )
				}.to finish_with( HTTP::FORBIDDEN, /you are not authorized/i )
			end

		end

	end

end

