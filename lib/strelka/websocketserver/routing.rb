# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require 'strelka' unless defined?( Strelka )
require 'strelka/websocketserver' unless defined?( Strelka::WebSocketServer )
require 'strelka/plugin' unless defined?( Strelka::Plugin )

# Frame routing logic for Strelka WebSocketServers.
#
# For a protocol that defines its own opcodes:
#
#    class ChatServer
#        plugin :routing
#
#        opcodes :nick => 7,
#                :emote => 8
#
#        on_text do |frame|
#            # ...
#        end
#
#        on_nick do |frame|
#            self.set_nick( frame.socket_id, frame.payload.read )
#        end
#
#
module Strelka::WebSocketServer::Routing
	extend Loggability,
	       Strelka::Plugin
	include Strelka::Constants,
	        Mongrel2::WebSocket::Constants


	# Loggability API -- set up logging under the 'strelka' log host
	log_to :strelka

	# Plugins API -- set up load order
	# run_inside :templating, :filters, :parameters


	# Class methods to add to classes with routing.
	module ClassMethods # :nodoc:

		##
		# The list of routes to pass to the Router when the application is created
		attr_reader :op_callbacks
		@op_callbacks = {}

		##
		# The Hash of opcode names to numeric opcodes
		attr_reader :opcode_map
		@opcode_map = {}

		##
		# The Hash of numeric opcodes to opcode names
		attr_reader :opcode_names
		@opcode_names = {}


		### Declare one or more opcodes in the form:
		###
		### {
		###     <label> => <bit>,
		### }
		def opcodes( hash )
			@opcode_map ||= {}
			@opcode_map.merge!( hash )

			@opcode_names = @opcode_map.invert

			@opcode_map.each do |label, bit|
				self.log.debug "Set opcode %p to %#0x" % [ label, bit ]
				declarative = "on_#{label}"
				block = self.make_declarative( label )
				self.log.debug "  declaring method %p on %p" % [ declarative, self ]
				self.class.send( :define_method, declarative, &block )
			end
		end


		### Make a declarative method for setting the callback for frames with the specified
		### +opcode+ (Symbol).
		def make_declarative( opcode )
			self.log.debug "Making a declarative for %p" % [ opcode ]
			return lambda do |&block|
				self.log.debug "Setting handler for %p frames to %p" % [ opcode, block ]
				methodname = "on_#{opcode}_frame"
				define_method( methodname, &block )
				self.op_callbacks[ opcode ] = self.instance_method( methodname )
			end
		end


		### Inheritance hook -- inheriting classes inherit their parents' routes table.
		def inherited( subclass )
			super
			subclass.instance_variable_set( :@opcode_map, self.opcode_map.dup )
			subclass.instance_variable_set( :@op_callbacks, self.op_callbacks.dup )
		end


		### Extension callback -- install default opcode declaratives when the plugin
		### is registered.
		def self::extended( mod )
			super
			mod.opcodes( Mongrel2::WebSocket::Constants::OPCODE )
		end

	end # module ClassMethods



	### Dispatch the incoming frame to its handler based on its opcode
	def handle_frame( frame )
		self.log.debug "[:routing] Opcode map is: %p" % [ self.class.opcode_map ]
		opname = self.class.opcode_names[ frame.numeric_opcode ]
		self.log.debug "[:routing] Routing frame: %p" % [ opname ]

		handler = self.class.op_callbacks[ opname ] or return super

		return handler.bind( self ).call( frame )
	end

end # module Strelka::WebSocketServer::Routing

