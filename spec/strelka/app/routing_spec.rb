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


	it_should_behave_like( "A Strelka::App Plugin" )


	describe "an including App" do

		before( :each ) do
			Strelka.log.debug "Creating a new Strelka::App"
			@app = Class.new( Strelka::App ) do
				plugin :routing
				def initialize( appid='params-test', sspec=TEST_SEND_SPEC, rspec=TEST_RECV_SPEC )
					super
				end
			end
			Strelka.log.debug "  new instance is: %p, routes array: 0x%016x" %
				[ @app, @app.routes.object_id * 2 ]
		end


		it "has an Array of raw routes" do
			@app.routes.should be_a( Array )
		end

		it "knows what its route methods are" do
			@app.route_methods.should == []
			@app.class_eval do
				get() {}
				post( '/clowns' ) {}
				options( '/clowns' ) {}
			end

			@app.route_methods.should == [ :GET, :POST_clowns, :OPTIONS_clowns ]
		end

		# OPTIONS GET/HEAD POST PUT DELETE TRACE CONNECT

		it "can declare a OPTIONS route" do
			@app.routes.should be_empty()

			@app.class_eval do
				options do |req|
				end
			end

			@app.routes.should == [[ :OPTIONS, [], @app.instance_method(:OPTIONS), {} ]]
		end

		it "can declare a GET route" do
			@app.routes.should be_empty()

			@app.class_eval do
				get do |req|
				end
			end

			@app.routes.should == [[ :GET, [], @app.instance_method(:GET), {} ]]
		end

		it "can declare a POST route" do
			@app.routes.should be_empty()

			@app.class_eval do
				post do |req|
				end
			end

			@app.routes.should == [[ :POST, [], @app.instance_method(:POST), {} ]]
		end

		it "can declare a PUT route" do
			@app.routes.should be_empty()

			@app.class_eval do
				put do |req|
				end
			end

			@app.routes.should == [[ :PUT, [], @app.instance_method(:PUT), {} ]]
		end

		it "can declare a DELETE route" do
			@app.routes.should be_empty()

			@app.class_eval do
				delete do |req|
				end
			end

			@app.routes.should == [[ :DELETE, [], @app.instance_method(:DELETE), {} ]]
		end

		it "can declare a TRACE route" do
			@app.routes.should be_empty()

			@app.class_eval do
				trace do |req|
				end
			end

			@app.routes.should == [[ :TRACE, [], @app.instance_method(:TRACE), {} ]]
		end

		it "can declare a CONNECT route" do
			@app.routes.should be_empty()

			@app.class_eval do
				connect do |req|
				end
			end

			@app.routes.should == [[ :CONNECT, [], @app.instance_method(:CONNECT), {} ]]
		end



		it "allows a route to specify a path" do
			@app.routes.should be_empty()

			@app.class_eval do
				get '/info' do |req|
				end
			end

			@app.routes.should == [[ :GET, ['info'], @app.instance_method(:GET_info), {} ]]
		end

		it "allows a route to omit the leading '/' when specifying a path" do
			@app.class_eval do
				get 'info' do |req|
				end
			end

			@app.routes.should == [[ :GET, ['info'], @app.instance_method(:GET_info), {} ]]
		end


		it "uses the Strelka::App::DefaultRouter as it's router by default" do
			@app.routerclass.should == :default
			@app.new.router.should be_a( Strelka::App::DefaultRouter )
		end

		it "can specify a different Router class than the default" do
			class MyRouter < Strelka::App::Router; end
			@app.class_eval do
				router MyRouter
			end
			@app.routerclass.should equal( MyRouter )
			@app.new.router.should be_a( MyRouter )
		end


		it "has its routes inherited by subclasses" do
			@app.class_eval do
				get( '/info' ) {}
				get( '/about' ) {}
				get( '/origami' ) {}
			end
			subclass = Class.new( @app ) do
				get( '/origami' ) {}
			end

			subclass.routes.should have( 3 ).members

			subclass.routes.
				should include([ :GET, ['info'], @app.instance_method(:GET_info), {} ])
			subclass.routes.
				should include([ :GET, ['about'], @app.instance_method(:GET_about), {} ])
			subclass.routes.
				should include([ :GET, ['origami'], subclass.instance_method(:GET_origami), {} ])
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

				@app.routes.should == 
					[[ :POST, ['userinfo', /(?<username>(?i-mx:[a-z]\w+))/], 
					   @app.instance_method(:POST_userinfo__username), {} ]]
			end

			it "unbinds parameter patterns bound with ^ and $ for the route" do
				@app.class_eval do
					param :username, /^[a-z]\w+$/i
					post '/userinfo/:username' do |req|
					end
				end

				@app.routes.should == 
					[[ :POST, ['userinfo', /(?<username>(?i-mx:[a-z]\w+))/], 
					   @app.instance_method(:POST_userinfo__username), {} ]]
			end

			it "unbinds parameter patterns bound with \\A and \\z for the route" do
				@app.class_eval do
					param :username, /\A[a-z]\w+\z/i
					post '/userinfo/:username' do |req|
					end
				end

				@app.routes.should == 
					[[ :POST, ['userinfo', /(?<username>(?i-mx:[a-z]\w+))/], 
					   @app.instance_method(:POST_userinfo__username), {} ]]
			end

			it "unbinds parameter patterns bound with \\Z for the route" do
				@app.class_eval do
					param :username, /\A[a-z]\w+\Z/i
					post '/userinfo/:username' do |req|
					end
				end

				@app.routes.should == 
					[[ :POST, ['userinfo', /(?<username>(?i-mx:[a-z]\w+))/], 
					   @app.instance_method(:POST_userinfo__username), {} ]]
			end

			it "merges parameters from the route path into the request's param validator" do
				@app.class_eval do
					param :username, /\A[a-z]\w+\Z/i
					get '/userinfo/:username' do |req|
					end
				end

				req = @request_factory.get( '/userinfo/benthik' )
				@app.new.handle( req )

				req.params[:username].should == 'benthik'
			end


			it "raises a ScriptError if a route is defined with a param without it having first " +
			   "been set up" do
				# RSpec's "expect {}.to" construct only rescues RuntimeErrors, so we have to do 
				# this ourselves.
				begin
					@app.get( '/userinfo/:username' ) {}
				rescue ScriptError => err
					Strelka.log.error "%p: %s" % [ err.class, err.message ]
					:pass
				rescue ::Exception => err
					fail "Expected to raise a ScriptError, but raised a %p instead" % [ err ]
				else
					fail "Expected to raise a ScriptError, but nothing was raised."
				end

			end
		end

	end


end

