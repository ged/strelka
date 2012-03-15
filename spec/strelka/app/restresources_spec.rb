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


		it "knows what resources are mounted where" do
			@app.resource_verbs.should be_a( Hash )
			@app.resource_verbs.should be_empty()
		end


		describe "with a resource declared using default options" do

			subject { @app }

			before( :each ) do
				@app.class_eval do
					resource Mongrel2::Config::Server
				end
			end

			it "knows about the mounted resource" do
				@app.resource_verbs.should have( 1 ).member
				@app.resource_verbs.should include( 'servers' )
				@app.resource_verbs[ 'servers' ].
					should include( :OPTIONS, :GET, :HEAD, :POST, :PUT, :DELETE )
			end

			# Reader regular routes
			it { should have_route(:OPTIONS, 'servers') }
			it { should have_route(:GET,     'servers') }
			it { should have_route(:GET,     'servers/:id') }

			# Writer regular routes
			it { should have_route(:POST,    'servers') }
			it { should have_route(:PUT,     'servers') }
			it { should have_route(:PUT,     'servers/:id') }
			it { should have_route(:DELETE,  'servers') }
			it { should have_route(:DELETE,  'servers/:id') }

			# Reader composite routes
			it { should have_route(:GET,     'servers/by_uuid/:uuid') }
			it { should have_route(:GET,     'servers/:id/hosts') }
			it { should have_route(:GET,     'servers/:id/filters') }

		end


		describe "with a resource declared as read-only" do

			subject { @app }

			before( :each ) do
				@app.class_eval do
					resource Mongrel2::Config::Server, readonly: true
				end
			end

			it "knows about the mounted resource" do
				@app.resource_verbs.should have( 1 ).member
				@app.resource_verbs.should include( 'servers' )
				@app.resource_verbs[ 'servers' ].
					should include( :OPTIONS, :GET, :HEAD )
				@app.resource_verbs[ 'servers' ].
					should_not include( :POST, :PUT, :DELETE )
			end

			# Reader regular routes
			it { should have_route(:OPTIONS, 'servers') }
			it { should have_route(:GET,     'servers') }
			it { should have_route(:GET,     'servers/:id') }

			# Writer regular routes
			it { should_not have_route(:POST,    'servers') }
			it { should_not have_route(:PUT,     'servers') }
			it { should_not have_route(:PUT,     'servers/:id') }
			it { should_not have_route(:DELETE,  'servers') }
			it { should_not have_route(:DELETE,  'servers/:id') }

			# Reader composite routes
			it { should have_route(:GET,     'servers/by_uuid/:uuid') }
			it { should have_route(:GET,     'servers/:id/hosts') }
			it { should have_route(:GET,     'servers/:id/filters') }

		end


		describe "route behaviors" do

			before( :each ) do
				# Create two servers in the config db to test with
				server 'test-server' do
					host 'main'
					host 'monitor'
					host 'adminpanel'
					host 'api'
				end
				server 'step-server'

				@app.class_eval do
					resource Mongrel2::Config::Server
				end
			end

			after( :each ) do
				# Clear the database after each test
				Mongrel2::Config.subclasses.each {|klass| klass.truncate }
			end

			context "OPTIONS routes" do
				it "responds to a top-level OPTIONS request with a resource description (JSON Schema?)"
				it "responds to an OPTIONS request for a particular resource with details about it" do
					req = @request_factory.options( '/api/v1/servers' )
					res = @app.new.handle( req )

					res.status.should == HTTP::OK
					res.headers.allowed.split( /\s*,\s*/ ).should include(*%w[GET HEAD POST PUT DELETE])
				end
			end # OPTIONS routes


			context "GET routes" do
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

				it "has a GET route for fetching the resource via one of its dataset methods" do
					req = @request_factory.get( '/api/v1/servers/by_uuid/test-server', :accept => 'application/json' )
					res = @app.new.handle( req )

					res.status.should == HTTP::OK
					body = Yajl.load( res.body )

					body.should be_an( Array )
					body.should have( 1 ).member
					body.first.should be_a( Hash )
					body.first['uuid'].should == 'test-server'
				end

				it "has a GET route for fetching the resource's associated objects" do
					req = @request_factory.get( '/api/v1/servers/1/hosts' )
					res = @app.new.handle( req )

					res.status.should == HTTP::OK
					body = Yajl.load( res.body )

					body.should be_an( Array )
					body.should have( 4 ).members
					body.first.should be_a( Hash )
					body.first['server_id'].should == 1
					body.first['id'].should == 1
				end

				it "supports offset and limits for composite GET routes" do
					req = @request_factory.get( '/api/v1/servers/1/hosts?offset=2;limit=2' )
					res = @app.new.handle( req )

					res.status.should == HTTP::OK
					body = Yajl.load( res.body )

					body.should be_an( Array )
					body.should have( 2 ).members
					body.first.should be_a( Hash )
					body.first['server_id'].should == 1
					body.first['id'].should == 3
				end

			end # GET routes


			context "POST routes" do

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
					@host_values = {
						'name'         => 'step',
						'matching'     => 'step.example.com',
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

			end # POST routes


			context "PUT routes" do

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

			end # PUT routes


			context "DELETE routes" do

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

			end # DELETE routes

		end # route behaviors

	end

end