#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent.parent
	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
}

require 'rspec'
require 'rspec/mocks'

require 'spec/lib/helpers'

require 'strelka'
require 'strelka/app/plugins'
require 'strelka/app/auth'
require 'strelka/authprovider'

require 'strelka/behavior/plugin'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::App::Auth do

	before( :all ) do
		setup_logging( :fatal )
		@request_factory = Mongrel2::RequestFactory.new( route: '/api/v1' )
	end

	after( :all ) do
		reset_logging()
	end


	it_should_behave_like( "A Strelka::App Plugin" )


	it "gives including apps a default authprovider" do
		app = Class.new( Strelka::App ) do
			plugins :auth
		end

		app.auth_provider.should be_a( Class )
		app.auth_provider.should < Strelka::AuthProvider
	end


	it "adds the Auth mixin to the request class" do
		app = Class.new( Strelka::App ) do
			plugins :auth
		end

		@request_factory.get( '/api/v1/verify' ).should respond_to( :authenticated? )
	end


	describe "an including App" do

		before( :each ) do
			@app = Class.new( Strelka::App ) do
				plugins :auth

				# Stand in for a real AuthProvider
				@auth_provider = RSpec::Mocks::Mock

				def initialize( appid='auth-test', sspec=TEST_SEND_SPEC, rspec=TEST_RECV_SPEC )
					super
				end

				def handle_request( req )
					super do
						res = req.response
						res.status = HTTP::OK
						res.content_type = 'text/plain'
						res.puts "Ran successfully."

						res
					end
				end
			end
		end

		after( :each ) do
			@app = nil
		end


		it "applies auth to every request by default" do
			app = @app.new
			req = @request_factory.get( '/api/v1' )

			app.auth_provider.should_receive( :authenticate ).and_return( 'anonymous' )
			app.auth_provider.should_receive( :authorize ).and_return( true )

			res = app.handle( req )

			res.status.should == HTTP::OK
		end

		it "doesn't have any auth criteria by default" do
			@app.should_not have_auth_criteria()
		end

		it "sets the authenticated_user attribute of the request to the credentials of the authenticating user" do
			app = @app.new
			req = @request_factory.get( '/api/v1' )

			app.auth_provider.should_receive( :authenticate ).and_return( 'anonymous' )
			app.auth_provider.should_receive( :authorize ).and_return( true )

			app.handle( req )
			req.authenticated_user.should == 'anonymous'
		end

		context "that has negative auth criteria for the root" do

			before( :each ) do
				@app.no_auth_for( '/' )
			end

			it "knows that it has auth criteria" do
				@app.should have_auth_criteria()
			end

			it "doesn't pass a request for the root path through auth" do
				req = @request_factory.get( '/api/v1/' )

				app = @app.new
				app.auth_provider.should_not_receive( :authenticate )
				app.auth_provider.should_not_receive( :authorize )

				app.handle( req )
			end

			it "passes a request for a path other than the root through auth" do
				req = @request_factory.get( '/api/v1/console' )

				app = @app.new
				app.auth_provider.should_receive( :authenticate ).and_return( 'anonymous' )
				app.auth_provider.should_receive( :authorize ).and_return( true )

				app.handle( req )
			end

		end

		context "that has negative auth criteria" do

			before( :each ) do
				@app.no_auth_for( '/login' )
			end

			it "knows that it has auth criteria" do
				@app.should have_auth_criteria()
			end

			it "doesn't pass a request that matches through auth" do
				req = @request_factory.get( '/api/v1/login' )

				app = @app.new
				app.auth_provider.should_not_receive( :authenticate )
				app.auth_provider.should_not_receive( :authorize )

				app.handle( req )
			end

			it "passes a request that doesn't match through auth" do
				req = @request_factory.get( '/api/v1/console' )

				app = @app.new
				app.auth_provider.should_receive( :authenticate ).and_return( 'anonymous' )
				app.auth_provider.should_receive( :authorize ).and_return( true )

				app.handle( req )
			end

		end

		context "that has a negative auth criteria block" do

			before( :each ) do
				@app.no_auth_for do |req|
					req.notes[:skip_auth]
				end
			end

			it "knows that it has auth criteria" do
				@app.should have_auth_criteria()
			end

			it "doesn't pass a request for which the block returns true through auth" do
				req = @request_factory.get( '/api/v1/login' )
				req.notes[:skip_auth] = true

				app = @app.new
				app.auth_provider.should_not_receive( :authenticate )
				app.auth_provider.should_not_receive( :authorize )

				app.handle( req )
			end

			it "passes a request for which the block returns false through auth" do
				req = @request_factory.get( '/api/v1/login' )
				req.notes[:skip_auth] = false

				app = @app.new
				app.auth_provider.should_receive( :authenticate ).and_return( 'anonymous' )
				app.auth_provider.should_receive( :authorize ).and_return( true )

				app.handle( req )
			end

		end


		context "that has a negative auth criteria with both a pattern and a block" do

			before( :each ) do
				@app.no_auth_for( %r{^/login/(?<username>\w+)} ) do |req, match|
					match[:username] != 'validuser'
				end
			end

			it "knows that it has auth criteria" do
				@app.should have_auth_criteria()
			end

			it "doesn't pass a request through auth if the path matches and the block returns true" do
				req = @request_factory.get( '/api/v1/login/lyssa' )

				app = @app.new
				app.auth_provider.should_not_receive( :authenticate )
				app.auth_provider.should_not_receive( :authorize )

				app.handle( req )
			end

			it "passes a request through auth if the path doesn't match" do
				req = @request_factory.get( '/api/v1/console' )

				app = @app.new
				app.auth_provider.should_receive( :authenticate ).and_return( 'anonymous' )
				app.auth_provider.should_receive( :authorize ).and_return( true )

				app.handle( req )
			end

			it "passes a request through auth if the path matches, but the the block returns false" do
				req = @request_factory.get( '/api/v1/login/validuser' )

				app = @app.new
				app.auth_provider.should_receive( :authenticate ).and_return( 'anonymous' )
				app.auth_provider.should_receive( :authorize ).and_return( true )

				app.handle( req )
			end

		end


		context "that has positive auth criteria" do

			before( :each ) do
				@app.require_auth_for( '/login' )
			end

			it "knows that it has auth criteria" do
				@app.should have_auth_criteria()
			end

			it "passes requests that match through auth" do
				req = @request_factory.get( '/api/v1/login' )

				app = @app.new
				app.auth_provider.should_receive( :authenticate ).and_return( 'anonymous' )
				app.auth_provider.should_receive( :authorize ).and_return( true )

				app.handle( req )
			end

			it "doesn't pass requests that don't match through auth" do
				req = @request_factory.get( '/api/v1/console' )

				app = @app.new
				app.auth_provider.should_not_receive( :authenticate )
				app.auth_provider.should_not_receive( :authorize )

				app.handle( req )
			end
		end


		context "that has a positive auth criteria block" do

			before( :each ) do
				@app.require_auth_for do |req|
					req.notes[:require_auth]
				end
			end

			it "knows that it has auth criteria" do
				@app.should have_auth_criteria()
			end

			it "passes requests for which the block returns true through auth" do
				req = @request_factory.get( '/api/v1/login' )
				req.notes[:require_auth] = true

				app = @app.new
				app.auth_provider.should_receive( :authenticate ).and_return( 'anonymous' )
				app.auth_provider.should_receive( :authorize ).and_return( true )

				app.handle( req )
			end

			it "doesn't pass requests for which the block returns false through auth" do
				req = @request_factory.get( '/api/v1/console' )
				req.notes[:require_auth] = false

				app = @app.new
				app.auth_provider.should_not_receive( :authenticate )
				app.auth_provider.should_not_receive( :authorize )

				app.handle( req )
			end
		end


		context "that has a positive auth criteria with both a pattern and a block" do

			before( :each ) do
				@app.require_auth_for( %r{^/login/(?<username>\w+)} ) do |req, match|
					match[:username] != 'guest'
				end
			end

			it "knows that it has auth criteria" do
				@app.should have_auth_criteria()
			end

			it "passes a request through auth if the path matches and the block returns true" do
				req = @request_factory.get( '/api/v1/login/lyssa' )

				app = @app.new
				app.auth_provider.should_receive( :authenticate ).and_return( 'lyssa' )
				app.auth_provider.should_receive( :authorize ).and_return( true )

				app.handle( req )
			end

			it "doesn't pass a request through auth if the path doesn't match" do
				req = @request_factory.get( '/api/v1/console' )

				app = @app.new
				app.auth_provider.should_not_receive( :authenticate )
				app.auth_provider.should_not_receive( :authorize )

				app.handle( req )
			end

			it "doesn't pass a request through auth if the path matches, but the the block returns false" do
				req = @request_factory.get( '/api/v1/login/guest' )

				app = @app.new
				app.auth_provider.should_not_receive( :authenticate )
				app.auth_provider.should_not_receive( :authorize )

				app.handle( req )
			end

		end


		it "can register an authorization callback with a block" do
			@app.authz_callback { :authz }
			@app.authz_callback.should be_a( Proc )
		end

		it "can register an authorization callback with a callable object" do
			callback = Proc.new { :authz }
			@app.authz_callback( callback )
			@app.authz_callback.should == callback
		end


		context "that has an authz callback" do

			before( :each ) do
				@app.authz_callback {  }
			end

			it "yields authorization to the callback if authentication succeeds"
			it "responds with a 403 Forbidden response if the block doesn't return true"

		end

	end

end

