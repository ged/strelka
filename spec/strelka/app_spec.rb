#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent
	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
}

require 'rspec'
require 'zmq'
require 'mongrel2'

require 'spec/lib/helpers'

require 'strelka'
require 'strelka/app'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::App do

	before( :all ) do
		setup_logging( :fatal )
		@request_factory = Mongrel2::RequestFactory.new( route: '/mail' )
		Mongrel2::Config.db = Mongrel2::Config.in_memory_db
		Mongrel2::Config.init_database
	end

	before( :each ) do
		@app = Class.new( Strelka::App ) do
			def initialize( appid=TEST_APPID, sspec=TEST_SEND_SPEC, rspec=TEST_RECV_SPEC )
				super
			end
			def run; end # No-op so it doesn't ever really start up
		end
		@req = @request_factory.get( '/mail/inbox' )
	end

	after( :each ) do
		@app = nil
	end

	after( :all ) do
		reset_logging()
	end


	it "returns a No Content response by default" do

		res = @app.new.handle( @req )

		res.should be_a( Mongrel2::HTTPResponse )
		res.status_line.should == 'HTTP/1.1 204 No Content'
		res.body.should == ''
	end


	it "provides a mechanism for aborting with a status" do

		# make a plugin that always 304s and install it
		not_modified_plugin = Module.new do
			extend Strelka::App::Plugin
			def handle_request( r )
				finish_with( HTTP::NOT_MODIFIED, "Unchanged." )
				fail "Shouldn't be reached."
			end
		end
		@app.plugin( not_modified_plugin )

		res = @app.new.handle( @req )

		res.should be_a( Mongrel2::HTTPResponse )
		res.status_line.should == 'HTTP/1.1 304 Not Modified'
		res.body.should == ''
	end


	it "creates a simple response body for status responses that can have them" do
		# make an auth plugin that always denies requests
		forbidden_plugin = Module.new do
			extend Strelka::App::Plugin
			def handle_request( r )
				finish_with( HTTP::FORBIDDEN, "You aren't allowed to look at that." )
				fail "Shouldn't be reached."
			end
		end
		@app.plugin( forbidden_plugin )

		res = @app.new.handle( @req )

		res.should be_a( Mongrel2::HTTPResponse )
		res.status_line.should == 'HTTP/1.1 403 Forbidden'
		res.content_type.should == 'text/plain'
		res.body.should == "You aren't allowed to look at that.\n"
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

		res.should be_a( Mongrel2::HTTPResponse )
		res.content_type.should == 'text/css'
	end


	it "uses the app's ID constant for the appid if .run is called without one" do
		@app.const_set( :ID, 'testing-app' )

		Mongrel2::Handler.should_receive( :connection_info_for ).with( 'testing-app' ).
			and_return([ TEST_SEND_SPEC, TEST_RECV_SPEC ])
		Mongrel2::Connection.should_receive( :new ).
			with( 'testing-app', TEST_SEND_SPEC, TEST_RECV_SPEC ).
			and_return( :a_connection )

		@app.run
	end


	it "uses the app's name for the appid if .run is called without one and it has no ID constant" do
		@app.class_eval do
			def self::name; "My::First::Blog" ; end
		end

		Mongrel2::Handler.should_receive( :connection_info_for ).with( 'my-first-blog' ).
			and_return([ TEST_SEND_SPEC, TEST_RECV_SPEC ])
		Mongrel2::Connection.should_receive( :new ).
			with( 'my-first-blog', TEST_SEND_SPEC, TEST_RECV_SPEC ).
			and_return( :a_connection )

		@app.run
	end


	describe "plugin hooks" do

		it "provides a plugin hook for plugins to manipulate the request before handling it" do
			# make a fixup plugin that adds a custom x- header to the request
			header_fixup_plugin = Module.new do
				extend Strelka::App::Plugin
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

			res.should be_a( Mongrel2::HTTPResponse )
			res.status_line.should == 'HTTP/1.1 200 OK'
			res.body.should == "Request was funted by Cragnux/1.1.3!\n"
		end


		it "provides a plugin hook for plugins to manipulate the response before it's returned to Mongrel2" do
			# make a fixup plugin that adds a custom x- header to the response
			header_fixup_plugin = Module.new do
				extend Strelka::App::Plugin
				def fixup_response( req, res )
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

			res.should be_a( Mongrel2::HTTPResponse )
			res.status_line.should == 'HTTP/1.1 200 OK'
			res.header_data.should =~ %r{X-Funted-By: Cragnux/1.1.3}
		end

	end

end

