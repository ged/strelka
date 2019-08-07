# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# frozen-string-literal: true

require_relative '../helpers'

require 'rspec'
require 'mongrel2'

require 'strelka'
require 'strelka/websocketserver'


#####################################################################
###	C O N T E X T S
#####################################################################

RSpec.describe Strelka::WebSocketServer do

	before( :all ) do
		@initial_registry = described_class.loaded_plugins.dup
		@request_factory = Mongrel2::WebSocketRequestFactory.new( route: '/chat' )

		Mongrel2::Config.db = Mongrel2::Config.in_memory_db
		Mongrel2::Config.init_database

		# Skip loading the 'strelka' gem, which probably doesn't exist in the right version
		# in the dev environment
		strelkaspec = make_gemspec( 'strelka', Strelka::VERSION, false )
		loaded_specs = Gem.instance_variable_get( :@loaded_specs )
		loaded_specs['strelka'] = strelkaspec
	end

	before( :each ) do
		described_class.loaded_plugins.clear
	end

	after( :all ) do
		described_class.loaded_plugins = @initial_registry
	end


	let( :app_class ) do
		return Class.new( described_class ) do
			def initialize( appid=TEST_APPID, sspec=TEST_SEND_SPEC, rspec=TEST_RECV_SPEC )
				super
			end
			def set_signal_handlers; end
			def start_accepting_requests; end
			def restore_signal_handlers; end
		end
	end


	it "uses the app's ID constant for the appid if .run is called without one" do
		app_class.const_set( :ID, 'chat-server' )
		expect( app_class.default_appid ).to eq( 'chat-server' )
	end


	it "uses the app's name for the appid it has no ID constant" do
		app_class.class_eval do
			def self::name; "Acme::Valhalla::EventServer" ; end
		end

		expect( app_class.default_appid ).to eq( 'acme-valhalla-eventserver' )
	end


	it "accepts websocket handshakes" do
		app = app_class.new
		request = @request_factory.handshake( '/chat' )

		res = app.dispatch_request( request )

		expect( res ).to be_a( Mongrel2::WebSocket::ServerHandshake )
	end


	describe "control frame defaults" do

		it "returns a PONG response for PING requests" do
			ping = @request_factory.ping( '/chat' )

			res = app_class.new.dispatch_request( ping )

			expect( res ).to be_a( Mongrel2::WebSocket::Response )
			expect( res.opcode ).to eq( :pong )
			expect( res.socket_id ).to eq( ping.socket_id )
		end


		it "ignores PONG requests" do
			pong = @request_factory.pong( '/chat' )

			res = app_class.new.dispatch_request( pong )

			expect( res ).to be_nil()
		end


		it "closes the connection on CLOSE requests" do
			app = app_class.new
			close = @request_factory.close( '/chat' )

			expect( app.conn ).to receive( :reply_close ).with( close )

			res = app.dispatch_request( close )

			expect( res ).to be_nil()
		end


		it "closes the connection with an appropriate error for reserved control opcodes" do
			reserved = @request_factory.create( '/chat', '', 0xB )

			res = app_class.new.dispatch_request( reserved )

			expect( res ).to be_a( Mongrel2::WebSocket::Response )
			expect( res.opcode ).to eq( :close )

			res.payload.rewind
			expect( res.payload.read ).to match( /Unhandled data type/i )
			expect( res.socket_id ).to eq( reserved.socket_id )
		end

	end


	describe "content frame defaults" do

		it "replies with a close frame with a bad data type error for TEXT requests" do
			app = app_class.new
			frame = @request_factory.text( '/chat' )

			res = app.dispatch_request( frame )

			expect( res ).to be_a( Mongrel2::WebSocket::Response )
			expect( res.opcode ).to eq( :close )

			res.payload.rewind
			expect( res.payload.read ).to match( /Unhandled data type/i )
		end


		it "replies with a close frame with a bad data type error for BINARY requests" do
			app = app_class.new
			frame = @request_factory.binary( '/chat' )

			res = app.dispatch_request( frame )

			expect( res ).to be_a( Mongrel2::WebSocket::Response )
			expect( res.opcode ).to eq( :close )

			res.payload.rewind
			expect( res.payload.read ).to match( /Unhandled data type/i )
		end


		it "replies with a close frame with a bad data type error for CONTINUATION requests" do
			app = app_class.new
			frame = @request_factory.continuation( '/chat' )

			res = app.dispatch_request( frame )

			expect( res ).to be_a( Mongrel2::WebSocket::Response )
			expect( res.opcode ).to eq( :close )

			res.payload.rewind
			expect( res.payload.read ).to match( /Unhandled data type/i )
		end


		it "closes the connection with an appropriate error for reserved content opcodes" do
			reserved = @request_factory.create( '/chat', '', 0x3 )

			res = app_class.new.dispatch_request( reserved )

			expect( res ).to be_a( Mongrel2::WebSocket::Response )
			expect( res.opcode ).to eq( :close )

			res.payload.rewind
			expect( res.payload.read ).to match( /Unhandled data type/i )
			expect( res.socket_id ).to eq( reserved.socket_id )
		end

	end


	describe "connection registry" do

		it "maintains a table of connections" do
			app = app_class.new
			request = @request_factory.handshake( '/chat' )

			app.dispatch_request( request )

			expect( app.connections ).to include( request.sender_id )
			expect( app.connections[request.sender_id] ).to include( request.conn_id )
		end


		it "tracks when the last request from a client was" do
			app = app_class.new

			request = @request_factory.handshake( '/chat' )
			app.dispatch_request( request )

			request = @request_factory.ping( '/chat', "Hey, I'm awake!" )
			app.dispatch_request( request )

			timestamp = app.last_connection_time( request )

			expect( timestamp ).to be_a( Time )
			expect( timestamp ).to be_within( 1 ).of( Time.now )
		end

	end


	describe "broadcasting" do

		let( :sender1 ) { '2ac271e0-6dfe-11e9-904a-177944ec9af0' }
		let( :sender2 ) { '91562be6-6dfd-11e9-bcf6-63596c9a6a08' }

		let( :factory1 ) do
			Mongrel2::WebSocketRequestFactory.new( route: '/chat', sender_id: sender1, conn_id: 1 )
		end
		let( :factory2 ) do
			Mongrel2::WebSocketRequestFactory.new( route: '/chat', sender_id: sender1, conn_id: 2 )
		end
		let( :factory3 ) do
			Mongrel2::WebSocketRequestFactory.new( route: '/chat', sender_id: sender2, conn_id: 1 )
		end


		it "can broadcast a frame to all current connections" do
			app = app_class.new

			request1 = factory1.handshake( '/chat' )
			app.dispatch_request( request1 )

			request2 = factory2.handshake( '/chat' )
			app.dispatch_request( request2 )

			request3 = factory3.handshake( '/chat' )
			app.dispatch_request( request3 )

			frame = Mongrel2::WebSocket::Frame.text( 'Server running.' )

			expect( app.conn ).to receive( :broadcast ).with( sender1, [1, 2], frame.to_s )
			expect( app.conn ).to receive( :broadcast ).with( sender2, [1], frame.to_s )

			app.broadcast( frame )
		end


		it "can broadcast a frame to all current connections with exceptions" do
			app = app_class.new

			request1 = factory1.handshake( '/chat' )
			app.dispatch_request( request1 )

			request2 = factory2.handshake( '/chat' )
			app.dispatch_request( request2 )

			request3 = factory3.handshake( '/chat' )
			app.dispatch_request( request3 )

			frame = Mongrel2::WebSocket::Frame.text( 'Server running.' )

			expect( app.conn ).to receive( :broadcast ).with( sender1, [1, 2], frame.to_s )
			expect( app.conn ).to_not receive( :broadcast ).with( sender2, [1], frame.to_s )

			app.broadcast( frame, except: [sender2, 1] )
		end

	end

end

