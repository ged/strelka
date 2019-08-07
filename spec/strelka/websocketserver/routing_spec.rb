# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# frozen-string-literal: true

require_relative '../../helpers'

require 'rspec'

require 'strelka'
require 'strelka/plugins'
require 'strelka/websocketserver/routing'

require 'strelka/behavior/plugin'


#####################################################################
###	C O N T E X T S
#####################################################################

RSpec.describe Strelka::WebSocketServer::Routing do

	before( :all ) do
		@request_factory = Mongrel2::WebSocketRequestFactory.new( route: '/chat' )
	end


	it_should_behave_like( "A Strelka Plugin" )


	describe "an including App" do

		let( :app_class ) do
			Class.new( Strelka::WebSocketServer ) do
				plugin :routing
				def initialize( appid='chat-test', sspec=TEST_SEND_SPEC, rspec=TEST_RECV_SPEC )
					super
				end
			end
		end


		it "has an Hash of raw routes" do
			expect( app_class.op_callbacks ).to be_a( Hash )
		end


		it "knows what its route methods are" do
			expect( app_class.op_callbacks ).to eq( {} )
			app_class.class_eval do
				on_text() {}
				on_binary() {}
				on_ping() {}
			end

			expect( app_class.op_callbacks.keys ).to eq([ :text, :binary, :ping ])
		end


		it "allows the declaration of custom opcodes" do
			app_class.opcodes( nick: 0x3 )
			app_class.class_eval do
				on_nick() {}
			end
			expect( app_class.op_callbacks.size ).to eq(  1  )
			expect( app_class.op_callbacks[ :nick ] ).to be_a( UnboundMethod )
		end


		it "dispatches TEXT frames to a text handler if one is declared" do
			app_class.class_eval do
				on_text do |frame|
					res = frame.response
					res.puts( "#{frame.body.read} Yep!" )
					return res
				end
			end

			frame = @request_factory.text( "/chat", "Clowns?" )
			response = app_class.new.handle_websocket( frame )

			expect( response ).to be_a( Mongrel2::WebSocket::Response )
			expect( response.opcode ).to eq( :text )
			response.payload.rewind
			expect( response.payload.read ).to eq( "Clowns? Yep!\n" )
		end


		it "dispatches custom frame type to its handler if one is declared" do
			app_class.class_eval do
				opcodes refresh: 0xb

				on_refresh do |frame|
					return frame.response
				end
			end

			frame = @request_factory.create( '/chat', '', 0xb )
			response = app_class.new.handle_websocket( frame )

			expect( response ).to be_a( Mongrel2::WebSocket::Response )
			expect( response.numeric_opcode ).to eq( 0xb )
		end


		it "falls back to the defaults if a handler isn't declared for a frame" do
			frame = @request_factory.text( '/chat', '' )
			response = app_class.new.handle_websocket( frame )

			expect( response ).to be_a( Mongrel2::WebSocket::Response )
			expect( response.opcode ).to eq( :close )
		end

	end

end

