# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# frozen-string-literal: true

require_relative '../../helpers'

require 'rspec'

require 'strelka'
require 'strelka/authprovider'
require 'strelka/httprequest/auth'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::HTTPRequest::Auth do

	before( :all ) do
		@request_factory = Mongrel2::RequestFactory.new( route: '/service/user' )
	end


	let( :request ) do
		request = @request_factory.get( '/service/user/astark' )
		request.extend( described_class )
		request
	end



	it "adds an authenticated? predicate" do
		expect( request ).to_not be_authenticated()
		request.authenticated_user = 'anonymous'
		expect( request ).to be_authenticated()
	end

	it "adds an authenticated_user attribute" do
		expect( request.authenticated_user ).to be_nil()
		request.authenticated_user = 'someone'
		expect( request.authenticated_user ).to eq( 'someone' )
	end


	context "authentication method" do

		it "sets the authenticated user to the result of the authenticate block" do
			request.authenticate do
				:the_user
			end

			expect( request.authenticated_user ).to eq( :the_user )
		end

		it "calls #authenticate on the request's auth_provider if no block is given" do
			request.auth_provider = instance_double( Strelka::AuthProvider )

			expect( request.auth_provider ).to receive( :authenticate ).with( request ).
				and_return( :the_user )

			expect( request.authenticate ).to eq( :the_user )
			expect( request.authenticated_user ).to eq( :the_user )
		end

		it "finishes with a 401 Auth Required if the provided block returns a false value" do
			expect {
				request.authenticate { false }
			}.to finish_with( HTTP::UNAUTHORIZED )
		end

		it "doesn't 401 if provided block returns false when called with optional: true" do
			expect {
				request.authenticate( optional: true ) { false }
			}.to_not finish_with( HTTP::UNAUTHORIZED )
		end

	end


	context "authorization method" do

		it "is a noop if the provided block returns true" do
			expect {
				request.authorize { :the_user }
			}.to_not finish_with( HTTP::FORBIDDEN )
		end


		it "calls #authorize on the request's auth_provider if no block is given" do
			request.authenticated_user = :the_user
			request.auth_provider = instance_double( Strelka::AuthProvider )

			expect( request.auth_provider ).to_not receive( :authenticate )
			expect( request.auth_provider ).to receive( :authorize ).
				with( :the_user, request, [] ).
				and_return( true )

			result = request.authorize

			expect( result ).to eq( :the_user )
			expect( request.authenticated_user ).to eq( :the_user )
		end


		it "trys to authenticate if called without a block and the request doesn't have an authorized_user" do
			request.authenticated_user = nil
			request.auth_provider = instance_double( Strelka::AuthProvider )

			expect( request.auth_provider ).to receive( :authenticate ).with( request ).
				and_return( :the_user )
			expect( request.auth_provider ).to receive( :authorize ).
				with( :the_user, request, [] ).
				and_return( true )

			result = request.authorize

			expect( result ).to eq( :the_user )
			expect( request.authenticated_user ).to eq( :the_user )
		end


		it "finishes with a 401 Auth Required if calling #authorize without a block and auth fails" do
			request.auth_provider = instance_double( Strelka::AuthProvider )

			expect( request.auth_provider ).to receive( :authenticate ) do |arg|
				expect( arg ).to be( request )
				Strelka::ResponseHelpers.finish_with( HTTP::UNAUTHORIZED )
			end

			expect { request.authorize }.to finish_with( HTTP::UNAUTHORIZED )
		end


		it "finishes with a 403 Forbidden if it returns a false value" do
			expect {
				request.authorize { false }
			}.to finish_with( HTTP::FORBIDDEN )
		end


		it "passes permissions to the auth provider" do
			request.authenticated_user = :the_user
			request.auth_provider = instance_double( Strelka::AuthProvider )

			expect( request.auth_provider ).to receive( :authorize ).
				with( :the_user, request, [ :hand, :meat ] ).
				and_return( true )

			result = request.authorize( :hand, :meat )

			expect( result ).to eq( :the_user )
			expect( request.authenticated_user ).to eq( :the_user )
		end

	end


end
