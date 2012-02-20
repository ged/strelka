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
require 'strelka/app/restresources'

require 'strelka/behavior/plugin'
require 'mongrel2/config/dsl'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::App::RestResources do
	include Mongrel2::Config::DSL

	before( :all ) do
		setup_logging( :fatal )
		setup_config_db()

		@request_factory = Mongrel2::RequestFactory.new( route: '/api/v1' )
	end

	after( :all ) do
		reset_logging()
	end


	it_should_behave_like( "A Strelka::App Plugin" )


	describe "an including App" do

		before( :each ) do
			Strelka.log.debug "Creating a new Strelka::App"
			@app = Class.new( Strelka::App ) do
				plugin :restresources
				def initialize( appid='rest-test', sspec=TEST_SEND_SPEC, rspec=TEST_RECV_SPEC )
					super
				end
			end
		end


		it "has a Hash of resource objects to the route they're mounted on (collection)" do
			@app.resource_routes.should be_a( Hash )
		end


		describe "with a resource declared using default options" do

			before( :each ) do

				# Create two servers in the config db to test with
				server 'test-server'
				server 'step-server'

				@app.class_eval do
					resource Mongrel2::Config::Server
				end
			end

			after( :each ) do
				# Clear the database after each test
				Mongrel2::Config.subclasses.each {|klass| klass.truncate }
			end

			context "OPTIONS verb" do
				it "has an OPTIONS route for the exposed resource"
			end

			context "GET verb" do
				it "has a GET route to fetch the resource collection" do
					req = @request_factory.get( '/api/v1/servers', 'Accept' => 'application/json' )
					res = @app.new.handle( req )

					res.content_type.should == 'application/json'
					body = Yajl.load( res.body )

					body.should have( 2 ).members
					body.map {|record| record['uuid'] }.should include( 'test-server', 'step-server' )
				end

				it "supports limiting the result set when fetching the resource collection" do
					req = @request_factory.get( '/api/v1/servers?limit=1', 'Accept' => 'application/json' )
					res = @app.new.handle( req )

					res.status.should == HTTP::OK
					res.content_type.should == 'application/json'
					body = Yajl.load( res.body )

					body.should have( 1 ).member
					body[0]['uuid'].should == 'test-server'
				end

				it "supports paging the result set when fetching the resource collection" do
					req = @request_factory.get( '/api/v1/servers?limit=1;offset=1', 'Accept' => 'application/json' )
					res = @app.new.handle( req )

					res.status.should == HTTP::OK
					res.content_type.should == 'application/json'
					body = Yajl.load( res.body )

					body.should have( 1 ).member
					body[0]['uuid'].should == 'step-server'
				end

				it "has a GET route to fetch a single resource by its ID" do
					req = @request_factory.get( '/api/v1/servers/1', 'Accept' => 'application/json' )
					res = @app.new.handle( req )

					res.content_type.should == 'application/json'
					body = Yajl.load( res.body )

					body.should be_a( Hash )
					body['uuid'].should == 'test-server'
				end

				it "returns a NOT FOUND response when fetching a non-existant resource" do
					req = @request_factory.get( '/api/v1/servers/411', 'Accept' => 'application/json' )
					res = @app.new.handle( req )

					res.status.should == HTTP::NOT_FOUND
					res.body.should =~ /no such server/i
				end

				it "returns a NOT FOUND response when fetching a resource with an invalid ID" do
					req = @request_factory.get( '/api/v1/servers/ape-tastic' )
					res = @app.new.handle( req )

					res.status.should == HTTP::NOT_FOUND
					res.body.should =~ /requested resource was not found/i
				end
			end

			context "POST verb" do

				before( :each ) do
					@server_values = {
						'uuid'         => "test-server",
						'access_log'   => "/logs/admin-access.log",
						'error_log'    => "/logs/admin-error.log",
						'chroot'       => "/var/www",
						'pid_file'     => "/var/run/test.pid",
						'default_host' => "localhost",
						'name'         => "Testing Server",
						'bind_addr'    => "127.0.0.1",
						'port'         => '7337',
						'use_ssl'      => '0',
					}
				end

				it "has a POST route to create instances in the resource collection" do
					req = @request_factory.post( '/api/v1/servers' )
					req.content_type = 'application/json'
					req.body = Yajl.dump( @server_values )

					res = @app.new.handle( req )

					res.status.should == HTTP::CREATED
					res.headers.location.should == 'http://localhost:8080/api/v1/servers/3'

					new_server = Mongrel2::Config::Server[ 3 ]

					new_server.uuid.should         == "test-server"
					new_server.access_log.should   == "/logs/admin-access.log"
					new_server.error_log.should    == "/logs/admin-error.log"
					new_server.chroot.should       == "/var/www"
					new_server.pid_file.should     == "/var/run/test.pid"
					new_server.default_host.should == "localhost"
					new_server.name.should         == "Testing Server"
					new_server.bind_addr.should    == "127.0.0.1"
					new_server.port.should         == 7337
					new_server.use_ssl.should      == 0
				end
			end


			context "PUT verb" do

				before( :each ) do
					@posted_values = {
						'name'      => 'Not A Testing Server',
						'bind_addr' => '0.0.0.0',
					}
				end

				it "has a PUT route to update instances in the resource collection" do
					req = @request_factory.put( '/api/v1/servers/1' )
					req.content_type = 'application/json'
					req.headers.accept = 'application/json'
					req.body = Yajl.dump( @posted_values )

					res = @app.new.handle( req )

					res.status.should == HTTP::NO_CONTENT

					Mongrel2::Config::Server[ 1 ].name.should == 'Not A Testing Server'
					Mongrel2::Config::Server[ 1 ].bind_addr.should == '0.0.0.0'
				end

				it "has a PUT route to mass-update all resources in a collection" do
					req = @request_factory.put( '/api/v1/servers' )
					req.content_type = 'application/json'
					req.body = Yajl.dump({ 'bind_addr' => '0.0.0.0' })

					res = @app.new.handle( req )

					res.status.should == HTTP::NO_CONTENT

					Mongrel2::Config::Server.map( :bind_addr ).uniq.should == ['0.0.0.0']
				end

			end


			context "DELETE verb" do

				it "has a DELETE route to delete single instances in the resource collection" do
					req = @request_factory.delete( '/api/v1/servers/1' )

					res = @app.new.handle( req )

					res.status.should == HTTP::NO_CONTENT

					Mongrel2::Config::Server.count.should == 1
				end

				it "has a DELETE route to mass-delete all resources in a collection" do
					req = @request_factory.delete( '/api/v1/servers' )

					res = @app.new.handle( req )

					res.status.should == HTTP::NO_CONTENT

					Mongrel2::Config::Server.count.should == 0
				end

			end

		end

	end

end

