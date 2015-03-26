# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require_relative '../helpers'

require 'rspec'
require 'zmq'
require 'mongrel2'

require 'strelka'
require 'strelka/app'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::App do

	before( :all ) do
		@initial_registry = Strelka::App.loaded_plugins.dup
		@request_factory = Mongrel2::RequestFactory.new( route: '/mail' )
		Mongrel2::Config.db = Mongrel2::Config.in_memory_db
		Mongrel2::Config.init_database

		# Skip loading the 'strelka' gem, which probably doesn't exist in the right version
		# in the dev environment
		strelkaspec = make_gemspec( 'strelka', Strelka::VERSION, false )
		loaded_specs = Gem.instance_variable_get( :@loaded_specs )
		loaded_specs['strelka'] = strelkaspec

	end

	before( :each ) do
		Strelka::App.loaded_plugins.clear
		@app = Class.new( Strelka::App ) do
			def initialize( appid=TEST_APPID, sspec=TEST_SEND_SPEC, rspec=TEST_RECV_SPEC )
				super
			end
			def set_signal_handlers; end
			def start_accepting_requests; end
			def restore_signal_handlers; end
		end
		@req = @request_factory.get( '/mail/inbox' )
	end

	after( :each ) do
		@app = nil
	end

	after( :all ) do
		Strelka::App.loaded_plugins = @initial_registry
	end


	#
	# Examples
	#

	it "returns a No Content response by default" do
		res = @app.new.handle( @req )

		expect( res ).to be_a( Mongrel2::HTTPResponse )
		expect( res.status_line ).to eq( 'HTTP/1.1 204 No Content' )
		res.body.rewind
		expect( res.body.read ).to eq( '' )
	end


	it "provides a mechanism for aborting with a status" do

		# make a plugin that always 304s and install it
		not_modified_plugin = Module.new do
			def self::name; "Strelka::App::NotModified"; end
			extend Strelka::Plugin
			def handle_request( r )
				finish_with( HTTP::NOT_MODIFIED, "Unchanged." )
				fail "Shouldn't be reached."
			end
		end
		@app.plugin( not_modified_plugin )

		res = @app.new.handle( @req )

		expect( res ).to be_a( Mongrel2::HTTPResponse )
		expect( res.status_line ).to eq( 'HTTP/1.1 304 Not Modified' )
		res.body.rewind
		expect( res.body.read ).to eq( '' )
	end


	it "creates a simple response body for status responses that can have them" do
		# make an auth plugin that always denies requests
		forbidden_plugin = Module.new do
			def self::name; "Strelka::App::Forbidden"; end
			extend Strelka::Plugin
			def handle_request( r )
				finish_with( HTTP::FORBIDDEN, "You aren't allowed to look at that." )
				fail "Shouldn't be reached."
			end
		end
		@app.plugin( forbidden_plugin )

		res = @app.new.handle( @req )

		expect( res ).to be_a( Mongrel2::HTTPResponse )
		expect( res.status_line ).to eq( 'HTTP/1.1 403 Forbidden' )
		expect( res.content_type ).to eq( 'text/plain' )
		res.body.rewind
		expect( res.body.read ).to eq( "You aren't allowed to look at that.\n" )
	end


	it "uses the specified content type for error responses" do
		# make an auth plugin that always denies requests
		forbidden_plugin = Module.new do
			def self::name; "Strelka::App::Forbidden"; end
			extend Strelka::Plugin
			def handle_request( r )
				finish_with( HTTP::FORBIDDEN, "You aren't allowed to look at that.",
					:content_type => 'text/html' )
				fail "Shouldn't be reached."
			end
		end
		@app.plugin( forbidden_plugin )

		res = @app.new.handle( @req )

		expect( res ).to be_a( Mongrel2::HTTPResponse )
		expect( res.status_line ).to eq( 'HTTP/1.1 403 Forbidden' )
		expect( res.content_type ).to eq( 'text/html' )
		res.body.rewind
		expect( res.body.read ).to eq( "You aren't allowed to look at that.\n" )
	end

	it "sets the error status info in the transaction notes for error responses" do
		forbidden_plugin = Module.new do
			def self::name; "Strelka::App::Forbidden"; end
			extend Strelka::Plugin
			def handle_request( r )
				finish_with( HTTP::FORBIDDEN, "You aren't allowed to look at that." )
				fail "Shouldn't be reached."
			end
		end
		@app.plugin( forbidden_plugin )

		res = @app.new.handle( @req )

		expect( res.notes ).to include( :status_info )
		expect( res.notes[:status_info] ).to include( :status, :message, :headers )
		expect( res.notes[:status_info][:status] ).to eq( HTTP::FORBIDDEN )
		expect( res.notes[:status_info][:message] ).to eq( "You aren't allowed to look at that." )
	end


	it "provides a declarative for setting the default content type of responses" do
		@app.class_eval do
			default_type 'text/css'
			def handle_request( r )
				r.response.puts( "body { font-family: monospace }" )
				r.response
			end
		end

		res = @app.new.handle( @req )

		expect( res ).to be_a( Mongrel2::HTTPResponse )
		expect( res.content_type ).to eq( 'text/css' )
	end

	it "doesn't override an explicitly-set content-type header with the default" do
		@app.class_eval do
			default_type 'text/css'
			def handle_request( r )
				r.response.puts( "I lied, I'm actually returning text." )
				r.response.content_type = 'text/plain'
				r.response
			end
		end

		res = @app.new.handle( @req )

		expect( res ).to be_a( Mongrel2::HTTPResponse )
		expect( res.content_type ).to eq( 'text/plain' )
	end


	it "automatically truncates HEAD responses" do
		@app.class_eval do
			default_type 'text/plain'
			def handle_request( r )
				r.response.puts( "Rendered output." )
				r.response
			end
		end

		req = @request_factory.head( '/mail/inbox' )
		res = @app.new.handle( req )

		expect( res ).to be_a( Mongrel2::HTTPResponse )
		expect( res.content_type ).to eq( 'text/plain' )
		res.body.rewind
		expect( res.body.read ).to eq( '' )
		expect( res.headers.content_length ).to eq( "Rendered output.\n".bytesize )
	end


	it "uses the app's ID constant for the appid if .run is called without one" do
		@app.const_set( :ID, 'testing-app' )
		conn = double( "Mongrel2 connection", close: true )

		expect( Mongrel2::Handler ).to receive( :connection_info_for ).with( 'testing-app' ).
			and_return([ TEST_SEND_SPEC, TEST_RECV_SPEC ])
		expect( Mongrel2::Connection ).to receive( :new ).
			with( 'testing-app', TEST_SEND_SPEC, TEST_RECV_SPEC ).
			and_return( conn )

		@app.run
	end


	it "uses the app's name for the appid if .run is called without one and it has no ID constant" do
		@app.class_eval do
			def self::name; "My::First::Blog" ; end
		end
		conn = double( "Mongrel2 connection", close: true )

		expect( Mongrel2::Handler ).to receive( :connection_info_for ).with( 'my-first-blog' ).
			and_return([ TEST_SEND_SPEC, TEST_RECV_SPEC ])
		expect( Mongrel2::Connection ).to receive( :new ).
			with( 'my-first-blog', TEST_SEND_SPEC, TEST_RECV_SPEC ).
			and_return( conn )

		@app.run
	end


	it "handles uncaught exceptions with a SERVER_ERROR response" do
		@app.class_eval do
			def handle_request( r )
				raise "Something went wrong."
			end
		end

		res = @app.new.handle( @req )

		expect( res ).to be_a( Mongrel2::HTTPResponse )
		expect( res.status ).to eq( HTTP::SERVER_ERROR )
		res.content_type = 'text/plain'
		res.body.rewind
		expect( res.body.read ).to match( /internal server error/i )
	end

	it "isn't in 'developer mode' by default" do
		expect( @app ).to_not be_in_devmode()
	end

	it "can be configured to be in 'developer mode' using the Configurability API" do
		@app.configure( devmode: true )
		expect( @app ).to be_in_devmode()
	end

	it "configures itself to be in 'developer mode' if debugging is enabled" do
		debugsetting = $DEBUG

		begin
			$DEBUG = true
			@app.configure
			expect( @app ).to be_in_devmode()
		ensure
			$DEBUG = debugsetting
		end
	end

	it "closes async uploads with a 413 Request Entity Too Large by default" do
		@req.headers.x_mongrel2_upload_start = 'an/uploaded/file/path'

		app = @app.new
		expect( app.conn ).to receive( :reply ).with( an_instance_of(Strelka::HTTPResponse) )
		expect( app.conn ).to receive( :reply_close ).with( @req )

		res = app.handle_async_upload_start( @req )

		expect( res ).to be_nil()
	end


	describe "process name" do

		before( :all ) do
			$old_0 = $0
		end

		after( :all ) do
			$0 = $old_0
		end

		it "sets the process name to something more interesting than the command line" do
			@app.new.run

			expect( $0 ).to match( /#{@app.inspect}/ )
			expect( $0 ).to match( %r|\{\S+\} tcp://\S+ <-> \S+| )
		end

	end

	describe "plugin hooks" do

		it "provides a plugin hook for plugins to manipulate the request before handling it" do
			# make a fixup plugin that adds a custom x- header to the request
			header_fixup_plugin = Module.new do
				def self::name; "Strelka::App::HeaderFixup"; end
				extend Strelka::Plugin
				def fixup_request( r )
					r.headers[:x_funted_by] = 'Cragnux/1.1.3'
					super
				end
				def handle_request( r )
					res = r.response
					res.puts( "Request was funted by %s!" % [r.headers.x_funted_by] )
					res.status = HTTP::OK
					return res
				end
			end
			@app.plugin( header_fixup_plugin )

			res = @app.new.handle( @req )

			expect( res ).to be_a( Mongrel2::HTTPResponse )
			expect( res.status_line ).to eq( 'HTTP/1.1 200 OK' )
			res.body.rewind
			expect( res.body.read ).to eq( "Request was funted by Cragnux/1.1.3!\n" )
		end


		it "provides a plugin hook for plugins to manipulate the response before it's returned to Mongrel2" do
			# make a fixup plugin that adds a custom x- header to the response
			header_fixup_plugin = Module.new do
				def self::name; "Strelka::App::HeaderFixup"; end
				extend Strelka::Plugin
				def fixup_response( res )
					res.headers.x_funted_by = 'Cragnux/1.1.3'
					super
				end
				def handle_request( r )
					res = r.response
					res.puts( "Funt this" )
					res.status = HTTP::OK
					return res
				end
			end
			@app.plugin( header_fixup_plugin )

			res = @app.new.handle( @req )

			expect( res ).to be_a( Mongrel2::HTTPResponse )
			expect( res.status_line ).to eq( 'HTTP/1.1 200 OK' )
			expect( res.header_data ).to match( %r{X-Funted-By: Cragnux/1.1.3} )
		end

	end

end

