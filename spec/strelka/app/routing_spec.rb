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
			end
			Strelka.log.debug "  new instance is: %p, routes array: 0x%016x" %
				[ @app, @app.routes.object_id * 2 ]
		end


		it "has an Array of raw routes" do
			@app.routes.should be_a( Array )
		end

		it "can declare a GET route" do
			@app.routes.should be_empty()

			@app.class_eval do
				get do |req|
				end
			end

			@app.routes.should == [[ :GET, [], @app.instance_method(:GET), {} ]]
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
			@app.routerclass.should equal( Strelka::App::DefaultRouter )
		end

		it "can specify a different Router class than the default" do
			class MyRouter < Strelka::App::DefaultRouter; end
			@app.class_eval do
				router MyRouter
			end
			@app.routerclass.should equal( MyRouter )
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


			it "raises a ScriptError if a route is defined with a param without it having first " +
			   "been set up" do
				# RSpec's expect {},to only rescues RuntimeErrors, so we have to do this ourselves.
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

