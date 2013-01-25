# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent.parent
	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
}

require 'rspec'

require 'spec/lib/helpers'

require 'strelka'
require 'strelka/plugins'
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

		it "has its config inherited by subclasses" do
			@app.param :string
			subclass = Class.new( @app )

			subclass.paramvalidator.param_names.should == @app.paramvalidator.param_names
			subclass.paramvalidator.should_not equal( @app.paramvalidator )
		end

		it "has a ParamValidator" do
			@app.paramvalidator.should be_a( Strelka::ParamValidator )
		end

		it "can declare a parameter with a validation pattern" do
			@app.class_eval do
				param :username, /\w+/i
			end

			@app.paramvalidator.param_names.should == [ 'username' ]
		end


		it "can declare a parameter with a block constraint" do
			@app.class_eval do
				param :created_at do |val|
					Time.parse(val) rescue nil
				end
			end

			@app.paramvalidator.param_names.should == [ 'created_at' ]
		end

		it "inherits parameters from its superclass" do
			@app.class_eval do
				param :username, /\w+/i
			end
			subapp = Class.new( @app )

			subapp.paramvalidator.param_names.should == [ 'username' ]
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

