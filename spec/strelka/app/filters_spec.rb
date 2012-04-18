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
require 'strelka/app/filters'

require 'strelka/behavior/plugin'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::App::Filters do

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
				plugin :filters
				def initialize( appid='params-test', sspec=TEST_SEND_SPEC, rspec=TEST_RECV_SPEC )
					super
				end
			end
			Strelka.log.debug "  App class is: %p, filters array: 0x%016x" %
				[ @app, @app.filters.object_id * 2 ]
		end

		it "has its filters config inherited by subclasses" do
			@app.filter :request do |req|
				req.notes['blap'] = true
			end
			subclass = Class.new( @app )

			subclass.filters.should == @app.filters
			subclass.filters.should_not equal( @app.filters )
			subclass.filters[:request].should_not equal( @app.filters[:request] )
			subclass.filters[:response].should_not equal( @app.filters[:response] )
			subclass.filters[:both].should_not equal( @app.filters[:both] )
		end

		it "has a Hash of filters" do
			@app.filters.should be_a( Hash )
		end


		describe "that doesn't declare any filters" do

			it "doesn't have any request filters" do
				@app.request_filters.should be_empty()
			end

			it "doesn't have any response filters" do
				@app.response_filters.should be_empty()
			end

		end


		describe "that declares a filter without a phase" do

			before( :each ) do
				@app.class_eval do
					filter do |reqres|
						if reqres.respond_to?( :notes )
							reqres.notes[:test] = 'filtered notes'
						else
							reqres.body = 'filtered body'
						end
					end
				end
			end

			after( :each ) do
				@app.filters[:request].clear
				@app.filters[:response].clear
				@app.filters[:both].clear
			end


			it "has a single request filter" do
				@app.request_filters.should have(1).member
			end

			it "has a single response filter" do
				@app.response_filters.should have(1).member
			end

			it "passes both the request and the response through it" do
				req = @request_factory.get( '/account/118811' )

				res = @app.new.handle( req )

				req.notes[:test].should == 'filtered notes'
				res.body.should == 'filtered body'
			end

		end

		describe "that declares a request filter" do

			before( :each ) do
				@app.class_eval do
					filter( :request ) do |reqres|
						if reqres.respond_to?( :notes )
							reqres.notes[:test] = 'filtered notes'
						else
							reqres.body = 'filtered body'
						end
					end
				end
			end

			after( :each ) do
				@app.filters[:request].clear
				@app.filters[:response].clear
				@app.filters[:both].clear
			end


			it "has a single request filter" do
				@app.request_filters.should have(1).member
			end

			it "has no response filters" do
				@app.response_filters.should be_empty()
			end

			it "passes just the request through it" do
				req = @request_factory.get( '/account/118811' )

				res = @app.new.handle( req )

				req.notes[:test].should == 'filtered notes'
				res.body.should_not == 'filtered body'
			end

		end

		describe "that declares a response filter" do

			before( :each ) do
				@app.class_eval do
					filter( :response ) do |reqres|
						if reqres.respond_to?( :notes )
							reqres.notes[:test] = 'filtered notes'
						else
							reqres.body = 'filtered body'
						end
					end
				end
			end

			after( :each ) do
				@app.filters[:request].clear
				@app.filters[:response].clear
				@app.filters[:both].clear
			end


			it "has no request filters" do
				@app.request_filters.should be_empty()
			end

			it "has no response filters" do
				@app.response_filters.should have(1).member
			end

			it "passes just the response through it" do
				req = @request_factory.get( '/account/118811' )

				res = @app.new.handle( req )

				req.notes[:test].should == {}
				res.body.should == 'filtered body'
			end

		end

	end


end

