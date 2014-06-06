# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require_relative '../../helpers'

require 'rspec'

require 'strelka'
require 'strelka/plugins'
require 'strelka/app/restresources'

require 'strelka/behavior/plugin'
require 'mongrel2/config/dsl'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::App::RestResources do
	include Mongrel2::Config::DSL

	before( :all ) do
		setup_logging()
		setup_config_db()

		@request_factory = Mongrel2::RequestFactory.new( route: '/api/v1' )

		# Add some dataset methods via various alternative methods to ensure they show up too
		name_selection = Module.new do
			def by_name( name )
				return self.filter( name: name )
			end
		end
		Mongrel2::Config::Server.subset( :with_ephemeral_ports ) { port > 1024 }
		Mongrel2::Config::Server.dataset_module( name_selection )
	end

	after( :all ) do
		reset_logging()
	end


	it_should_behave_like( "A Strelka Plugin" )


	describe "included in an App" do

		before( :each ) do
			@app = Class.new( Strelka::App ) do
				plugin :restresources
				def initialize( appid='rest-test', sspec=TEST_SEND_SPEC, rspec=TEST_RECV_SPEC )
					super
				end
			end
		end


		it "keeps track of what resources are mounted where" do
			expect( @app.resource_verbs ).to be_a( Hash )
			expect( @app.resource_verbs ).to be_empty()
		end


		describe "with a resource declared using default options" do

			subject { @app }

			before( :each ) do
				@app.class_eval do
					resource Mongrel2::Config::Server
				end
			end

			it "keeps track of what resources are mounted where" do
				expect( @app.resource_verbs.size ).to eq(  1  )
				expect( @app.resource_verbs ).to include( 'servers' )
				expect(@app.resource_verbs[ 'servers' ]).
					to include( :OPTIONS, :GET, :HEAD, :POST, :PUT, :DELETE )
			end

			# Reader regular routes
			it { is_expected.to have_route(:OPTIONS, 'servers') }
			it { is_expected.to have_route(:GET,     'servers') }
			it { is_expected.to have_route(:GET,     'servers/:id') }

			# Writer regular routes
			it { is_expected.to have_route(:POST,    'servers') }
			it { is_expected.to have_route(:POST,    'servers/:id') }
			it { is_expected.to have_route(:PUT,     'servers') }
			it { is_expected.to have_route(:PUT,     'servers/:id') }
			it { is_expected.to have_route(:DELETE,  'servers') }
			it { is_expected.to have_route(:DELETE,  'servers/:id') }

			# Reader composite routes
			it { is_expected.to have_route(:GET,     'servers/by_uuid/:uuid') }
			it { is_expected.to have_route(:GET,     'servers/:id/hosts') }
			it { is_expected.to have_route(:GET,     'servers/:id/filters') }

		end


		describe "with a resource declared as read-only" do

			subject { @app }

			before( :each ) do
				@app.class_eval do
					resource Mongrel2::Config::Server, readonly: true
				end
			end

			it "keeps track of what resources are mounted where" do
				expect( @app.resource_verbs.size ).to eq(  1  )
				expect( @app.resource_verbs ).to include( 'servers' )
				expect(@app.resource_verbs[ 'servers' ]).
					to include( :OPTIONS, :GET, :HEAD )
				expect(@app.resource_verbs[ 'servers' ]).
					not_to include( :POST, :PUT, :DELETE )
			end

			# Reader regular routes
			it { is_expected.to have_route(:OPTIONS, 'servers') }
			it { is_expected.to have_route(:GET,     'servers') }
			it { is_expected.to have_route(:GET,     'servers/:id') }

			# Writer regular routes
			it { is_expected.not_to have_route(:POST,    'servers') }
			it { is_expected.not_to have_route(:POST,    'servers/:id') }
			it { is_expected.not_to have_route(:PUT,     'servers') }
			it { is_expected.not_to have_route(:PUT,     'servers/:id') }
			it { is_expected.not_to have_route(:DELETE,  'servers') }
			it { is_expected.not_to have_route(:DELETE,  'servers/:id') }

			# Reader composite routes
			it { is_expected.to have_route(:GET,     'servers/by_uuid/:uuid') }
			it { is_expected.to have_route(:GET,     'servers/:id/hosts') }
			it { is_expected.to have_route(:GET,     'servers/:id/filters') }

		end


		describe "auto-generates routes:" do

			before( :each ) do
				Mongrel2::Config.subclasses.each {|klass| klass.truncate }

				# Create two servers in the config db to test with
				server 'test-server' do
					name "Test"
					host 'main'
					host 'monitor'
					host 'adminpanel'
					host 'api'
					port 80
				end
				server 'step-server' do
					name 'Step'
				end

				@app.class_eval do
					resource Mongrel2::Config::Server
				end
			end

			after( :each ) do
				# Clear the database after each test
				Mongrel2::Config.subclasses.each {|klass| klass.truncate }
			end


			context "OPTIONS route" do

				it "responds to a top-level OPTIONS request with a resource description (JSON Schema?)"

				it "responds to an OPTIONS request for a particular resource with details about it" do
					req = @request_factory.options( '/api/v1/servers' )
					res = @app.new.handle( req )

					expect( res.status ).to eq( HTTP::OK )
					expect( res.headers.allowed.split( /\s*,\s*/ ) ).to include(*%w[GET HEAD POST PUT DELETE])
				end

			end # OPTIONS routes


			context "GET route" do
				it "has a GET route to fetch the resource collection" do
					req = @request_factory.get( '/api/v1/servers', 'Accept' => 'application/json' )
					res = @app.new.handle( req )

					expect( res.content_type ).to eq( 'application/json' )
					body = Yajl.load( res.body )

					expect( body.size ).to eq(  2  )
					expect( body.map {|record| record['uuid'] } ).to include( 'test-server', 'step-server' )
				end

				it "supports limiting the result set when fetching the resource collection" do
					req = @request_factory.get( '/api/v1/servers?limit=1',
						'Accept' => 'application/json' )
					res = @app.new.handle( req )

					expect( res.status ).to eq( HTTP::OK )
					expect( res.content_type ).to eq( 'application/json' )
					body = Yajl.load( res.body )

					expect( body.size ).to eq(  1  )
					expect( body[0]['uuid'] ).to eq( 'test-server' )
				end

				it "supports paging the result set when fetching the resource collection" do
					req = @request_factory.get( '/api/v1/servers?limit=1;offset=1',
						'Accept' => 'application/json' )
					res = @app.new.handle( req )

					expect( res.status ).to eq( HTTP::OK )
					expect( res.content_type ).to eq( 'application/json' )
					body = Yajl.load( res.body )

					expect( body.size ).to eq(  1  )
					expect( body[0]['uuid'] ).to eq( 'step-server' )
				end

				it "supports ordering the result by a single column" do
					req = @request_factory.get( '/api/v1/servers?order=name',
						'Accept' => 'application/json' )
					res = @app.new.handle( req )

					expect( res.status ).to eq( HTTP::OK )
					expect( res.content_type ).to eq( 'application/json' )
					body = Yajl.load( res.body )

					expect( body.size ).to eq(  2  )
					expect( body[0]['name'] ).to eq( 'Step' )
				end

				it "supports ordering the result by multiple columns" do
					req = @request_factory.get( '/api/v1/servers?order=id;order=name',
						 'Accept' => 'application/json' )
					res = @app.new.handle( req )

					expect( res.status ).to eq( HTTP::OK )
					expect( res.content_type ).to eq( 'application/json' )
					body = Yajl.load( res.body )

					expect( body.size ).to eq(  2  )
					expect( body[0]['name'] ).to eq( 'Test' )
				end

				it "has a GET route to fetch a single resource by its ID" do
					req = @request_factory.get( '/api/v1/servers/1', 'Accept' => 'application/json' )
					res = @app.new.handle( req )

					expect( res.content_type ).to eq( 'application/json' )
					body = Yajl.load( res.body )

					expect( body ).to be_a( Hash )
					expect( body['uuid'] ).to eq( 'test-server' )
				end

				it "returns a NOT FOUND response when fetching a non-existant resource" do
					req = @request_factory.get( '/api/v1/servers/411', 'Accept' => 'application/json' )
					res = @app.new.handle( req )

					expect( res.status ).to eq( HTTP::NOT_FOUND )
					res.body.rewind
					expect( res.body.read ).to match( /no such server/i )
				end

				it "returns a NOT FOUND response when fetching a resource with an invalid ID" do
					req = @request_factory.get( '/api/v1/servers/ape-tastic' )
					res = @app.new.handle( req )

					expect( res.status ).to eq( HTTP::NOT_FOUND )
					res.body.rewind
					expect( res.body.read ).to match( /requested resource was not found/i )
				end

				it "has a GET route for fetching the resource via one of its dataset methods" do
					req = @request_factory.get( '/api/v1/servers/by_uuid/test-server',
						 :accept => 'application/json' )
					res = @app.new.handle( req )

					expect( res.status ).to eq( HTTP::OK )
					body = Yajl.load( res.body )

					expect( body ).to be_an( Array )
					expect( body.size ).to eq(  1  )
					expect( body.first ).to be_a( Hash )
					expect( body.first['uuid'] ).to eq( 'test-server' )
				end

				it "has a GET route for fetching the resource via a subset" do
					req = @request_factory.get( '/api/v1/servers/with_ephemeral_ports',
						:accept => 'application/json' )
					res = @app.new.handle( req )

					expect( res.status ).to eq( HTTP::OK )
					body = Yajl.load( res.body )

					expect( body ).to be_an( Array )
					expect( body.size ).to eq(  1  )
					expect( body.first ).to be_a( Hash )
					expect( body.first['port'] ).to be > 1024
				end

				it "has a GET route for methods declared in a named dataset module" do
					req = @request_factory.get( '/api/v1/servers/by_name/Step',
						 :accept => 'application/json' )
					res = @app.new.handle( req )

					expect( res.status ).to eq( HTTP::OK )
					body = Yajl.load( res.body )

					expect( body ).to be_an( Array )
					expect( body.size ).to eq(  1  )
					expect( body.first ).to be_a( Hash )
					expect( body.first['name'] ).to eq( 'Step' )
				end


				it "has a GET route for fetching the resource's associated objects" do
					req = @request_factory.get( '/api/v1/servers/1/hosts' )
					res = @app.new.handle( req )

					expect( res.status ).to eq( HTTP::OK )
					body = Yajl.load( res.body )

					expect( body ).to be_an( Array )
					expect( body.size ).to eq(  4  )
					expect( body.first ).to be_a( Hash )
					expect( body.first['server_id'] ).to eq( 1 )
					expect( body.first['id'] ).to eq( 1 )
				end

				it "supports offset and limits for composite GET routes" do
					req = @request_factory.get( '/api/v1/servers/1/hosts?offset=2;limit=2' )
					res = @app.new.handle( req )

					expect( res.status ).to eq( HTTP::OK )
					body = Yajl.load( res.body )

					expect( body ).to be_an( Array )
					expect( body.size ).to eq(  2  )
					expect( body.first ).to be_a( Hash )
					expect( body.first['server_id'] ).to eq( 1 )
					expect( body.first['id'] ).to eq( 3 )
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

					expect( res.status ).to eq( HTTP::CREATED )
					expect( res.headers.location ).to eq( 'http://localhost:8080/api/v1/servers/3' )

					new_server = Mongrel2::Config::Server[ 3 ]

					expect( new_server.uuid ).to         eq( "test-server" )
					expect( new_server.access_log ).to   eq( "/logs/admin-access.log" )
					expect( new_server.error_log ).to    eq( "/logs/admin-error.log" )
					expect( new_server.chroot ).to       eq( "/var/www" )
					expect( new_server.pid_file ).to     eq( "/var/run/test.pid" )
					expect( new_server.default_host ).to eq( "localhost" )
					expect( new_server.name ).to         eq( "Testing Server" )
					expect( new_server.bind_addr ).to    eq( "127.0.0.1" )
					expect( new_server.port ).to         eq( 7337 )
					expect( new_server.use_ssl ).to      eq( 0 )
				end

				it "has a POST route to update a single resource" do
					server = Mongrel2::Config::Server.create( @server_values )

					req = @request_factory.post( "/api/v1/servers/#{server.id}" )
					req.content_type = 'application/json'
					req.body = Yajl.dump({ 'name' => 'Staging Server' })

					res = @app.new.handle( req )
					server.refresh

					expect( res.status ).to eq( HTTP::NO_CONTENT )
					expect( server.name ).to eq( 'Staging Server' )
					expect( server.uuid ).to eq( @server_values['uuid'] )
				end

				it "ignores attributes that aren't in the allowed columns list"

			end # POST routes


			context "PUT routes" do

				it "has a PUT route to replace instances in the resource collection" do
					req = @request_factory.put( '/api/v1/servers/1' )
					req.content_type = 'application/json'
					req.headers.accept = 'application/json'
					req.body = Yajl.dump({
							'name'         => 'Staging',
							'uuid'         => 'staging',
							'access_log'   => "/logs/staging-access.log",
							'error_log'    => "/logs/staging-error.log",
							'chroot'       => "",
							'pid_file'     => "/var/run/staging.pid",
							'default_host' => "staging.local",
							'port'         => '6455',
						})

					res = @app.new.handle( req )

					expect( res.status ).to eq( HTTP::NO_CONTENT )

					server = Mongrel2::Config::Server[1]
					expect( server.name ).to eq( 'Staging' )
					expect( server.bind_addr ).to eq( '0.0.0.0' )
					expect( server.uuid ).to eq( 'staging' )
				end

				it "has a PUT route to replace all resources in a collection" do
					req = @request_factory.put( '/api/v1/servers' )
					req.content_type = 'application/json'
					req.body = Yajl.dump([
						{
							'name'         => 'Staging Server',
							'uuid'         => 'staging',
							'access_log'   => "/logs/staging-access.log",
							'error_log'    => "/logs/staging-error.log",
							'chroot'       => "",
							'pid_file'     => "/var/run/staging.pid",
							'default_host' => "staging.local",
							'port'         => '6455',
						}
					])

					res = @app.new.handle( req )

					expect( res.status ).to eq( HTTP::NO_CONTENT )

					expect( Mongrel2::Config::Server.count ).to eq( 1 )
					server = Mongrel2::Config::Server.first
					expect( server.name ).to eq( 'Staging Server' )
					expect( server.uuid ).to eq( 'staging' )
				end

			end # PUT routes


			context "DELETE routes" do

				it "has a DELETE route to delete single instances in the resource collection" do
					req = @request_factory.delete( '/api/v1/servers/1' )

					res = @app.new.handle( req )

					expect( res.status ).to eq( HTTP::NO_CONTENT )

					expect( Mongrel2::Config::Server[1] ).to be_nil
					expect( Mongrel2::Config::Server.count ).to eq( 1 )
				end

				it "has a DELETE route to mass-delete all resources in a collection" do
					req = @request_factory.delete( '/api/v1/servers' )

					res = @app.new.handle( req )

					expect( res.status ).to eq( HTTP::NO_CONTENT )

					expect( Mongrel2::Config::Server.count ).to eq( 0 )
				end

			end # DELETE routes

		end # route behaviors


		describe "supports inheritance:" do

			subject do
				@app.resource( Mongrel2::Config::Server )
				Class.new( @app )
			end


			it "has its config inherited by subclass" do
				expect( subject.service_options ).to eq( @app.service_options )
				expect( subject.service_options ).to_not be( @app.service_options )
			end

			it "has its metadata inherited by subclasses" do
				expect( subject.resource_verbs.size ).to eq(  1  )
				expect( subject.resource_verbs ).to include( 'servers' )
				expect(subject.resource_verbs[ 'servers' ]).
					to include( :OPTIONS, :GET, :HEAD, :POST, :PUT, :DELETE )
			end

		end # supports inheritance

	end

end