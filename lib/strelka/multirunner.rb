# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# frozen-string-literal: true

require 'strelka' unless defined?( Strelka )
require 'strelka/signal_handling'

# Load multiple simulatneous Strelka handlers (of a single type) with
# proper signal handling.
#
class Strelka::MultiRunner
	extend Loggability
	include Strelka::SignalHandling

	# Loggability API -- set up logging under the 'strelka' log host
	log_to :strelka


	# Signals we understand.
	QUEUE_SIGS = [ :QUIT, :INT, :TERM, :CHLD ]


	### Create a new multirunner instance given a handler +app_class+,
	### and the +number+ of instances to start.
	def initialize( app_class, number=2 )
		@handler_pids = []
		@running      = false
		@app_class    = app_class
		@number       = number

		self.set_up_signal_handling
	end

	# The child handler pids.
	attr_reader :handler_pids

	# In this instance currently managing children?
	attr_reader :running

	# How many handler children to manage.
	attr_reader :number

	# The class name of the handler.
	attr_reader :app_class


	### Start the child handlers via fork(), block for signals.
	def run
		@running = true

		# Set up traps for common signals
		self.set_signal_traps( *QUEUE_SIGS )

		self.log.debug "Starting multirunner loop..."
		self.spawn_children
		self.wait_for_signals while self.running
		self.log.debug "Ending multirunner."

		# Restore the default signal handlers
		self.reset_signal_traps( *QUEUE_SIGS )

		return
	end


	#########
	protected
	#########

	### Start the handlers using fork().
	def spawn_children
		self.number.times do
			pid = Process.fork do
				Process.setpgrp
				self.app_class.run
			end
			self.handler_pids << pid
			Process.setpgid( pid, 0 )
		end
	end


	### Wait on the child associated with the given +pid+, deleting it from the
	### running tasks Hash if successful.
	def reap_children( signal )
		self.handler_pids.dup.each do |pid|
			self.log.debug "  sending %p to pid %p" % [ signal, pid ]
			Process.kill( signal, pid )
			pid, status = Process.waitpid2( pid, Process::WUNTRACED )
			self.log.debug "  waitpid2 returned: [ %p, %p ]" % [ pid, status ]
			self.handler_pids.delete( pid )
		end
	end


	### Handle signals.
	def handle_signal( sig )
		self.log.debug "Handling signal %s in PID %d" % [ sig, Process.pid ]
		case sig
		when :INT, :TERM, :QUIT
			if @running
				self.log.warn "%s signal: graceful shutdown" % [ sig ]
				self.reap_children( sig )
				@running = false
			else
				self.ignore_signals
				self.log.warn "%s signal: forceful shutdown" % [ sig ]
				self.kill_children( :KILL )
				exit!( 255 )
			end

		when :CHLD
			self.log.info "Got SIGCHLD."
			# Just need to wake up, nothing else necessary

		else
			self.log.warn "Unhandled signal %s" % [ sig ]
		end
	end

end # class Strelka::MultiRunner

