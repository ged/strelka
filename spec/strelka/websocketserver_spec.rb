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
require 'strelka/websocketserver'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::WebSocketServer do

	before( :all ) do
		setup_logging( :fatal )
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
		reset_logging()
	end


	#
	# Control frame defaults
	#

	it "returns a PONG for PING frames" do
		ping = @frame_factory.ping( '/chat' )
		res = @app.new.handle_websocket( ping )

		res.should be_a( Mongrel2::WebSocket::Frame )
		res.opcode.should == :pong
		res.socket_id.should == ping.socket_id
	end

	it "ignores PONG frames" do
		pong = @frame_factory.pong( '/chat' )
		res = @app.new.handle_websocket( pong )

		res.should be_nil()
	end

	it "closes the connection on CLOSE frames" do
		app = @app.new
		close = @frame_factory.close( '/chat' )

		app.conn.should_receive( :reply_close ).with( close )

		res = app.handle_websocket( close )
		res.should be_nil()
	end

	it "closes the connection with an appropriate error for reserved control opcodes" do
		reserved = @frame_factory.create( '/chat', '', 0xB )
		res = @app.new.handle_websocket( reserved )

		res.should be_a( Mongrel2::WebSocket::Frame )
		res.opcode.should == :close
		res.payload.rewind
		res.payload.read.should =~ /Unhandled data type/i
		res.socket_id.should == reserved.socket_id
	end

	#
	# Content frame defaults
	#

	it "replies with a close frame with a bad data type error for TEXT frames" do
		app = @app.new
		frame = @frame_factory.text( '/chat' )

		res = app.handle_websocket( frame )
		res.should be_a( Mongrel2::WebSocket::Frame )
		res.opcode.should == :close
		res.payload.rewind
		res.payload.read.should =~ /Unhandled data type/i
	end

	it "replies with a close frame with a bad data type error for BINARY frames" do
		app = @app.new
		frame = @frame_factory.binary( '/chat' )

		res = app.handle_websocket( frame )
		res.should be_a( Mongrel2::WebSocket::Frame )
		res.opcode.should == :close
		res.payload.rewind
		res.payload.read.should =~ /Unhandled data type/i
	end

	it "replies with a close frame with a bad data type error for CONTINUATION frames" do
		app = @app.new
		frame = @frame_factory.continuation( '/chat' )

		res = app.handle_websocket( frame )
		res.should be_a( Mongrel2::WebSocket::Frame )
		res.opcode.should == :close
		res.payload.rewind
		res.payload.read.should =~ /Unhandled data type/i
	end

	it "closes the connection with an appropriate error for reserved content opcodes" do
		reserved = @frame_factory.create( '/chat', '', 0x3 )
		res = @app.new.handle_websocket( reserved )

		res.should be_a( Mongrel2::WebSocket::Frame )
		res.opcode.should == :close
		res.payload.rewind
		res.payload.read.should =~ /Unhandled data type/i
		res.socket_id.should == reserved.socket_id
	end


end

