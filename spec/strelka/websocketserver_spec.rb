# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require_relative '../helpers'

require 'rspec'
require 'mongrel2'

require 'strelka'
require 'strelka/websocketserver'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::WebSocketServer do

	before( :all ) do
		@initial_registry = described_class.loaded_plugins.dup
		@frame_factory = Mongrel2::WebSocketFrameFactory.new( route: '/chat' )
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
		@app = Class.new( described_class ) do
			def initialize( appid=TEST_APPID, sspec=TEST_SEND_SPEC, rspec=TEST_RECV_SPEC )
				super
			end
			def set_signal_handlers; end
			def start_accepting_requests; end
			def restore_signal_handlers; end
		end
	end

	after( :each ) do
		@app = nil
	end

	after( :all ) do
		described_class.loaded_plugins = @initial_registry
	end


	#
	# Control frame defaults
	#

	it "returns a PONG for PING frames" do
		ping = @frame_factory.ping( '/chat' )
		res = @app.new.handle_websocket( ping )

		expect( res ).to be_a( Mongrel2::WebSocket::Frame )
		expect( res.opcode ).to eq( :pong )
		expect( res.socket_id ).to eq( ping.socket_id )
	end

	it "ignores PONG frames" do
		pong = @frame_factory.pong( '/chat' )
		res = @app.new.handle_websocket( pong )

		expect( res ).to be_nil()
	end

	it "closes the connection on CLOSE frames" do
		app = @app.new
		close = @frame_factory.close( '/chat' )

		expect( app.conn ).to receive( :reply_close ).with( close )

		res = app.handle_websocket( close )
		expect( res ).to be_nil()
	end

	it "closes the connection with an appropriate error for reserved control opcodes" do
		reserved = @frame_factory.create( '/chat', '', 0xB )
		res = @app.new.handle_websocket( reserved )

		expect( res ).to be_a( Mongrel2::WebSocket::Frame )
		expect( res.opcode ).to eq( :close )
		res.payload.rewind
		expect( res.payload.read ).to match( /Unhandled data type/i )
		expect( res.socket_id ).to eq( reserved.socket_id )
	end

	#
	# Content frame defaults
	#

	it "replies with a close frame with a bad data type error for TEXT frames" do
		app = @app.new
		frame = @frame_factory.text( '/chat' )

		res = app.handle_websocket( frame )
		expect( res ).to be_a( Mongrel2::WebSocket::Frame )
		expect( res.opcode ).to eq( :close )
		res.payload.rewind
		expect( res.payload.read ).to match( /Unhandled data type/i )
	end

	it "replies with a close frame with a bad data type error for BINARY frames" do
		app = @app.new
		frame = @frame_factory.binary( '/chat' )

		res = app.handle_websocket( frame )
		expect( res ).to be_a( Mongrel2::WebSocket::Frame )
		expect( res.opcode ).to eq( :close )
		res.payload.rewind
		expect( res.payload.read ).to match( /Unhandled data type/i )
	end

	it "replies with a close frame with a bad data type error for CONTINUATION frames" do
		app = @app.new
		frame = @frame_factory.continuation( '/chat' )

		res = app.handle_websocket( frame )
		expect( res ).to be_a( Mongrel2::WebSocket::Frame )
		expect( res.opcode ).to eq( :close )
		res.payload.rewind
		expect( res.payload.read ).to match( /Unhandled data type/i )
	end

	it "closes the connection with an appropriate error for reserved content opcodes" do
		reserved = @frame_factory.create( '/chat', '', 0x3 )
		res = @app.new.handle_websocket( reserved )

		expect( res ).to be_a( Mongrel2::WebSocket::Frame )
		expect( res.opcode ).to eq( :close )
		res.payload.rewind
		expect( res.payload.read ).to match( /Unhandled data type/i )
		expect( res.socket_id ).to eq( reserved.socket_id )
	end


end

