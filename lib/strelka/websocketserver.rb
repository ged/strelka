# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# frozen-string-literal: true

require 'set'

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
#       def handle_websocket_handshake( request )
#           @users[ request.socket_id ] = nil
#           return request.response # accept the connection
#       end
#
#       plugin :routing
#
#       # Handle incoming commands, which should be text frames
#       on_text do |request|
#           senderid = request.socket_id
#           data = request.payload.read
#
#           # If the input starts with '/', it's a command (e.g., /quit, /nick, etc.)
#           output = nil
#           if data.start_with?( '/' )
#               output = self.command( senderid, data[1..-1] )
#           else
#               output = self.say( senderid, data )
#           end
#
#           response = request.response
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

		@connections = Hash.new {|h, k| h[k] = Set.new }
		@connection_times = Hash.new {|h, k| h[k] = Hash.new }

		super
	end


	######
	public
	######

	##
	# A Hash of sender ID => Set of connection IDs.
	attr_reader :connections

	##
	# A Hash of [sender ID, connection ID] keys => connection Times
	attr_reader :connection_times



	### Run the app -- overriden to set the process name to something interesting.
	def run
		procname = "%s %s: %p %s" % [ RUBY_ENGINE, RUBY_VERSION, self.class, self.conn ]
		$0 = procname

		super
	end


	### Handle a WebSocket frame in +request+. If not overridden, WebSocket connections are
	### closed with a policy error status.
	def handle_websocket( request )
		response = nil

		self.connection_times[ request.sender_id ][ request.conn_id ] = Time.now

		# Dispatch the request
		response = catch( :close_websocket ) do
			self.log.debug "Incoming WEBSOCKET request (%p):%s" % [ request, request.headers.path ]
			self.handle_websocket_request( request )
		end

		return response
	end


	### Handle a WebSocket handshake HTTP +request+.
	### :TODO: Register/check for supported Sec-WebSocket-Protocol.
	def handle_websocket_handshake( handshake )
		self.log.info "Incoming WEBSOCKET_HANDSHAKE request (%p)" % [ handshake.headers.path ]
		self.connections[ handshake.sender_id ].add( handshake.conn_id )
		self.connection_times[ handshake.sender_id ][ handshake.conn_id ] = Time.now
		self.log.debug "  connections: %p" % [ self.connections ]

		return handshake.response( handshake.protocols.first )
	end


	### Handle a disconnect notice from Mongrel2 via the given +request+. Its return value
	### is ignored.
	def handle_disconnect( request )
		self.log.info "Connection %d closed." % [ request.conn_id ]
		self.connection_times[ request.sender_id ].delete( request.conn_id )
		self.connections.delete( request.sender_id )
		self.log.debug "  connections remaining: %p" % [ self.connections ]

		return nil
	end


	### Return the Time of the last frame from the client associated with the given
	### +request+.
	def last_connection_time( request )
		table = self.connection_times[ request.sender_id ] or return nil
		return table[ request.conn_id ]
	end


	### Send the specified +frame+ to all current connections, except those listed in
	### +except+. The +except+ argument is a single [sender_id, conn_id] tuple.
	def broadcast( frame, except: nil )
		self.connections.each do |sender_id, conn_ids|
			id_list = conn_ids.to_a.
				reject {|cid| except&.first == sender_id && except&.last == cid }

			self.log.debug "Broadcasting to %d connections for sender %s" %
				[ conn_ids.length, sender_id ]

			self.conn.broadcast( sender_id, id_list, frame.to_s )
		end
	end


	#########
	protected
	#########

	### Default request handler.
	def handle_websocket_request( request )
		if request.control?
			self.handle_control_request( request )
		else
			self.handle_content_request( request )
		end
	end


	### Throw a response with a 'close' frame that will close the current
	### connection.
	def close_with( request, reason )
		self.log.debug "Closing the connection: %p" % [ reason ]

		# Make a CLOSE response
		response = request.response( :close )
		response.set_status( reason )

		throw :close_websocket, response
	end


	### Handle an incoming request with a control frame.
	def handle_control_request( request )
		self.log.debug "Handling control request: %p" % [ request ]

		case request.opcode
		when :ping
			return request.response
		when :pong
			return nil
		when :close
			self.conn.reply_close( request )
			return nil
		else
			self.close_with( request, CLOSE_BAD_DATA_TYPE )
		end
	end


	### Handle an incoming request with a content frame.
	def handle_content_request( request )
		self.log.warn "Unhandled request type %p" % [ request.opcode ]
		self.close_with( request, CLOSE_BAD_DATA_TYPE )
	end


end # class Strelka::WebSocketServer

