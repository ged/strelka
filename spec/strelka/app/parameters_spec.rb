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
require 'strelka/app/parameters'
require 'strelka/behavior/plugin'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::App::Parameters do

	before( :all ) do
		setup_logging( :fatal )
		@request_factory = Mongrel2::RequestFactory.new( route: '/user' )
	end

	after( :all ) do
		reset_logging()
	end


	it_should_behave_like( "A Strelka::App Plugin" )


	describe "an including App" do

		before( :each ) do
			@app = Class.new( Strelka::App ) do
				plugin :parameters
				def initialize( appid='params-test', sspec=TEST_SEND_SPEC, rspec=TEST_RECV_SPEC )
					super
				end
			end
		end

		after( :each ) do
			@app = nil
		end

		it "has a parameters Hash" do
			@app.parameters.should be_a( Hash )
		end

		it "can declare a parameter with a validation pattern" do
			@app.class_eval do
				param :username, /\w+/i
			end

			@app.parameters.should have( 1 ).member
			@app.parameters[ :username ].
				should include( :constraint => /(?<username>(?i-mx:\w+))/ )
		end

		it "can declare a parameter with an Array validation" do
			@app.class_eval do
				param :username, [:printable, lambda {|str| str.length <= 16 }]
			end

			@app.parameters.should have( 1 ).member
			@app.parameters[:username][:constraint][0].should == :printable
			@app.parameters[:username][:constraint][1].should be_an_instance_of( Proc )
		end

		it "can declare a parameter with a Hash validation" do
			@app.class_eval do
				param :username, {'ambrel' => 'A. Hotchgah'}
			end

			@app.parameters.should have( 1 ).member
			@app.parameters[ :username ].
				should include( :constraint => {'ambrel' => 'A. Hotchgah'} )
		end

		it "can declare a parameter with a matcher validation" do
			@app.class_eval do
				param :host, :hostname
			end

			@app.parameters.should have( 1 ).member
			@app.parameters[ :host ].should include( :constraint => :hostname )
		end

		it "can declare a parameter with a validation pattern and a description" do
			@app.class_eval do
				param :username, /\w+/i, "The user's login"
			end

			@app.parameters.should have( 1 ).member
			@app.parameters[ :username ].should include( :required => false )
			@app.parameters[ :username ].should include( :constraint => /(?<username>(?i-mx:\w+))/ )
			@app.parameters[ :username ].should include( :description => "The user's login" )
		end

		it "can declare a parameter with an Array validation and a description" do
			@app.class_eval do
				param :username, ['johnny5', 'ariel', 'hotah'], "The user's login"
			end

			@app.parameters.should have( 1 ).member
			@app.parameters[ :username ].
				should include( :constraint => ['johnny5', 'ariel', 'hotah'] )
			@app.parameters[ :username ].should include( :description => "The user's login" )
		end

		it "can declare a parameter with just a description" do
			@app.class_eval do
				param :uuid, "UUID string"
			end

			@app.parameters.should have( 1 ).member
			@app.parameters[ :uuid ].should include( :description => "UUID string" )
			@app.parameters[ :uuid ].should include( :constraint => :uuid )
		end

		it "can declare a parameter with a validation pattern and a flag" do
			@app.class_eval do
				param :username, /\w+/i, :untaint
			end

			@app.parameters.should have( 1 ).member
			@app.parameters[ :username ].should include( :required => false )
			@app.parameters[ :username ].should include( :untaint => true )
			@app.parameters[ :username ].should include( :constraint => /(?<username>(?i-mx:\w+))/ )
			@app.parameters[ :username ].should include( :description => nil )
		end

		it "can declare a parameter with a validation Array and a flag" do
			@app.class_eval do
				param :username, ['amhel', 'hotah', 'aurelii'], :required
			end

			@app.parameters.should have( 1 ).member
			@app.parameters[ :username ].should include( :required => true )
			@app.parameters[ :username ].
				should include( :constraint => ['amhel', 'hotah', 'aurelii'] )
			@app.parameters[ :username ].should include( :description => nil )
		end

		it "inherits parameters from its superclass" do
			@app.class_eval do
				param :username, /\w+/i
			end
			subapp = Class.new( @app )

			subapp.parameters.should have( 1 ).member
			subapp.parameters[ :username ].
				should include( :constraint => /(?<username>(?i-mx:\w+))/ )
		end

		describe "instance" do

			before( :each ) do
				@app.class_eval do
					param :username, /\w+/, :required
					param :id, /\d+/
				end
			end

			it "gets requests that have had their parameters replaced with a validator" do
				req = @request_factory.get( '/user/search' )
				@app.new.handle( req )

				req.params.should be_a( Strelka::ParamValidator )
				req.params.should have_errors()
				req.params.error_messages.should == ["Missing value for 'Username'"]
			end

			it "validates parameters from the request" do
				req = @request_factory.get( '/user/search?username=anheptoh'.taint )
				@app.new.handle( req )

				req.params.should be_a( Strelka::ParamValidator )
				req.params.should be_okay()
				req.params.should_not have_errors()
				req.params[:username].should == 'anheptoh'
				req.params[:username].should be_tainted()
			end

			it "untaints all parameters if global untainting is enabled" do
				@app.class_eval do
					untaint_all_constraints true
				end

				@app.untaint_all_constraints.should be_true()
				req = @request_factory.get( '/user/search?username=shereshnaheth'.taint )
				@app.new.handle( req )

				req.params[:username].should == 'shereshnaheth'
				req.params[:username].should_not be_tainted()
			end

			it "untaints parameters flagged for untainting" do
				@app.class_eval do
					param :message, :printable, :untaint
				end

				req = @request_factory.get( '/user/search?message=I+love+the+circus.'.taint )
				@app.new.handle( req )

				req.params[:message].should_not be_tainted()
				req.params[:message].should == 'I love the circus.'
			end

		end

	end


end

