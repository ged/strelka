#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent.parent
	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
}

require 'rspec'

require 'spec/lib/helpers'

require 'strelka'
require 'strelka/app/plugins'
require 'strelka/app/sessions'

require 'strelka/behavior/plugin'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::App::Sessions do

	before( :all ) do
		setup_logging( :fatal )
		@request_factory = Mongrel2::RequestFactory.new( route: '' )
	end

	after( :all ) do
		reset_logging()
	end


	it_should_behave_like( "A Strelka::App Plugin" )


	describe "session-class loading" do
		before( :all ) do
			# First, hook the anonymous class up to the 'testing' name using the PluginFactory API
			@test_session_class = Class.new( Strelka::Session ) do
				class << self; attr_accessor :options; end
				def self::configure( options )
					@options = options
				end
			end
			Strelka::Session.derivatives[ 'testing' ] = @test_session_class
		end

		after( :each ) do
			Strelka::App::Sessions.instance_variable_set( :@session_class, nil )
		end

		it "has a default associated session class" do
			Strelka::App::Sessions.session_class.should be_a( Class )
			Strelka::App::Sessions.session_class.should < Strelka::Session
		end

		it "is can be configured to use a different session class" do
			Strelka::App::Sessions.configure( :session_class => 'testing' )
			Strelka::App::Sessions.session_class.should == @test_session_class
		end

		it "configures the configured session class with default options" do
			Strelka::App::Sessions.configure( :session_class => 'testing' )
			Strelka::App::Sessions.session_class.options.should == Strelka::App::Sessions::DEFAULT_OPTIONS
		end

		it "merges any config options for the configured session class" do
			options = { 'cookie_name' => 'patience' }
			Strelka::App::Sessions.configure( :session_class => 'testing', :options => options )
			Strelka::App::Sessions.session_class.options.
				should == Strelka::App::Sessions::DEFAULT_OPTIONS.merge( options )
		end

		it "uses the default session class if the config doesn't have a session section" do
			Strelka::App::Sessions.configure
			Strelka::App::Sessions.session_class.should be( Strelka::Session::Default )
		end

	end

	describe "an including App" do

		before( :each ) do
			@app = Class.new( Strelka::App ) do
				Strelka.log.info "Anonymous App class: %p" % [ self ]
				Strelka.log.info "ID constant is: %p" % [ const_defined?(:ID) ? const_get(:ID) : "(not defined)" ]

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

			subclass.session_namespace.should == @app.session_namespace
		end

		it "has a default session key that's the same as its appid" do
			@app.session_namespace.should == @app.default_appid
		end

		it "can set its session namespace to something else" do
			@app.class_eval do
				session_namespace :findizzle
			end

			@app.session_namespace.should == :findizzle
		end

		it "extends the request and response classes" do
			@app.install_plugins
			Strelka::HTTPRequest.should < Strelka::HTTPRequest::Session
			Strelka::HTTPResponse.should < Strelka::HTTPResponse::Session
		end

		it "sets the session namespace on requests" do
			req = @request_factory.get( '/foom' )
			res = @app.new.handle( req )
			req.session_namespace.should == @app.default_appid
		end

		it "saves the session automatically" do
			req = @request_factory.get( '/foom' )
			res = @app.new.handle( req )
			res.cookies.should include( Strelka::Session::Default.cookie_options[:name] )
		end

	end


end

