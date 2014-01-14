# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require_relative '../../helpers'

require 'rspec'

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


	it_should_behave_like( "A Strelka Plugin" )


	context "an including App" do

		before( :each ) do
			@app = Class.new( Strelka::App ) do
				plugin :filters
				def initialize( appid='params-test', sspec=TEST_SEND_SPEC, rspec=TEST_RECV_SPEC )
					super
				end
			end
		end

		it "has its filters config inherited by subclasses" do
			@app.filter :request do |req|
				req.notes['blap'] = true
			end
			subclass = Class.new( @app )

			expect( subclass.filters ).to eq( @app.filters )
			expect( subclass.filters ).to_not equal( @app.filters )
			expect( subclass.filters[:request] ).to_not equal( @app.filters[:request] )
			expect( subclass.filters[:response] ).to_not equal( @app.filters[:response] )
			expect( subclass.filters[:both] ).to_not equal( @app.filters[:both] )
		end

		it "has a Hash of filters" do
			expect( @app.filters ).to be_a( Hash )
		end


		context "that doesn't declare any filters" do

			it "doesn't have any request filters" do
				expect( @app.request_filters ).to be_empty()
			end

			it "doesn't have any response filters" do
				expect( @app.response_filters ).to be_empty()
			end

		end


		context "that declares a filter without a phase" do

			before( :each ) do
				@app.filter do |reqres|
					if reqres.is_a?( Strelka::HTTPRequest )
						reqres.notes[:saw][:request] = true
					else
						reqres.notes[:saw][:response] = true
					end
				end
			end

			after( :each ) do
				@app.filters[:request].clear
				@app.filters[:response].clear
				@app.filters[:both].clear
			end


			it "has a single request filter" do
				expect( @app.request_filters.size ).to eq( 1 )
			end

			it "has a single response filter" do
				expect( @app.response_filters.size ).to eq( 1 )
			end

			it "passes both the request and the response through it" do
				req = @request_factory.get( '/account/118811' )

				res = @app.new.handle( req )

				expect( req.notes[:saw][:request] ).to be_truthy()
				expect( res.notes[:saw][:response] ).to be_truthy()
			end

		end

		context "that declares a request filter" do

			before( :each ) do
				@app.filter( :request ) do |reqres|
					if reqres.is_a?( Strelka::HTTPRequest )
						reqres.notes[:saw][:request] = true
					else
						reqres.notes[:saw][:response] = true
					end
				end
			end

			after( :each ) do
				@app.filters[:request].clear
				@app.filters[:response].clear
				@app.filters[:both].clear
			end


			it "has a single request filter" do
				expect( @app.request_filters.size ).to eq( 1 )
			end

			it "has no response filters" do
				expect( @app.response_filters ).to be_empty()
			end

			it "passes just the request through it" do
				req = @request_factory.get( '/account/118811' )

				res = @app.new.handle( req )

				expect( req.notes[:saw][:request] ).to be_truthy()
				expect( res.notes[:saw][:response] ).to be_nil()
			end

		end

		context "that declares a response filter" do

			before( :each ) do
				@app.filter( :response ) do |reqres|
					if reqres.is_a?( Strelka::HTTPRequest )
						reqres.notes[:saw][:request] = true
					else
						reqres.notes[:saw][:response] = true
					end
				end
			end

			after( :each ) do
				@app.filters[:request].clear
				@app.filters[:response].clear
				@app.filters[:both].clear
			end


			it "has no request filters" do
				expect( @app.request_filters ).to be_empty()
			end

			it "has no response filters" do
				expect( @app.response_filters.size ).to eq( 1 )
			end

			it "passes just the response through it" do
				req = @request_factory.get( '/account/118811' )

				res = @app.new.handle( req )

				expect( req.notes[:saw][:request] ).to be_nil()
				expect( res.notes[:saw][:response] ).to be_truthy()
			end

		end


		context "that returns something other than an HTTPResponse from its handler" do

			before( :each ) do
				@app.class_eval do
					plugin :templating
					templates :main => 'spec/data/main.tmpl'
					def handle_request( req )
						super { :main }
					end
				end
			end

			it "still gives the response filter an HTTPResponse" do
				@app.filter( :response ) do |res|
					expect( res ).to be_a( Strelka::HTTPResponse )
				end

				req = @request_factory.get( '/account/118811' )
				res = @app.new.handle( req )

				expect( res.status_line ).to match( /200 ok/i )
			end
		end

	end


end

