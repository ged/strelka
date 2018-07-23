# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require 'mongrel2/handler'
require 'mongrel2/websocket'

require 'strelka' unless defined?( Strelka )
require 'strelka/mixins'
require 'strelka/plugins'
require 'strelka/discovery'


# WebSocket (RFC 6455) Server base class.
#
#   class ChatServer < Strelka::WebSocketServer
#
#       # Set up a Hash for participating users
#       def initialize( * )
#           super
#           @users = {}
#       end
#
#       # Disconnect clients that don't answer a ping
#       plugin :heartbeat
#       heartbeat_rate 5.0
#       idle_timeout 15.0
#
#       # When a websocket is set up, add a new user to the table, but without a nick.
#       on_handshake do |frame|
#           @users[ frame.socket_id ] = nil
#           return frame.response # accept the connection
#       end
#
#       # Handle incoming commands, which should be text frames
#       on_text do |frame|
#           senderid = frame.socket_id
#           data = frame.payload.read
#
#           # If the input starts with '/', it's a command (e.g., /quit, /nick, etc.)
#           output = nil
#           if data.start_with?( '/' )
#               output = self.command( senderid, data[1..-1] )
#           else
#               output = self.say( senderid, data )
#           end
#
#           response = frame.response
#           response.puts( output )
#           return response
#       end
#
#   end # class ChatServer
#
class Strelka::WebSocketServer < Mongrel2::Handler
	extend Strelka::MethodUtilities,
	       Strelka::PluginLoader,
		   Strelka::Discovery


	# Loggability API -- log to the Strelka logger
	log_to :strelka


	### Overridden from Mongrel2::Handler -- use the value returned from .default_appid if
	### one is not specified.
	def self::run( appid=nil )
		appid ||= self.default_appid
		self.log.info "Starting up with appid %p." % [ appid ]
		super( appid )
	end


	### Calculate a default application ID for the class based on either its ID
	### constant or its name and return it.
	def self::default_appid
		self.log.info "Looking up appid for %p" % [ self.class ]
		appid = nil

		if self.const_defined?( :ID )
			appid = self.const_get( :ID )
			self.log.info "  app has an ID: %p" % [ appid ]
		else
			appid = ( self.name || "anonymous#{self.object_id}" ).downcase
			appid.gsub!( /[^[:alnum:]]+/, '-' )
			self.log.info "  deriving one from the class name: %p" % [ appid ]
		end

		return appid
	end


	### Return an instance of the App configured for the handler in the currently-loaded
	### Mongrel2 config that corresponds to the #default_appid.
	def self::default_app_instance
		appid = self.default_appid
		return self.app_instance_for( appid )
	end



	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Dump the application stack when a new instance is created.
	def initialize( * )
		self.class.dump_application_stack
		@connections = {}
		super
	end


	######
	public
	######

	# A Hash of last seen times keyed by [sender ID, connection ID] tuple
	attr_reader :connections


	### Run the app -- overriden to set the process name to something interesting.
	def run
		procname = "%s %s: %p %s" % [ RUBY_ENGINE, RUBY_VERSION, self.class, self.conn ]
		$0 = procname

		super
	end


	### Handle a WebSocket frame in +request+. If not overridden, WebSocket connections are
	### closed with a policy error status.
	def handle_websocket( frame )
		response = nil

		unless frame.opcode == :close
			self.connections[ [frame.sender_id, frame.conn_id] ] = Time.now
		end

		# Dispatch the frame
		response = catch( :close_websocket ) do
			self.log.debug "Incoming WEBSOCKET frame (%p):%s" % [ frame, frame.headers.path ]
			self.handle_frame( frame )
		end

		return response
	end


	### Handle a WebSocket handshake HTTP +request+.
	### :TODO: Register/check for supported Sec-WebSocket-Protocol.
	def handle_websocket_handshake( handshake )
		self.log.warn "Incoming WEBSOCKET_HANDSHAKE request (%p)" % [ handshake.headers.path ]
		self.connections[ [handshake.sender_id, handshake.conn_id] ] = Time.now
		return handshake.response( handshake.protocols.first )
	end


	### Handle a disconnect notice from Mongrel2 via the given +request+. Its return value
	### is ignored.
	def handle_disconnect( request )
		self.log.info "Connection %d closed." % [ request.conn_id ]
		self.connections.delete( [request.sender_id, request.conn_id] )
		self.log.debug "  connections remaining: %p" % [ self.connections ]
		return nil
	end


	#########
	protected
	#########

	### Default frame handler.
	def handle_frame( frame )
		if frame.control?
			self.handle_control_frame( frame )
		else
			self.handle_content_frame( frame )
		end
	end


	### Throw a :close_websocket frame that will close the current connection.
	def close_with( frame, reason )
		self.log.debug "Closing the connection: %p" % [ reason ]

		# Make a CLOSE frame
		frame = frame.response( :close )
		frame.set_status( reason )

		throw :close_websocket, frame
	end


	### Handle an incoming control frame.
	def handle_control_frame( frame )
		self.log.debug "Handling control frame: %p" % [ frame ]

		case frame.opcode
		when :ping
			return frame.response
		when :pong
			return nil
		when :close
			self.conn.reply_close( frame )
			return nil
		else
			self.close_with( frame, CLOSE_BAD_DATA_TYPE )
		end
	end


	### Handle an incoming content frame.
	def handle_content_frame( frame )
		self.log.warn "Unhandled frame type %p" % [ frame.opcode ]
		self.close_with( frame, CLOSE_BAD_DATA_TYPE )
	end


end # class Strelka::WebSocketServer

