# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
#encoding: utf-8

require 'strelka' unless defined?( Strelka )
require 'strelka/websocketserver' unless defined?( Strelka::WebSocketServer )
require 'strelka/plugin' unless defined?( Strelka::Plugin )

# Heartbeat logic for Strelka WebSocketServers.
#
# To ping connected clients, and disconnect them after 3 failed pings:
#
#    class ChatServer < Strelka::WebSocketServer
#        plugin :heartbeat
#
#        heartbeat_rate 5.0
#        idle_timeout 15.0
#    end
#
module Strelka::WebSocketServer::Heartbeat
	extend Loggability,
	       Strelka::Plugin
	include Strelka::Constants,
	        Mongrel2::WebSocket::Constants


	# The default number of seconds between heartbeat events
	DEFAULT_HEARTBEAT_RATE = 5.0

	# The default number of seconds between events before a client is disconnected
	DEFAULT_IDLE_TIMEOUT = 15.0


	# Loggability API -- set up logging under the 'strelka' log host
	log_to :strelka

	# Plugins API -- set up load order
	run_outside :routing


	# Class methods to add to servers with a heartbeat.
	module ClassMethods # :nodoc:

		@heartbeat_rate = DEFAULT_HEARTBEAT_RATE
		@idle_timeout = DEFAULT_IDLE_TIMEOUT


		### Get/set the number of seconds between heartbeat events.
		def heartbeat_rate( new_rate=nil )
			@heartbeat_rate = new_rate.to_f if new_rate
			return @heartbeat_rate
		end


		### Get/set the number of seconds between events before a client is disconnected
		def idle_timeout( new_timeout=nil )
			@idle_timeout = new_timeout if new_timeout
			return @idle_timeout
		end


		### Inheritance hook -- inheriting classes inherit their parents' routes table.
		def inherited( subclass )
			super
			subclass.instance_variable_set( :@idle_timeout, self.idle_timeout.dup )
			subclass.instance_variable_set( :@heartbeat_rate, self.heartbeat_rate.dup )
		end

	end # module ClassMethods


	######
	public
	######

	### Called by Mongrel2::Handler when it starts accepting requests. Overridden
	### to start up the heartbeat thread.
	def start_accepting_requests
		self.start_heartbeat
		super
	end


	### Called by Mongrel2::Handler when the server is restarted. Overridden to
	### restart the heartbeat thread.
	def restart
		self.stop_heartbeat
		super
		self.start_heartbeat
	end


	### Called by Mongrel2::Handler when the server is shut down. Overridden to
	### stop the heartbeat thread.
	def shutdown
		self.stop_heartbeat
		super
	end


	### Start a thread that will periodically ping connected sockets and remove any
	### connections that don't reply
	def start_heartbeat
		self.log.info "Starting heartbeat timer."
		@heartbeat_timer = self.reactor.add_periodic_timer( self.class.heartbeat_rate ) do
			self.cull_idle_sockets
			self.ping_all_sockets
		end
	end


	### Tell the heartbeat thread to exit.
	def stop_heartbeat
		self.reactor.remove_timer( @heartbeat_timer )
	end


	### Disconnect any sockets that haven't sent any frames for at least
	### SOCKET_IDLE_TIMEOUT seconds.
	def cull_idle_sockets
		self.log.debug "Culling idle sockets."

		earliest = Time.now - self.class.idle_timeout

		self.connections.each do |(sender_id, conn_id), lastframe|
			next unless earliest > lastframe

			# Make a CLOSE frame
			frame = Mongrel2::WebSocket::Frame.new( sender_id, conn_id, '', {}, '' )
			frame.opcode = :close
			frame.set_status( CLOSE_EXCEPTION )

			# Use the connection directly so we can send a frame and close the
			# connection
			self.conn.reply( frame )
			self.conn.send_close( sender_id, conn_id )
		end
	end


	### Send a PING frame to all connected sockets.
	def ping_all_sockets
		return if self.connections.empty?

		self.log.debug "Pinging %d connected sockets." % [ self.connections.length ]
		self.connections.each do |(sender_id, conn_id), hash|
			frame = Mongrel2::WebSocket::Frame.new( sender_id, conn_id, '', {}, 'heartbeat' )
			frame.opcode = :ping
			frame.fin = true

			self.log.debug "  %s/%d: PING" % [ sender_id, conn_id ]
			self.conn.reply( frame )
		end

		self.log.debug "  done with pings."
	end

end # module Strelka::WebSocketServer::Heartbeat

