# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# frozen-string-literal: true

require_relative '../../helpers'

require 'rspec'
require 'inversion'

require 'strelka'
require 'strelka/plugins'
require 'strelka/app/errors'

require 'strelka/behavior/plugin'


#####################################################################
###	C O N T E X T S
#####################################################################

RSpec.describe Strelka::App::Errors do

	before( :all ) do
		@request_factory = Mongrel2::RequestFactory.new( route: '' )
	end


	it_should_behave_like( "A Strelka Plugin" )


	describe "an including App" do

		before( :each ) do
			@app = Class.new( Strelka::App ) do
				plugin :errors, :routing
				def initialize( appid='params-test', sspec=TEST_SEND_SPEC, rspec=TEST_RECV_SPEC )
					super
				end
			end
		end

		it "has its status handlers inherited by subclasses" do
			@app.on_status HTTP::OK do
				'blap'
			end
			subclass = Class.new( @app )
			expect( subclass.status_handlers ).to eq( @app.status_handlers )
			expect( subclass.status_handlers ).to_not equal( @app.status_handlers )
		end

		it "doesn't alter normal responses" do
			@app.class_eval do
				get do |req|
					res = req.response
					res.puts "Oh yeah! Kool-Aid!"
					res.status = HTTP::OK
					return res
				end
			end

			req = @request_factory.get( '/koolaid' )
			res = @app.new.handle( req )

			expect( res.status ).to eq( HTTP::OK )
			res.body.rewind
			expect( res.body.read ).to eq( "Oh yeah! Kool-Aid!\n" )
		end

		it "raises an error if a handler is declared with both a template and a block" do
			expect {
				@app.class_eval do
					on_status 404, :a_template do |*|
						# Wait, what am I DOING?!?!
					end
				end
			}.to raise_error( ArgumentError, /don't take a block/i )
		end


		it "raises an error if a template handler is declared but the templating plugin isn't loaded" do
			expect {
				@app.class_eval do
					on_status 404, :a_template
				end
			}.to raise_error( ScriptError, /require the :templating plugin/i )
		end

		it "uses the fallback status handler if an error is encountered in a custom error handler" do
			@app.class_eval do
				on_status 404 do |*|
					raise "A problem with the custom error-handler"
				end
			end

			req = @request_factory.get( '/foom' )
			res = @app.new.handle( req )

			res.body.rewind
			expect( res.body.read ).to match( /internal server error/i )
		end

		it "calls a callback-style handler for any status when finished with BAD_REQUEST" do
			@app.class_eval do
				on_status do |res, info|
					res.body = '(%d) Filthy banana' % [ info[:status] ]
					return res
				end

				get do |req|
					finish_with HTTP::BAD_REQUEST, "Your sandwich is missing something."
				end
			end

			req = @request_factory.get( '/foom' )
			res = @app.new.handle( req )

			expect( res.status ).to eq( HTTP::BAD_REQUEST )
			res.body.rewind
			expect( res.body.read ).to eq( '(400) Filthy banana' )
		end


		it "calls a callback-style handler for NOT_FOUND when the response is NOT_FOUND" do
			@app.class_eval do
				on_status HTTP::NOT_FOUND do |res, _|
					res.body = 'NOPE!'
					return res
				end
			end

			req = @request_factory.get( '/foom' )
			res = @app.new.handle( req )

			res.body.rewind
			expect( res.body.read ).to eq( 'NOPE!' )
		end


		it "calls a callback-style handler for all 400-level statuses when the response is NOT_FOUND" do
			@app.class_eval do
				on_status 400..499 do |res, _|
					res.body = 'Error:  JAMBA'
					return res
				end
			end

			req = @request_factory.get( '/foom' )
			res = @app.new.handle( req )

			res.body.rewind
			expect( res.body.read ).to eq( 'Error:  JAMBA' )
		end

		it "sets the error status info in the transaction notes when the response is handled by a status-handler" do
			@app.class_eval do
				on_status do |res, info|
					res.body = '(%d) Filthy banana' % [ info[:status] ]
					return res
				end

				get do |req|
					finish_with HTTP::BAD_REQUEST, "Your sandwich is missing something."
				end
			end

			req = @request_factory.get( '/foom' )
			res = @app.new.handle( req )

			expect( res.notes[:status_info] ).to include( :status, :message, :headers )
			expect( res.notes[:status_info][:status] ).to eq( HTTP::BAD_REQUEST )
			expect( res.notes[:status_info][:message] ).to eq( "Your sandwich is missing something." )
		end

		it "provides its own exception handler for the request phase" do
			@app.class_eval do
				on_status do |res, info|
					res.body = info[:exception].class.name
					return res
				end

				get do |req|
					raise "An uncaught exception"
				end
			end

			req = @request_factory.get( '/foom' )
			res = @app.new.handle( req )

			expect( res.notes[:status_info] ).to include( :status, :message, :headers, :exception )
			expect( res.notes[:status_info][:status] ).to eq( HTTP::SERVER_ERROR )
			expect( res.notes[:status_info][:message] ).to eq( "An uncaught exception" )
			expect( res.notes[:status_info][:exception] ).to be_a( RuntimeError )
			res.body.rewind
			expect( res.body.read ).to eq( "RuntimeError" )
		end


		context "template-style handlers" do

			before( :all ) do
				basedir = Pathname.new( __FILE__ ).dirname.parent.parent.parent
				specdir = basedir + 'spec'
				specdata = specdir + 'data'

				tmpl_paths = [ specdata ]
				Inversion::Template.configure( :template_paths => tmpl_paths )
			end

			before( :each ) do
				@app.class_eval do
					plugins :templating, :routing
					templates jamba: 'error.tmpl'
					on_status 500, :jamba

					get do |req|
						finish_with HTTP::SERVER_ERROR, "I knitted an extra arm for his hopes and dreams."
					end
				end
			end


			it "renders the response body using the templating plugin" do
				req = @request_factory.get( '/foom' )
				res = @app.new.handle( req )

				res.body.rewind
				expect( res.body.read ).to match( /error-handler template/i )
			end
		end

	end


end



