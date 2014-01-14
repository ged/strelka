# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require_relative '../../helpers'

require 'rspec'

require 'strelka'
require 'strelka/plugins'
require 'strelka/websocketserver/routing'

require 'strelka/behavior/plugin'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::WebSocketServer::Routing do

	before( :all ) do
		setup_logging()
		@frame_factory = Mongrel2::WebSocketFrameFactory.new( route: '/chat' )
	end

	after( :all ) do
		reset_logging()
	end


	it_should_behave_like( "A Strelka Plugin" )


	describe "an including App" do

		before( :each ) do
			@app = Class.new( Strelka::WebSocketServer ) do
				plugin :routing
				def initialize( appid='chat-test', sspec=TEST_SEND_SPEC, rspec=TEST_RECV_SPEC )
					super
				end
			end
		end


		it "has an Hash of raw routes" do
			expect( @app.op_callbacks ).to be_a( Hash )
		end

		it "knows what its route methods are" do
			expect( @app.op_callbacks ).to eq( {} )
			@app.class_eval do
				on_text() {}
				on_binary() {}
				on_ping() {}
			end

			expect( @app.op_callbacks.keys ).to eq([ :text, :binary, :ping ])
		end

		it "allows the declaration of custom opcodes" do
			@app.opcodes( 0x3 => :nick )
			@app.class_eval do
				on_nick() {}
			end
			expect( @app.op_callbacks.size ).to eq(  1  )
			expect( @app.op_callbacks[ :nick ] ).to be_a( UnboundMethod )
		end


		it "dispatches TEXT frames to a text handler if one is declared" do
			@app.class_eval do
				on_text do |frame|
					res = frame.response
					res.puts( "#{frame.body.read} Yep!" )
					return res
				end
			end

			frame = @frame_factory.text( "/chat", "Clowns?" )
			response = @app.new.handle_websocket( frame )

			expect( response ).to be_a( Mongrel2::WebSocket::Frame )
			expect( response.opcode ).to eq( :text )
			response.body.rewind
			expect( response.body.read ).to eq( "Clowns? Yep!\n" )
		end

		it "dispatches custom frame type to its handler if one is declared" do
			@app.class_eval do
				opcodes 0xB => :refresh

				on_refresh do |frame|
					return frame.response
				end
			end

			frame = @frame_factory.create( '/chat', '', 0xB )
			response = @app.new.handle_websocket( frame )

			expect( response ).to be_a( Mongrel2::WebSocket::Frame )
			expect( response.opcode ).to eq( :reserved )
			expect( response.numeric_opcode ).to eq( 0xB )
		end


		it "falls back to the defaults if a handler isn't declared for a frame" do
			frame = @frame_factory.text( '/chat', '' )
			response = @app.new.handle_websocket( frame )

			expect( response ).to be_a( Mongrel2::WebSocket::Frame )
			expect( response.opcode ).to eq( :close )
		end

	end

end

