# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# frozen-string-literal: true

require_relative '../../helpers'

require 'rspec'

require 'strelka'
require 'strelka/plugins'
require 'strelka/app/sessions'

require 'strelka/behavior/plugin'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::App::Sessions do

	before( :all ) do
		@request_factory = Mongrel2::RequestFactory.new( route: '' )
	end


	it_should_behave_like( "A Strelka Plugin" )


	describe "session-class loading" do
		before( :all ) do
			# First, hook the anonymous class up to the 'testing' name using the PluginFactory API
			@test_session_class = Class.new( Strelka::Session )
			Strelka::Session.derivatives[ 'testing' ] = @test_session_class
		end

		after( :each ) do
			Strelka::App::Sessions.instance_variable_set( :@session_class, nil )
		end

		it "has a default associated session class" do
			Strelka::App::Sessions.configure
			expect( Strelka::App::Sessions.session_class ).to be( Strelka::Session::Default )
		end

		it "is can be configured to use a different session class" do
			Strelka::App::Sessions.configure( :session_class => 'testing' )
			expect( Strelka::App::Sessions.session_class ).to eq( @test_session_class )
		end

	end

	describe "an including App" do


		before( :each ) do
			Strelka::App::Sessions.configure

			@app = Class.new( Strelka::App ) do
				self.log.info "Anonymous App class: %p" % [ self ]
				self.log.info "ID constant is: %p" % [ const_defined?(:ID) ? const_get(:ID) : "(not defined)" ]

				self::ID = 'monkeyshines'
				# Guard against ID leakage
				unless const_defined?( :ID, false )
					raise ScriptError, "Awwww, damn. Apparently ID got defined in a parent class?"
				end
				plugin :sessions

				def initialize( appid='params-test', sspec=TEST_SEND_SPEC, rspec=TEST_RECV_SPEC )
					super
				end

				def handle_request( req )
					super do
						self.log.debug "Session is: %p" % [ req.session ]
						req.session[ :test ] = 'session data'
						req.response
					end
				end
			end
		end

		after( :each ) do
			@app = nil

			# Guard against ID leaking up into the base class
			if Strelka::App.const_defined?( :ID )
				raise ScriptError, "Awww crap. Somehow ID got defined in Strelka::App"
			end
		end

		it "has its config inherited by subclasses" do
			@app.session_namespace :indian_gurbles
			subclass = Class.new( @app )

			expect( subclass.session_namespace ).to eq( @app.session_namespace )
		end

		it "has a default session key that's the same as its appid" do
			expect( @app.session_namespace ).to eq( @app.default_appid )
		end

		it "can set its session namespace to something else" do
			@app.class_eval do
				session_namespace :findizzle
			end

			expect( @app.session_namespace ).to eq( :findizzle )
		end

		it "extends the request and response classes" do
			@app.install_plugins
			expect( Strelka::HTTPRequest ).to be < Strelka::HTTPRequest::Session
			expect( Strelka::HTTPResponse ).to be < Strelka::HTTPResponse::Session
		end

		it "sets the session namespace on requests" do
			req = @request_factory.get( '/foom' )
			res = @app.new.handle( req )
			expect( req.session_namespace ).to eq( @app.default_appid )
		end

		it "saves the session automatically" do
			req = @request_factory.get( '/foom' )
			res = @app.new.handle( req )
			expect( res.cookies ).to include( Strelka::Session::Default.cookie_name )
		end

	end


end

