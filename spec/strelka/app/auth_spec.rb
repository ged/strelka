#!/usr/bin/env ruby

require_relative '../../helpers'

require 'rspec'
require 'rspec/mocks'

require 'strelka'
require 'strelka/plugins'
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


	it_should_behave_like( "A Strelka Plugin" )


	it "gives including apps a default authprovider" do
		app = Class.new( Strelka::App ) do
			plugins :auth
		end

		expect( app.auth_provider ).to be_a( Class )
		expect( app.auth_provider ).to be < Strelka::AuthProvider
	end

	it "adds the Auth mixin to the request class" do
		app = Class.new( Strelka::App ) do
			plugins :auth
		end
		app.install_plugins

		expect( @request_factory.get('/api/v1/verify') ).to respond_to( :authenticated? )
	end


	describe "an including App" do

		before( :each ) do
			@app = Class.new( Strelka::App ) do
				plugins :auth

				# Stand in for a real AuthProvider
				@auth_provider = RSpec::Mocks::Double

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


		it "applies authentication and authorization to every request by default" do
			app = @app.new
			req = @request_factory.get( '/api/v1' )

			expect( app.auth_provider ).to receive( :authenticate ).and_return( 'anonymous' )
			expect( app.auth_provider ).to receive( :authorize )

			res = app.handle( req )

			expect( res.status ).to eq( HTTP::OK )
		end

		it "doesn't have any auth criteria by default" do
			expect( @app ).to_not have_auth_criteria()
		end

		it "sets the authenticated_user attribute of the request to the credentials " +
		   "of the authenticating user" do
			app = @app.new
			req = @request_factory.get( '/api/v1' )

			expect( app.auth_provider ).to receive( :authenticate ).and_return( 'anonymous' )
			expect( app.auth_provider ).to receive( :authorize ).and_return( true )

			app.handle( req )
			expect( req.authenticated_user ).to eq( 'anonymous' )
		end

		it "has its configured auth provider inherited by subclasses" do
			Strelka::App::Auth.configure( :provider => 'basic' )
			subclass = Class.new( @app )
			expect( subclass.auth_provider ).to eq( Strelka::AuthProvider::Basic )
		end

		it "has its auth config inherited by subclasses" do
			subclass = Class.new( @app )

			expect( subclass.positive_auth_criteria ).to eq( @app.positive_auth_criteria )
			expect( subclass.positive_auth_criteria ).to_not equal( @app.positive_auth_criteria )
			expect( subclass.negative_auth_criteria ).to eq( @app.negative_auth_criteria )
			expect( subclass.negative_auth_criteria ).to_not equal( @app.negative_auth_criteria )
			expect( subclass.positive_perms_criteria ).to eq( @app.positive_perms_criteria )
			expect( subclass.positive_perms_criteria ).to_not equal( @app.positive_perms_criteria )
			expect( subclass.negative_perms_criteria ).to eq( @app.negative_perms_criteria )
			expect( subclass.negative_perms_criteria ).to_not equal( @app.negative_perms_criteria )
		end


		RSpec::Matchers.define( :require_auth_for_request ) do |request|
			match do |app|
				app.request_should_auth?( request )
			end
		end


		it "allows auth criteria to be declared with a string" do
			@app.require_auth_for( '/string' )
			app = @app.new

			req = @request_factory.get( '/api/v1/string' )
			expect( app ).to require_auth_for_request( req )
			expect( app.request_should_auth?(req) ).to be_truthy()
			req = @request_factory.get( '/api/v1/strong' )
			expect( app.request_should_auth?(req) ).to be_falsey()
			req = @request_factory.get( '/api/v1/stri' )
			expect( app.request_should_auth?(req) ).to be_falsey()
			req = @request_factory.get( '/api/v1/string/long' )
			expect( app.request_should_auth?(req) ).to be_falsey()
		end

		it "allows auth criteria to be declared with a regexp" do
			@app.require_auth_for( %r{/str[io]} )
			app = @app.new

			req = @request_factory.get( '/api/v1/stri' )
			expect( app.request_should_auth?(req) ).to be_truthy()
			req = @request_factory.get( '/api/v1/stro' )
			expect( app.request_should_auth?(req) ).to be_truthy()
			req = @request_factory.get( '/api/v1/string' ) # not right-bound
			expect( app.request_should_auth?(req) ).to be_truthy()
			req = @request_factory.get( '/api/v1/string/long' )
			expect( app.request_should_auth?(req) ).to be_truthy()
			req = @request_factory.get( '/api/v1/other/string/long' ) # Not left-bound
			expect( app.request_should_auth?(req) ).to be_truthy()
			req = @request_factory.get( '/api/v1/chatlog' ) # Not left-bound
			expect( app.request_should_auth?(req) ).to be_falsey()
		end

		it "allows auth criteria to be declared with a string and a block" do
			@app.require_auth_for( 'string' ) do |req|
				req.verb != :GET
			end

			app = @app.new

			req = @request_factory.get( '/api/v1/string' )
			expect( app.request_should_auth?(req) ).to be_falsey()
			req = @request_factory.post( '/api/v1/string' )
			expect( app.request_should_auth?(req) ).to be_truthy()
			req = @request_factory.put( '/api/v1/string' )
			expect( app.request_should_auth?(req) ).to be_truthy()
			req = @request_factory.delete( '/api/v1/string' )
			expect( app.request_should_auth?(req) ).to be_truthy()
			req = @request_factory.options( '/api/v1/string' )
			expect( app.request_should_auth?(req) ).to be_truthy()
		end

		it "allows auth criteria to be declared with a regexp and a block" do
			@app.require_auth_for( %r{/regexp(?:/(?<username>\w+))?} ) do |req, match|
				match[:username] ? true : false
			end

			app = @app.new

			req = @request_factory.get( '/api/v1/regexp' )
			expect( app.request_should_auth?(req) ).to be_falsey()
			req = @request_factory.get( '/api/v1/regexp/a_username' )
			expect( app.request_should_auth?(req) ).to be_truthy()
			req = @request_factory.get( '/api/v1/regexp/%20not+a+username' )
			expect( app.request_should_auth?(req) ).to be_falsey()
		end

		it "allows auth criteria to be declared with just a block" do
			@app.require_auth_for do |req|
				path = req.app_path.gsub( %r{^/+|/+$}, '' )

				(
					path == 'strong' or
					path =~ %r{^marlon_brando$}i or
					req.verb == :POST or
					req.content_type == 'application/x-www-form-urlencoded'
				)
			end

			app = @app.new

			req = @request_factory.get( '/api/v1/strong' )
			expect( app.request_should_auth?(req) ).to be_truthy()
			req = @request_factory.get( '/api/v1/marlon_brando' )
			expect( app.request_should_auth?(req) ).to be_truthy()
			req = @request_factory.post( '/api/v1/somewhere' )
			expect( app.request_should_auth?(req) ).to be_truthy()
			req = @request_factory.put( '/api/v1/somewhere' )
			req.content_type = 'application/x-www-form-urlencoded'
			expect( app.request_should_auth?(req) ).to be_truthy()

			req = @request_factory.get( '/api/v1/string' )
			expect( app.request_should_auth?(req) ).to be_falsey()
			req = @request_factory.get( '/api/v1/marlon_brando/2' )
			expect( app.request_should_auth?(req) ).to be_falsey()
			req = @request_factory.put( '/api/v1/somewhere' )
			expect( app.request_should_auth?(req) ).to be_falsey()

		end

		it "allows negative auth criteria to be declared with a string" do
			@app.no_auth_for( '/string' )
			app = @app.new

			req = @request_factory.get( '/api/v1/string' )
			expect( app.request_should_auth?(req) ).to be_falsey()
			req = @request_factory.get( '/api/v1/strong' )
			expect( app.request_should_auth?(req) ).to be_truthy()
			req = @request_factory.get( '/api/v1/stri' )
			expect( app.request_should_auth?(req) ).to be_truthy()
			req = @request_factory.get( '/api/v1/string/long' )
			expect( app.request_should_auth?(req) ).to be_truthy()
		end

		it "allows negative auth criteria to be declared with a regexp" do
			@app.no_auth_for( %r{/str[io]} )
			app = @app.new

			req = @request_factory.get( '/api/v1/stri' )
			expect( app.request_should_auth?(req) ).to be_falsey()
			req = @request_factory.get( '/api/v1/stro' )
			expect( app.request_should_auth?(req) ).to be_falsey()
			req = @request_factory.get( '/api/v1/string' ) # not right-bound
			expect( app.request_should_auth?(req) ).to be_falsey()
			req = @request_factory.get( '/api/v1/string/long' )
			expect( app.request_should_auth?(req) ).to be_falsey()
			req = @request_factory.get( '/api/v1/other/string/long' ) # Not left-bound
			expect( app.request_should_auth?(req) ).to be_falsey()
			req = @request_factory.get( '/api/v1/chat' )
			expect( app.request_should_auth?(req) ).to be_truthy()
		end

		it "allows negative auth criteria to be declared with a string and a block" do
			@app.no_auth_for( 'string' ) {|req| req.verb == :GET }

			app = @app.new

			req = @request_factory.get( '/api/v1/string' )
			expect( app.request_should_auth?(req) ).to be_falsey()
			req = @request_factory.get( '/api/v1/strong' )
			expect( app.request_should_auth?(req) ).to be_truthy()
			req = @request_factory.post( '/api/v1/string' )
			expect( app.request_should_auth?(req) ).to be_truthy()
			req = @request_factory.put( '/api/v1/string' )
			expect( app.request_should_auth?(req) ).to be_truthy()
			req = @request_factory.delete( '/api/v1/string' )
			expect( app.request_should_auth?(req) ).to be_truthy()
			req = @request_factory.options( '/api/v1/string' )
			expect( app.request_should_auth?(req) ).to be_truthy()
		end

		it "allows negative auth criteria to be declared with a regexp and a block" do
			@app.no_auth_for( %r{/regexp(?:/(?<username>\w+))?} ) do |req, match|
				match[:username] == 'guest'
			end

			app = @app.new

			req = @request_factory.get( '/api/v1/regexp' )
			expect( app.request_should_auth?(req) ).to be_truthy()
			req = @request_factory.get( '/api/v1/regexp/a_username' )
			expect( app.request_should_auth?(req) ).to be_truthy()
			req = @request_factory.get( '/api/v1/regexp/%20not+a+username' )
			expect( app.request_should_auth?(req) ).to be_truthy()
			req = @request_factory.get( '/api/v1/regexp/guest' )
			expect( app.request_should_auth?(req) ).to be_falsey()
		end

		it "allows negative auth criteria to be declared with just a block" do
			@app.no_auth_for do |req|
				req.app_path == '/foom' &&
					req.verb == :GET &&
					req.headers.accept.include?( 'text/plain' )
			end

			app = @app.new

			req = @request_factory.get( '/api/v1/foom' )
			expect( app.request_should_auth?(req) ).to be_truthy()
			req = @request_factory.post( '/api/v1/foom', :accept => 'text/plain, text/html; q=0.5' )
			expect( app.request_should_auth?(req) ).to be_truthy()
			req = @request_factory.get( '/api/v1/foom', :accept => 'text/plain, text/html; q=0.5' )
			expect( app.request_should_auth?(req) ).to be_falsey()

		end


		it "allows perms criteria to be declared with a string" do
			@app.require_perms_for( '/string', :stringperm )
			app = @app.new

			req = @request_factory.get( '/api/v1/string' )
			expect( app.required_perms_for(req) ).to eq( [ :stringperm ] )
			req = @request_factory.get( '/api/v1/strong' )
			expect( app.required_perms_for(req) ).to eq( [] )
		end

		it "allows perms criteria to be declared with a regexp" do
			@app.require_perms_for( %r{^/admin}, :admin )
			@app.require_perms_for( %r{/grant}, :grant )
			app = @app.new

			req = @request_factory.get( '/api/v1/admin' )
			expect( app.required_perms_for(req) ).to eq( [ :admin ] )
			req = @request_factory.get( '/api/v1/admin/grant' )
			expect( app.required_perms_for(req) ).to eq( [ :admin, :grant ] )
			req = @request_factory.get( '/api/v1/users' )
			expect( app.required_perms_for(req) ).to eq( [] )
			req = @request_factory.get( '/api/v1/users/grant' )
			expect( app.required_perms_for(req) ).to eq( [ :grant ] )
		end

		it "allows perms criteria to be declared with a string and a block" do
			@app.require_perms_for( '/string', :stringperm, :otherperm )
			@app.require_perms_for( '/string', :rawdata ) do |req|
				req.headers.accept && req.headers.accept =~ /json/i
			end
			app = @app.new

			req = @request_factory.get( '/api/v1/string' )
			expect( app.required_perms_for(req) ).to eq( [ :stringperm, :otherperm ] )
			req = @request_factory.get( '/api/v1/strong' )
			expect( app.required_perms_for(req) ).to eq( [] )
		end

		it "allows multiple perms criteria for the same path" do
			@app.no_auth_for( '' ) {|req| req.verb == :GET }
			@app.require_perms_for %r{.*}, :it_assets_webapp
			@app.require_perms_for( %r{.*}, :@sysadmin ) {|req, m| req.verb != :GET }

			app = @app.new

			req = @request_factory.get( '/api/v1' )
			expect( app.required_perms_for(req) ).to eq( [ :it_assets_webapp ] )
			req = @request_factory.post( '/api/v1' )
			expect( app.required_perms_for(req) ).to eq( [ :it_assets_webapp, :@sysadmin ] )
			req = @request_factory.get( '/api/v1/users' )
			expect( app.required_perms_for(req) ).to eq( [ :it_assets_webapp ] )
			req = @request_factory.post( '/api/v1/users' )
			expect( app.required_perms_for(req) ).to eq( [ :it_assets_webapp, :@sysadmin ] )
		end

		it "allows perms criteria to be declared with a regexp and a block" do
			userclass = Class.new do
				def self::[]( username )
					self.new(username)
				end
				def initialize( username ); @username = username; end
				def is_admin?
					@username == 'madeline'
				end
			end
			@app.require_perms_for( %r{^/user}, :admin )
			@app.require_perms_for( %r{^/user(/(?<username>\w+))?}, :superuser ) do |req, match|
				user = userclass[ match[:username] ]
				user.is_admin?
			end
			app = @app.new

			req = @request_factory.get( '/api/v1/user' )
			expect( app.required_perms_for(req) ).to eq( [ :admin ] )
			req = @request_factory.get( '/api/v1/user/jzero' )
			expect( app.required_perms_for(req) ).to eq( [ :admin ] )
			req = @request_factory.get( '/api/v1/user/madeline' )
			expect( app.required_perms_for(req) ).to eq( [ :admin, :superuser ] )
		end

		it "allows perms the same as the appid to be declared with just a block" do
			@app.require_perms_for do |req|
				req.verb != :GET
			end
			app = @app.new

			req = @request_factory.get( '/api/v1/accounts' )
			expect( app.required_perms_for(req) ).to eq( [] )
			req = @request_factory.post( '/api/v1/accounts', '' )
			expect( app.required_perms_for(req) ).to eq( [ :auth_test ] )
			req = @request_factory.put( '/api/v1/accounts/1', '' )
			expect( app.required_perms_for(req) ).to eq( [ :auth_test ] )
		end

		it "allows specific required permissions to be returned by the block" do
			@app.require_perms_for( %r{.*} ) do |req|
				:write_access if req.verb != :GET
			end
			app = @app.new

			req = @request_factory.get( '/api/v1/accounts' )
			expect( app.required_perms_for(req) ).to eq( [] )
			req = @request_factory.put( '/api/v1/accounts' )
			expect( app.required_perms_for(req) ).to eq( [ :write_access ] )
		end

		it "adds specific required permissions returned by the block to argument permissions" do
			@app.require_perms_for( %r{.*}, :basic_access ) do |req|
				:write_access if req.verb != :GET
			end
			app = @app.new

			req = @request_factory.get( '/api/v1/accounts' )
			expect( app.required_perms_for(req) ).to eq( [] )
			req = @request_factory.put( '/api/v1/accounts' )
			expect( app.required_perms_for(req) ).to include( :basic_access, :write_access )
		end

		it "allows specific, multiple required permissions to be returned by the block" do
			@app.require_perms_for( %r{.*} ) do |req|
				[ :write_access, :is_handsome ] if req.verb != :GET
			end
			app = @app.new

			req = @request_factory.get( '/api/v1/accounts' )
			expect( app.required_perms_for(req) ).to eq( [] )
			req = @request_factory.put( '/api/v1/accounts' )
			expect( app.required_perms_for(req) ).to include( :is_handsome, :write_access )
		end

		it "adds specific, multiple required permissions returned by the block to argument permissions" do
			@app.require_perms_for( %r{.*}, :basic_access ) do |req|
				[ :write_access, :is_handsome ] if req.verb != :GET
			end
			app = @app.new

			req = @request_factory.get( '/api/v1/accounts' )
			expect( app.required_perms_for(req) ).to eq( [] )
			req = @request_factory.put( '/api/v1/accounts' )
			expect( app.required_perms_for(req) ).to include( :basic_access, :write_access, :is_handsome )
		end


		it "allows negative perms criteria to be declared with a string" do
			@app.no_perms_for( '/string' )
			app = @app.new

			req = @request_factory.get( '/api/v1/string' )
			expect( app.required_perms_for(req) ).to be_empty()
			req = @request_factory.get( '/api/v1/strong' )
			expect( app.required_perms_for(req) ).to eq([ :auth_test ]) # default == appid
		end

		it "allows negative perms criteria to be declared with a regexp" do
			@app.no_perms_for( %r{^/signup} )
			app = @app.new

			req = @request_factory.get( '/api/v1/signup' )
			expect( app.required_perms_for(req) ).to be_empty()
			req = @request_factory.get( '/api/v1/signup/reapply' )
			expect( app.required_perms_for(req) ).to be_empty()
			req = @request_factory.get( '/api/v1/index' )
			expect( app.required_perms_for(req) ).to eq( [ :auth_test ] )
		end

		it "allows negative perms criteria to be declared with a string and a block" do
			@app.no_perms_for( '/' ) do |req|
				req.verb == :GET
			end
			app = @app.new

			req = @request_factory.get( '/api/v1' )
			expect( app.required_perms_for(req) ).to be_empty()
			req = @request_factory.post( '/api/v1' )
			expect( app.required_perms_for(req) ).to eq([ :auth_test ]) # default == appid
			req = @request_factory.get( '/api/v1/users' )

			expect( app.required_perms_for(req) ).to eq( [ :auth_test ] )
		end

		it "allows negative perms criteria to be declared with a regexp and a block" do
			@app.no_perms_for( %r{^/collection/(?<collname>[^/]+)} ) do |req, match|
				public_collections = %w[degasse ione champhion]
				collname = match[:collname]
				public_collections.include?( collname )
			end
			app = @app.new

			req = @request_factory.get( '/api/v1/collection' )
			expect( app.required_perms_for(req) ).to eq( [ :auth_test ] )
			req = @request_factory.get( '/api/v1/collection/degasse' )
			expect( app.required_perms_for(req) ).to be_empty()
			req = @request_factory.get( '/api/v1/collection/ione' )
			expect( app.required_perms_for(req) ).to be_empty()
			req = @request_factory.get( '/api/v1/collection/champhion' )
			expect( app.required_perms_for(req) ).to be_empty()
			req = @request_factory.get( '/api/v1/collection/calindra' )
			expect( app.required_perms_for(req) ).to eq( [ :auth_test ] )
		end

		it "allows negative perms criteria to be declared with just a block" do
			@app.no_perms_for do |req|
				intranet = IPAddr.new( '10.0.0.0/8' )
				intranet.include?( req.remote_ip )
			end
			app = @app.new

			req = @request_factory.get( '/api/v1/collection', x_forwarded_for: '10.0.1.68' )
			expect( app.required_perms_for(req) ).to be_empty()
			req = @request_factory.get( '/api/v1/collection', x_forwarded_for: '192.0.43.10' )
			expect( app.required_perms_for(req) ).to eq( [ :auth_test ] )
		end


		context "that has positive auth criteria" do

			before( :each ) do
				@app.require_auth_for( '/onlyauth' )
				@app.require_auth_for( '/both' )
			end

			context "and positive perms criteria" do

				before( :each ) do
					@app.require_perms_for( '/both' )
					@app.require_perms_for( '/onlyperms' )
				end

				it "authorizes a request that only matches the perms criteria" do
					req = @request_factory.get( '/api/v1/onlyperms' )

					app = @app.new
					expect( app.auth_provider ).to_not receive( :authenticate )
					expect( app.auth_provider ).to receive( :authorize )

					app.handle( req )
				end

				it "authenticates a request that only matches the auth criteria" do
					req = @request_factory.get( '/api/v1/onlyauth' )

					app = @app.new
					expect( app.auth_provider ).to receive( :authenticate )
					expect( app.auth_provider ).to_not receive( :authorize )

					app.handle( req )
				end

				it "authenticates and authorizes a request that matches both" do
					req = @request_factory.get( '/api/v1/both' )

					app = @app.new
					expect( app.auth_provider ).to receive( :authenticate )
					expect( app.auth_provider ).to receive( :authorize )

					app.handle( req )
				end

				it "doesn't do either for a request that doesn't match either" do
					req = @request_factory.get( '/api/v1/neither' )

					app = @app.new
					expect( app.auth_provider ).to_not receive( :authenticate )
					expect( app.auth_provider ).to_not receive( :authorize )

					app.handle( req )
				end

			end

			context "and negative perms criteria" do

				before( :each ) do
					@app.no_perms_for( '/both' )
					@app.no_perms_for( '/onlyperms' )
				end

				it "doesn't do either for a request that only matches the perms criteria" do
					req = @request_factory.get( '/api/v1/onlyperms' )

					app = @app.new
					expect( app.auth_provider ).to_not receive( :authenticate )
					expect( app.auth_provider ).to_not receive( :authorize )

					app.handle( req )
				end

				it "authenticates and authorizes a request that only matches the auth criteria" do
					req = @request_factory.get( '/api/v1/onlyauth' )

					app = @app.new
					expect( app.auth_provider ).to receive( :authenticate )
					expect( app.auth_provider ).to receive( :authorize )

					app.handle( req )
				end

				it "only authenticates a request that matches both" do
					req = @request_factory.get( '/api/v1/both' )

					app = @app.new
					expect( app.auth_provider ).to receive( :authenticate )
					expect( app.auth_provider ).to_not receive( :authorize )

					app.handle( req )
				end

				it "only authorizes a request that doesn't match either" do
					req = @request_factory.get( '/api/v1/neither' )

					app = @app.new
					expect( app.auth_provider ).to_not receive( :authenticate )
					expect( app.auth_provider ).to receive( :authorize )

					app.handle( req )
				end

			end

		end


		context "that has negative auth criteria" do

			before( :each ) do
				@app.no_auth_for( '/onlyauth' )
				@app.no_auth_for( '/both' )
			end

			context "and positive perms criteria" do

				before( :each ) do
					@app.require_perms_for( '/both' )
					@app.require_perms_for( '/onlyperms' )
				end

				it "authenticates and authorizes a request that only matches the perms criteria" do
					req = @request_factory.get( '/api/v1/onlyperms' )

					app = @app.new
					expect( app.auth_provider ).to receive( :authenticate )
					expect( app.auth_provider ).to receive( :authorize )

					app.handle( req )
				end

				it "doesn't do either for a request that only matches the auth criteria" do
					req = @request_factory.get( '/api/v1/onlyauth' )

					app = @app.new
					expect( app.auth_provider ).to_not receive( :authenticate )
					expect( app.auth_provider ).to_not receive( :authorize )

					app.handle( req )
				end

				it "authorizes a request that matches both" do
					req = @request_factory.get( '/api/v1/both' )

					app = @app.new
					expect( app.auth_provider ).to_not receive( :authenticate )
					expect( app.auth_provider ).to receive( :authorize )

					app.handle( req )
				end

				it "authenticates a request that doesn't match either" do
					req = @request_factory.get( '/api/v1/neither' )

					app = @app.new
					expect( app.auth_provider ).to receive( :authenticate )
					expect( app.auth_provider ).to_not receive( :authorize )

					app.handle( req )
				end

			end

			context "and negative perms criteria" do

				before( :each ) do
					@app.no_perms_for( '/both' )
					@app.no_perms_for( '/onlyperms' )
				end

				it "authenticates for a request that only matches the perms criteria" do
					req = @request_factory.get( '/api/v1/onlyperms' )

					app = @app.new
					expect( app.auth_provider ).to receive( :authenticate )
					expect( app.auth_provider ).to_not receive( :authorize )

					app.handle( req )
				end

				it "authorizes a request that only matches the auth criteria" do
					req = @request_factory.get( '/api/v1/onlyauth' )

					app = @app.new
					expect( app.auth_provider ).to_not receive( :authenticate )
					expect( app.auth_provider ).to receive( :authorize )

					app.handle( req )
				end

				it "doesn't do either for a request that matches both" do
					req = @request_factory.get( '/api/v1/both' )

					app = @app.new
					expect( app.auth_provider ).to_not receive( :authenticate )
					expect( app.auth_provider ).to_not receive( :authorize )

					app.handle( req )
				end

				it "authenticates and authorizes a request that doesn't match either" do
					req = @request_factory.get( '/api/v1/neither' )

					app = @app.new
					expect( app.auth_provider ).to receive( :authenticate )
					expect( app.auth_provider ).to receive( :authorize )

					app.handle( req )
				end

			end

		end


		context "that has overlapping perms criteria" do

			before( :each ) do
				@app.require_perms_for( %r{^/admin.*}, :admin )
				@app.require_perms_for( %r{^/admin/upload.*}, :upload )
			end

			it "authorizes with a union of the permissions of both of the criteria" do
				req = @request_factory.get( '/api/v1/admin/upload' )

				app = @app.new
				allow( app.auth_provider ).to receive( :authenticate ).and_return( :credentials )
				expect( app.auth_provider ).to receive( :authorize ).
					with( :credentials, req, [:admin, :upload] )

				app.handle( req )
			end

		end

	end

end

