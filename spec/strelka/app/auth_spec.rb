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
		app.install_plugins

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


		it "applies authentication and authorization to every request by default" do
			app = @app.new
			req = @request_factory.get( '/api/v1' )

			app.auth_provider.should_receive( :authenticate ).and_return( 'anonymous' )
			app.auth_provider.should_receive( :authorize )

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

		it "has its configured auth provider inherited by subclasses" do
			Strelka::App::Auth.configure( :provider => 'basic' )
			subclass = Class.new( @app )
			subclass.auth_provider.should == Strelka::AuthProvider::Basic
		end

		it "has its auth config inherited by subclasses" do
			subclass = Class.new( @app )

			subclass.positive_auth_criteria.should == @app.positive_auth_criteria
			subclass.positive_auth_criteria.should_not equal( @app.positive_auth_criteria )
			subclass.negative_auth_criteria.should == @app.negative_auth_criteria
			subclass.negative_auth_criteria.should_not equal( @app.negative_auth_criteria )
			subclass.positive_perms_criteria.should == @app.positive_perms_criteria
			subclass.positive_perms_criteria.should_not equal( @app.positive_perms_criteria )
			subclass.negative_perms_criteria.should == @app.negative_perms_criteria
			subclass.negative_perms_criteria.should_not equal( @app.negative_perms_criteria )
		end


		it "allows auth criteria to be declared with a string" do
			@app.require_auth_for( '/string' )
			app = @app.new

			req = @request_factory.get( '/api/v1/string' )
			app.request_should_auth?( req ).should be_true()
			req = @request_factory.get( '/api/v1/strong' )
			app.request_should_auth?( req ).should be_false()
			req = @request_factory.get( '/api/v1/stri' )
			app.request_should_auth?( req ).should be_false()
			req = @request_factory.get( '/api/v1/string/long' )
			app.request_should_auth?( req ).should be_false()
		end

		it "allows auth criteria to be declared with a regexp" do
			@app.require_auth_for( %r{/str[io]} )
			app = @app.new

			req = @request_factory.get( '/api/v1/stri' )
			app.request_should_auth?( req ).should be_true()
			req = @request_factory.get( '/api/v1/stro' )
			app.request_should_auth?( req ).should be_true()
			req = @request_factory.get( '/api/v1/string' ) # not right-bound
			app.request_should_auth?( req ).should be_true()
			req = @request_factory.get( '/api/v1/string/long' )
			app.request_should_auth?( req ).should be_true()
			req = @request_factory.get( '/api/v1/other/string/long' ) # Not left-bound
			app.request_should_auth?( req ).should be_true()
			req = @request_factory.get( '/api/v1/chatlog' ) # Not left-bound
			app.request_should_auth?( req ).should be_false()
		end

		it "allows auth criteria to be declared with a string and a block" do
			@app.require_auth_for( 'string' ) do |req|
				req.verb != :GET
			end

			app = @app.new

			req = @request_factory.get( '/api/v1/string' )
			app.request_should_auth?( req ).should be_false()
			req = @request_factory.post( '/api/v1/string' )
			app.request_should_auth?( req ).should be_true()
			req = @request_factory.put( '/api/v1/string' )
			app.request_should_auth?( req ).should be_true()
			req = @request_factory.delete( '/api/v1/string' )
			app.request_should_auth?( req ).should be_true()
			req = @request_factory.options( '/api/v1/string' )
			app.request_should_auth?( req ).should be_true()
		end

		it "allows auth criteria to be declared with a regexp and a block" do
			@app.require_auth_for( %r{/regexp(?:/(?<username>\w+))?} ) do |req, match|
				match[:username] ? true : false
			end

			app = @app.new

			req = @request_factory.get( '/api/v1/regexp' )
			app.request_should_auth?( req ).should be_false()
			req = @request_factory.get( '/api/v1/regexp/a_username' )
			app.request_should_auth?( req ).should be_true()
			req = @request_factory.get( '/api/v1/regexp/%20not+a+username' )
			app.request_should_auth?( req ).should be_false()
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
			app.request_should_auth?( req ).should be_true()
			req = @request_factory.get( '/api/v1/marlon_brando' )
			app.request_should_auth?( req ).should be_true()
			req = @request_factory.post( '/api/v1/somewhere' )
			app.request_should_auth?( req ).should be_true()
			req = @request_factory.put( '/api/v1/somewhere' )
			req.content_type = 'application/x-www-form-urlencoded'
			app.request_should_auth?( req ).should be_true()

			req = @request_factory.get( '/api/v1/string' )
			app.request_should_auth?( req ).should be_false()
			req = @request_factory.get( '/api/v1/marlon_brando/2' )
			app.request_should_auth?( req ).should be_false()
			req = @request_factory.put( '/api/v1/somewhere' )
			app.request_should_auth?( req ).should be_false()

		end

		it "allows negative auth criteria to be declared with a string" do
			@app.no_auth_for( '/string' )
			app = @app.new

			req = @request_factory.get( '/api/v1/string' )
			app.request_should_auth?( req ).should be_false()
			req = @request_factory.get( '/api/v1/strong' )
			app.request_should_auth?( req ).should be_true()
			req = @request_factory.get( '/api/v1/stri' )
			app.request_should_auth?( req ).should be_true()
			req = @request_factory.get( '/api/v1/string/long' )
			app.request_should_auth?( req ).should be_true()
		end

		it "allows negative auth criteria to be declared with a regexp" do
			@app.no_auth_for( %r{/str[io]} )
			app = @app.new

			req = @request_factory.get( '/api/v1/stri' )
			app.request_should_auth?( req ).should be_false()
			req = @request_factory.get( '/api/v1/stro' )
			app.request_should_auth?( req ).should be_false()
			req = @request_factory.get( '/api/v1/string' ) # not right-bound
			app.request_should_auth?( req ).should be_false()
			req = @request_factory.get( '/api/v1/string/long' )
			app.request_should_auth?( req ).should be_false()
			req = @request_factory.get( '/api/v1/other/string/long' ) # Not left-bound
			app.request_should_auth?( req ).should be_false()
			req = @request_factory.get( '/api/v1/chat' )
			app.request_should_auth?( req ).should be_true()
		end

		it "allows negative auth criteria to be declared with a string and a block" do
			@app.no_auth_for( 'string' ) {|req| req.verb == :GET }

			app = @app.new

			req = @request_factory.get( '/api/v1/string' )
			app.request_should_auth?( req ).should be_false()
			req = @request_factory.get( '/api/v1/strong' )
			app.request_should_auth?( req ).should be_true()
			req = @request_factory.post( '/api/v1/string' )
			app.request_should_auth?( req ).should be_true()
			req = @request_factory.put( '/api/v1/string' )
			app.request_should_auth?( req ).should be_true()
			req = @request_factory.delete( '/api/v1/string' )
			app.request_should_auth?( req ).should be_true()
			req = @request_factory.options( '/api/v1/string' )
			app.request_should_auth?( req ).should be_true()
		end

		it "allows negative auth criteria to be declared with a regexp and a block" do
			@app.no_auth_for( %r{/regexp(?:/(?<username>\w+))?} ) do |req, match|
				match[:username] == 'guest'
			end

			app = @app.new

			req = @request_factory.get( '/api/v1/regexp' )
			app.request_should_auth?( req ).should be_true()
			req = @request_factory.get( '/api/v1/regexp/a_username' )
			app.request_should_auth?( req ).should be_true()
			req = @request_factory.get( '/api/v1/regexp/%20not+a+username' )
			app.request_should_auth?( req ).should be_true()
			req = @request_factory.get( '/api/v1/regexp/guest' )
			app.request_should_auth?( req ).should be_false()
		end

		it "allows negative auth criteria to be declared with just a block" do
			@app.no_auth_for do |req|
				req.app_path == '/foom' &&
					req.verb == :GET &&
					req.headers.accept.include?( 'text/plain' )
			end

			app = @app.new

			req = @request_factory.get( '/api/v1/foom' )
			app.request_should_auth?( req ).should be_true()
			req = @request_factory.post( '/api/v1/foom', :accept => 'text/plain, text/html; q=0.5' )
			app.request_should_auth?( req ).should be_true()
			req = @request_factory.get( '/api/v1/foom', :accept => 'text/plain, text/html; q=0.5' )
			app.request_should_auth?( req ).should be_false()

		end


		it "allows perms criteria to be declared with a string" do
			@app.require_perms_for( '/string', :stringperm )
			app = @app.new

			req = @request_factory.get( '/api/v1/string' )
			app.required_perms_for( req ).should == [ :stringperm ]
			req = @request_factory.get( '/api/v1/strong' )
			app.required_perms_for( req ).should == []
		end

		it "allows perms criteria to be declared with a regexp" do
			@app.require_perms_for( %r{^/admin}, :admin )
			@app.require_perms_for( %r{/grant}, :grant )
			app = @app.new

			req = @request_factory.get( '/api/v1/admin' )
			app.required_perms_for( req ).should == [ :admin ]
			req = @request_factory.get( '/api/v1/admin/grant' )
			app.required_perms_for( req ).should == [ :admin, :grant ]
			req = @request_factory.get( '/api/v1/users' )
			app.required_perms_for( req ).should == []
			req = @request_factory.get( '/api/v1/users/grant' )
			app.required_perms_for( req ).should == [ :grant ]
		end

		it "allows perms criteria to be declared with a string and a block" do
			@app.require_perms_for( '/string', :stringperm, :otherperm )
			@app.require_perms_for( '/string', :rawdata ) do |req|
				req.headers.accept && req.headers.accept =~ /json/i
			end
			app = @app.new

			req = @request_factory.get( '/api/v1/string' )
			app.required_perms_for( req ).should == [ :stringperm, :otherperm ]
			req = @request_factory.get( '/api/v1/strong' )
			app.required_perms_for( req ).should == []
		end

		it "allows multiple perms criteria for the same path" do
			@app.no_auth_for( '' ) {|req| req.verb == :GET }
			@app.require_perms_for %r{.*}, :it_assets_webapp
			@app.require_perms_for( %r{.*}, :@sysadmin ) {|req, m| req.verb != :GET }

			app = @app.new

			req = @request_factory.get( '/api/v1' )
			app.required_perms_for( req ).should == [ :it_assets_webapp ]
			req = @request_factory.post( '/api/v1' )
			app.required_perms_for( req ).should == [ :it_assets_webapp, :@sysadmin ]
			req = @request_factory.get( '/api/v1/users' )
			app.required_perms_for( req ).should == [ :it_assets_webapp ]
			req = @request_factory.post( '/api/v1/users' )
			app.required_perms_for( req ).should == [ :it_assets_webapp, :@sysadmin ]
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
			app.required_perms_for( req ).should == [ :admin ]
			req = @request_factory.get( '/api/v1/user/jzero' )
			app.required_perms_for( req ).should == [ :admin ]
			req = @request_factory.get( '/api/v1/user/madeline' )
			app.required_perms_for( req ).should == [ :admin, :superuser ]
		end

		it "allows perms the same as the appid to be declared with just a block" do
			@app.require_perms_for do |req|
				req.verb != :GET
			end
			app = @app.new

			req = @request_factory.get( '/api/v1/accounts' )
			app.required_perms_for( req ).should == []
			req = @request_factory.post( '/api/v1/accounts', '' )
			app.required_perms_for( req ).should == [ :auth_test ]
			req = @request_factory.put( '/api/v1/accounts/1', '' )
			app.required_perms_for( req ).should == [ :auth_test ]
		end

		it "allows negative perms criteria to be declared with a string" do
			@app.no_perms_for( '/string' )
			app = @app.new

			req = @request_factory.get( '/api/v1/string' )
			app.required_perms_for( req ).should be_empty()
			req = @request_factory.get( '/api/v1/strong' )
			app.required_perms_for( req ).should == [ :auth_test ] # default == appid
		end

		it "allows negative perms criteria to be declared with a regexp" do
			@app.no_perms_for( %r{^/signup} )
			app = @app.new

			req = @request_factory.get( '/api/v1/signup' )
			app.required_perms_for( req ).should be_empty()
			req = @request_factory.get( '/api/v1/signup/reapply' )
			app.required_perms_for( req ).should be_empty()
			req = @request_factory.get( '/api/v1/index' )
			app.required_perms_for( req ).should == [ :auth_test ]
		end

		it "allows negative perms criteria to be declared with a string and a block" do
			@app.no_perms_for( '/' ) do |req|
				req.verb == :GET
			end
			app = @app.new

			req = @request_factory.get( '/api/v1' )
			app.required_perms_for( req ).should be_empty()
			req = @request_factory.post( '/api/v1' )
			app.required_perms_for( req ).should == [ :auth_test ] # default == appid
			req = @request_factory.get( '/api/v1/users' )
			app.required_perms_for( req ).should == [ :auth_test ]
		end

		it "allows negative perms criteria to be declared with a regexp and a block" do
			@app.no_perms_for( %r{^/collection/(?<collname>[^/]+)} ) do |req, match|
				public_collections = %w[degasse ione champhion]
				collname = match[:collname]
				public_collections.include?( collname )
			end
			app = @app.new

			req = @request_factory.get( '/api/v1/collection' )
			app.required_perms_for( req ).should == [ :auth_test ]
			req = @request_factory.get( '/api/v1/collection/degasse' )
			app.required_perms_for( req ).should be_empty()
			req = @request_factory.get( '/api/v1/collection/ione' )
			app.required_perms_for( req ).should be_empty()
			req = @request_factory.get( '/api/v1/collection/champhion' )
			app.required_perms_for( req ).should be_empty()
			req = @request_factory.get( '/api/v1/collection/calindra' )
			app.required_perms_for( req ).should == [ :auth_test ]
		end

		it "allows negative perms criteria to be declared with just a block" do
			@app.no_perms_for do |req|
				intranet = IPAddr.new( '10.0.0.0/8' )
				intranet.include?( req.remote_ip )
			end
			app = @app.new

			req = @request_factory.get( '/api/v1/collection', x_forwarded_for: '10.0.1.68' )
			app.required_perms_for( req ).should be_empty()
			req = @request_factory.get( '/api/v1/collection', x_forwarded_for: '192.0.43.10' )
			app.required_perms_for( req ).should == [ :auth_test ]
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
					app.auth_provider.should_not_receive( :authenticate )
					app.auth_provider.should_receive( :authorize )

					app.handle( req )
				end

				it "authenticates a request that only matches the auth criteria" do
					req = @request_factory.get( '/api/v1/onlyauth' )

					app = @app.new
					app.auth_provider.should_receive( :authenticate )
					app.auth_provider.should_not_receive( :authorize )

					app.handle( req )
				end

				it "authenticates and authorizes a request that matches both" do
					req = @request_factory.get( '/api/v1/both' )

					app = @app.new
					app.auth_provider.should_receive( :authenticate )
					app.auth_provider.should_receive( :authorize )

					app.handle( req )
				end

				it "doesn't do either for a request that doesn't match either" do
					req = @request_factory.get( '/api/v1/neither' )

					app = @app.new
					app.auth_provider.should_not_receive( :authenticate )
					app.auth_provider.should_not_receive( :authorize )

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
					app.auth_provider.should_not_receive( :authenticate )
					app.auth_provider.should_not_receive( :authorize )

					app.handle( req )
				end

				it "authenticates and authorizes a request that only matches the auth criteria"do
					req = @request_factory.get( '/api/v1/onlyauth' )

					app = @app.new
					app.auth_provider.should_receive( :authenticate )
					app.auth_provider.should_receive( :authorize )

					app.handle( req )
				end

				it "only authenticates a request that matches both" do
					req = @request_factory.get( '/api/v1/both' )

					app = @app.new
					app.auth_provider.should_receive( :authenticate )
					app.auth_provider.should_not_receive( :authorize )

					app.handle( req )
				end

				it "only authorizes a request that doesn't match either" do
					req = @request_factory.get( '/api/v1/neither' )

					app = @app.new
					app.auth_provider.should_not_receive( :authenticate )
					app.auth_provider.should_receive( :authorize )

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
					app.auth_provider.should_receive( :authenticate )
					app.auth_provider.should_receive( :authorize )

					app.handle( req )
				end

				it "doesn't do either for a request that only matches the auth criteria" do
					req = @request_factory.get( '/api/v1/onlyauth' )

					app = @app.new
					app.auth_provider.should_not_receive( :authenticate )
					app.auth_provider.should_not_receive( :authorize )

					app.handle( req )
				end

				it "authorizes a request that matches both" do
					req = @request_factory.get( '/api/v1/both' )

					app = @app.new
					app.auth_provider.should_not_receive( :authenticate )
					app.auth_provider.should_receive( :authorize )

					app.handle( req )
				end

				it "authenticates a request that doesn't match either" do
					req = @request_factory.get( '/api/v1/neither' )

					app = @app.new
					app.auth_provider.should_receive( :authenticate )
					app.auth_provider.should_not_receive( :authorize )

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
					app.auth_provider.should_receive( :authenticate )
					app.auth_provider.should_not_receive( :authorize )

					app.handle( req )
				end

				it "authorizes a request that only matches the auth criteria" do
					req = @request_factory.get( '/api/v1/onlyauth' )

					app = @app.new
					app.auth_provider.should_not_receive( :authenticate )
					app.auth_provider.should_receive( :authorize )

					app.handle( req )
				end

				it "doesn't do either for a request that matches both" do
					req = @request_factory.get( '/api/v1/both' )

					app = @app.new
					app.auth_provider.should_not_receive( :authenticate )
					app.auth_provider.should_not_receive( :authorize )

					app.handle( req )
				end

				it "authenticates and authorizes a request that doesn't match either" do
					req = @request_factory.get( '/api/v1/neither' )

					app = @app.new
					app.auth_provider.should_receive( :authenticate )
					app.auth_provider.should_receive( :authorize )

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
				app.auth_provider.stub!( :authenticate ).and_return( :credentials )
				app.auth_provider.should_receive( :authorize ).with( :credentials, req, [:admin, :upload] )

				app.handle( req )
			end

		end

	end

end

