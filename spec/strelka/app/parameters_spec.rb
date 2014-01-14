# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require_relative '../../helpers'

require 'rspec'

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


	it_should_behave_like( "A Strelka Plugin" )


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

			expect( subclass.paramvalidator.param_names ).to eq( @app.paramvalidator.param_names )
			expect( subclass.paramvalidator ).to_not equal( @app.paramvalidator )
		end

		it "has a ParamValidator" do
			expect( @app.paramvalidator ).to be_a( Strelka::ParamValidator )
		end

		it "can declare a parameter with a regular-expression constraint" do
			@app.class_eval do
				param :username, /\w+/i
			end

			expect( @app.paramvalidator.param_names ).to eq( [ 'username' ] )
		end

		it "can declare a parameter with a builtin constraint" do
			@app.class_eval do
				param :comment_body, :printable
			end

			expect( @app.paramvalidator.param_names ).to eq( [ 'comment_body' ] )
		end

		it "can declare a parameter with a Proc constraint" do
			@app.class_eval do
				param :start_time do |val|
					Time.parse( val ) rescue nil
				end
			end

			expect( @app.paramvalidator.param_names ).to eq( [ 'start_time' ] )
		end


		it "can declare a parameter with a block constraint" do
			@app.class_eval do
				param :created_at do |val|
					Time.parse(val) rescue nil
				end
			end

			expect( @app.paramvalidator.param_names ).to eq( [ 'created_at' ] )
		end


		it "inherits parameters from its superclass" do
			@app.class_eval do
				param :username, /\w+/i
			end
			subapp = Class.new( @app )

			expect( subapp.paramvalidator.param_names ).to eq( [ 'username' ] )
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

				expect( req.params ).to be_a( Strelka::ParamValidator )
				expect( req.params ).to have_errors()
				expect( req.params.error_messages ).to eq( ["Missing value for 'Username'"] )
			end

			it "validates parameters from the request" do
				req = @request_factory.get( '/user/search?username=anheptoh'.taint )
				@app.new.handle( req )

				expect( req.params ).to be_a( Strelka::ParamValidator )
				expect( req.params ).to be_okay()
				expect( req.params ).to_not have_errors()
				expect( req.params[:username] ).to eq( 'anheptoh' )
				expect( req.params[:username] ).to be_tainted()
			end

			it "untaints all parameters if global untainting is enabled" do
				@app.class_eval do
					untaint_all_constraints true
				end

				expect( @app.untaint_all_constraints ).to be_truthy()
				req = @request_factory.get( '/user/search?username=shereshnaheth'.taint )
				@app.new.handle( req )

				expect( req.params[:username] ).to eq( 'shereshnaheth' )
				expect( req.params[:username] ).to_not be_tainted()
			end

			it "untaints parameters flagged for untainting" do
				@app.class_eval do
					param :message, :printable, :untaint
				end

				req = @request_factory.get( '/user/search?message=I+love+the+circus.'.taint )
				@app.new.handle( req )

				expect( req.params[:message] ).to_not be_tainted()
				expect( req.params[:message] ).to eq( 'I love the circus.' )
			end

		end

	end


end

