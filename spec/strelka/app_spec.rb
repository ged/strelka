# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

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
		reset_logging()
	end


	#
	# Helpers
	#

	def make_gemspec( name, version, strelka_dep=true )
		spec = Gem::Specification.new( name, version )
		spec.add_runtime_dependency( 'strelka', '~> 0.0' ) if strelka_dep
		return spec
	end


	#
	# Examples
	#

	it "has a method for loading app class/es from a file" do
		app_file = 'an_app.rb'
		app_path = Pathname( 'an_app.rb' ).expand_path
		app_class = nil

		Kernel.should_receive( :load ).with( app_path.to_s ).and_return do
			app_class = Class.new( Strelka::App )
		end
		Strelka::App.load( app_file ).should == [ app_class ]
	end

	it "has a method for discovering installed Strelka app files" do
		specs = {}
		specs[:donkey]     = make_gemspec( 'donkey',  '1.0.0' )
		specs[:rabbit_old] = make_gemspec( 'rabbit',  '1.0.0' )
		specs[:rabbit_new] = make_gemspec( 'rabbit',  '1.0.8' )
		specs[:bear]       = make_gemspec( 'bear',    '1.0.0', false )
		specs[:giraffe]    = make_gemspec( 'giraffe', '1.0.0' )

		expectation = Gem::Specification.should_receive( :each )
		specs.values.each {|spec| expectation.and_yield(spec) }

		donkey_path  = specs[:donkey].full_gem_path
		rabbit_path  = specs[:rabbit_new].full_gem_path
		giraffe_path = specs[:giraffe].full_gem_path

		Dir.should_receive( :glob ).with( Pathname('data/strelka/{apps,handlers}/**/*') ).
			and_return( [] )
		Dir.should_receive( :glob ).with( "#{giraffe_path}/data/giraffe/{apps,handlers}/**/*" ).
			and_return([ "#{giraffe_path}/data/giraffe/apps/app" ])
		Dir.should_receive( :glob ).with( "#{rabbit_path}/data/rabbit/{apps,handlers}/**/*" ).
			and_return([ "#{rabbit_path}/data/rabbit/apps/subdir/app1.rb",
			             "#{rabbit_path}/data/rabbit/apps/subdir/app2.rb" ])
		Dir.should_receive( :glob ).with( "#{donkey_path}/data/donkey/{apps,handlers}/**/*" ).
			and_return([ "#{donkey_path}/data/donkey/apps/app.rb" ])

		app_paths = Strelka::App.discover_paths

		# app_paths.should have( 4 ).members
		app_paths.should include(
			'donkey'  => [Pathname("#{donkey_path}/data/donkey/apps/app.rb")],
			'rabbit'  => [Pathname("#{rabbit_path}/data/rabbit/apps/subdir/app1.rb"),
			              Pathname("#{rabbit_path}/data/rabbit/apps/subdir/app2.rb")],
			'giraffe' => [Pathname("#{giraffe_path}/data/giraffe/apps/app")]
		)
	end

	it "has a method for loading discovered app classes from installed Strelka app files" do
		gemspec = make_gemspec( 'blood-orgy', '0.0.3' )
		Gem::Specification.should_receive( :each ).and_yield( gemspec ).at_least( :once )

		Dir.should_receive( :glob ).with( Pathname('data/strelka/{apps,handlers}/**/*') ).
			and_return( [] )
		Dir.should_receive( :glob ).with( "#{gemspec.full_gem_path}/data/blood-orgy/{apps,handlers}/**/*" ).
			and_return([ "#{gemspec.full_gem_path}/data/blood-orgy/apps/kurzweil" ])

		Kernel.stub( :load ).
			with( "#{gemspec.full_gem_path}/data/blood-orgy/apps/kurzweil" ).
			and_return do
				Class.new( Strelka::App )
				true
			end

		app_classes = Strelka::App.discover
		app_classes.should have( 1 ).member
		app_classes.first.should be_a( Class )
		app_classes.first.should < Strelka::App
	end

	it "handles exceptions while loading discovered apps" do
		gemspec = make_gemspec( 'blood-orgy', '0.0.3' )
		Gem::Specification.should_receive( :each ).and_yield( gemspec ).at_least( :once )

		Dir.should_receive( :glob ).with( Pathname('data/strelka/{apps,handlers}/**/*') ).
			and_return( [] )
		Dir.should_receive( :glob ).with( "#{gemspec.full_gem_path}/data/blood-orgy/{apps,handlers}/**/*" ).
			and_return([ "#{gemspec.full_gem_path}/data/blood-orgy/apps/kurzweil" ])

		Kernel.stub( :load ).
			with( "#{gemspec.full_gem_path}/data/blood-orgy/apps/kurzweil" ).
			and_raise( SyntaxError.new("kurzweil:1: syntax error, unexpected coffeeshop philosopher") )

		app_classes = Strelka::App.discover
		app_classes.should be_empty()
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
			def self::name; "Strelka::App::NotModified"; end
			extend Strelka::Plugin
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
			def self::name; "Strelka::App::Forbidden"; end
			extend Strelka::Plugin
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

		res.should be_a( Mongrel2::HTTPResponse )
		res.status_line.should == 'HTTP/1.1 403 Forbidden'
		res.content_type.should == 'text/html'
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

		res.should be_a( Mongrel2::HTTPResponse )
		res.content_type.should == 'text/plain'
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

		res.should be_a( Mongrel2::HTTPResponse )
		res.content_type.should == 'text/plain'
		res.body.should be_empty()
		res.headers.content_length.should == "Rendered output.\n".bytesize
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


	it "handles uncaught exceptions with a SERVER_ERROR response" do
		@app.class_eval do
			def handle_request( r )
				raise "Something went wrong."
			end
		end

		res = @app.new.handle( @req )

		res.should be_a( Mongrel2::HTTPResponse )
		res.status.should == HTTP::SERVER_ERROR
		res.content_type = 'text/plain'
		res.body.should =~ /internal server error/i
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

			$0.should =~ /#{@app.inspect}/
			$0.should =~ %r|\{\S+\} tcp://\S+ <-> \S+|
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

			res.should be_a( Mongrel2::HTTPResponse )
			res.status_line.should == 'HTTP/1.1 200 OK'
			res.body.should == "Request was funted by Cragnux/1.1.3!\n"
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

			res.should be_a( Mongrel2::HTTPResponse )
			res.status_line.should == 'HTTP/1.1 200 OK'
			res.header_data.should =~ %r{X-Funted-By: Cragnux/1.1.3}
		end

	end

end

