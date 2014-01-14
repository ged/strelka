# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require_relative '../../helpers'

require 'rspec'

require 'strelka'
require 'strelka/plugins'
require 'strelka/app/routing'

require 'strelka/behavior/plugin'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::App::Routing do

	before( :all ) do
		setup_logging( :fatal )
		@request_factory = Mongrel2::RequestFactory.new( route: '' )
	end

	after( :all ) do
		reset_logging()
	end


	it_should_behave_like( "A Strelka Plugin" )


	describe "an including App" do

		before( :each ) do
			@app = Class.new( Strelka::App ) do
				plugin :routing
				def initialize( appid='params-test', sspec=TEST_SEND_SPEC, rspec=TEST_RECV_SPEC )
					super
				end
			end
		end


		it "has an Array of raw routes" do
			expect( @app.routes ).to be_a( Array )
		end

		it "knows what its route methods are" do
			expect( @app.route_methods ).to eq( [] )
			@app.class_eval do
				get() {}
				post( '/clowns' ) {}
				options( '/clowns' ) {}
			end

			expect( @app.route_methods ).to eq( [ :GET, :POST_clowns, :OPTIONS_clowns ] )
		end

		# OPTIONS GET/HEAD POST PUT DELETE TRACE CONNECT

		it "can declare a OPTIONS route" do
			expect( @app.routes ).to be_empty()

			@app.class_eval do
				options do |req|
				end
			end

			expect( @app.routes ).to eq([
				[ :OPTIONS, [], {action: @app.instance_method(:OPTIONS), options: {}} ]
			])
		end

		it "can declare a GET route" do
			expect( @app.routes ).to be_empty()

			@app.class_eval do
				get do |req|
				end
			end

			expect( @app.routes ).to eq([
				[ :GET, [], {action: @app.instance_method(:GET), options: {}} ]
			])
		end

		it "can declare a POST route" do
			expect( @app.routes ).to be_empty()

			@app.class_eval do
				post do |req|
				end
			end

			expect( @app.routes ).to eq([
				[ :POST, [], {action: @app.instance_method(:POST), options: {}} ]
			])
		end

		it "can declare a PUT route" do
			expect( @app.routes ).to be_empty()

			@app.class_eval do
				put do |req|
				end
			end

			expect( @app.routes ).to eq([
				[ :PUT, [], {action: @app.instance_method(:PUT), options: {}} ]
			])
		end

		it "can declare a DELETE route" do
			expect( @app.routes ).to be_empty()

			@app.class_eval do
				delete do |req|
				end
			end

			expect( @app.routes ).to eq([
				[ :DELETE, [], {action: @app.instance_method(:DELETE), options: {}} ]
			])
		end

		it "can declare a TRACE route" do
			expect( @app.routes ).to be_empty()

			@app.class_eval do
				trace do |req|
				end
			end

			expect( @app.routes ).to eq([
				[ :TRACE, [], {action: @app.instance_method(:TRACE), options: {}} ]
			])
		end

		it "can declare a CONNECT route" do
			expect( @app.routes ).to be_empty()

			@app.class_eval do
				connect do |req|
				end
			end

			expect( @app.routes ).to eq([
				[ :CONNECT, [], {action: @app.instance_method(:CONNECT), options: {}} ]
			])
		end



		it "allows a route to specify a path" do
			expect( @app.routes ).to be_empty()

			@app.class_eval do
				get '/info' do |req|
				end
			end

			expect( @app.routes ).to eq([
				[ :GET, ['info'], {action: @app.instance_method(:GET_info), options: {}} ]
			])
		end

		it "allows a route to omit the leading '/' when specifying a path" do
			@app.class_eval do
				get 'info' do |req|
				end
			end

			expect( @app.routes ).to eq([
				[ :GET, ['info'], {action: @app.instance_method(:GET_info), options: {}} ]
			])
		end

		it "allows a route to specify a path via a Regex" do
			@app.class_eval do
				get /\.pdf$/ do
				end
			end

			expect( @app.routes.first[0,2] ).to eq( [ :GET, [/\.pdf$/] ] )
		end


		it "uses the Strelka::Router::Default as it's router by default" do
			expect( @app.routerclass ).to eq( :default )
			expect( @app.new.router ).to be_a( Strelka::Router::Default )
		end

		it "can specify a different Router class than the default" do
			class MyRouter < Strelka::Router; end
			@app.class_eval do
				router MyRouter
			end
			expect( @app.routerclass ).to equal( MyRouter )
			expect( @app.new.router ).to be_a( MyRouter )
		end


		it "has its routes inherited by subclasses" do
			@app.class_eval do
				router :deep
				get( '/info' ) {}
				get( '/about' ) {}
				get( '/origami' ) {}
			end
			subclass = Class.new( @app ) do
				get( '/origami' ) {}
			end

			expect( subclass.routes.size ).to eq(  3  )

			subclass.routes.
				should include([ :GET, ['info'], {action: @app.instance_method(:GET_info), options: {}} ])
			subclass.routes.
				should include([ :GET, ['about'], {action: @app.instance_method(:GET_about), options: {}} ])
			expect( subclass.routes ).to include(
				[ :GET, ['origami'], {action: subclass.instance_method(:GET_origami), options: {}} ]
			)

			expect( subclass.routerclass ).to eq( @app.routerclass )
		end

		describe "that also uses the :parameters plugin" do

			before( :each ) do
				@app.plugin( :parameters )
			end

			it "allows a route to have parameters in it" do
				@app.class_eval do
					param :username, /[a-z]\w+/i
					post '/userinfo/:username' do |req|
					end
				end

				expect( @app.routes ).to eq([
					[ :POST, ['userinfo', /(?<username>[a-z]\w+)/i],
					  {action: @app.instance_method(:POST_userinfo__re_username), options: {}} ]
				])
			end

			it "unbinds parameter patterns bound with ^ and $ for the route" do
				@app.class_eval do
					param :username, /^[a-z]\w+$/i
					post '/userinfo/:username' do |req|
					end
				end

				expect( @app.routes ).to eq([
					[ :POST, ['userinfo', /(?<username>[a-z]\w+)/i],
					  {action: @app.instance_method(:POST_userinfo__re_username), options: {}} ]
				])
			end

			it "unbinds parameter patterns bound with \\A and \\z for the route" do
				@app.class_eval do
					param :username, /\A[a-z]\w+\z/i
					post '/userinfo/:username' do |req|
					end
				end

				expect( @app.routes ).to eq([
					[ :POST, ['userinfo', /(?<username>[a-z]\w+)/i],
					  {action: @app.instance_method(:POST_userinfo__re_username), options: {}} ]
				])
			end

			it "unbinds parameter patterns bound with \\Z for the route" do
				@app.class_eval do
					param :username, /\A[a-z]\w+\Z/i
					post '/userinfo/:username' do |req|
					end
				end

				expect( @app.routes ).to eq([
					[ :POST, ['userinfo', /(?<username>[a-z]\w+)/i],
					  {action: @app.instance_method(:POST_userinfo__re_username), options: {}} ]
				])
			end

			it "merges parameters from the route path into the request's param validator" do
				@app.class_eval do
					param :username, /\A[a-z]\w+\Z/i
					get '/userinfo/:username' do |req|
					end
				end

				req = @request_factory.get( '/userinfo/benthik' )
				@app.new.handle( req )

				expect( req.params[:username] ).to eq( 'benthik' )
			end


			it "raises a ScriptError if a route is defined with a param without it having first " +
			   "been set up" do
				# RSpec's "expect {}.to" construct only rescues RuntimeErrors, so we have to do
				# this ourselves.
				expect {
					@app.get( '/userinfo/:username' ) {}
				}.to raise_error( NameError, /no such parameter "username"/i )

			end
		end

	end


end

