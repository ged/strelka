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


	it "has an associated session class" do
		Strelka::App::Sessions.session_class.should be_a( Class )
		Strelka::App::Sessions.session_class.should < Strelka::Session
	end

	it "is can be configured to use a different session class" do
		# First, hook the anonymous class up to the 'testing' name using the PluginFactory API
		test_session_class = Class.new( Strelka::Session )
		Strelka::Session.derivatives[ 'testing' ] = test_session_class

		# Now configuring it to use the 'testing' session type should set it to use the 
		# anonymous class
		Strelka::App::Sessions.configure( :session_class => 'testing' )

		Strelka::App::Sessions.session_class.should == test_session_class
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

				def handle( req )
					req.session[ :test ] = 'session data'
					return req.response
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


	end


end

