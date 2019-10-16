# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# frozen-string-literal: true

require 'strelka' unless defined?( Strelka )
require 'strelka/signal_handling'

# Load multiple simultaneous Strelka handlers (of a single type) with
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
		while self.running
			self.reap_children if self.wait_for_signals
		end
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
			Strelka.call_before_fork_hooks
			pid = Process.fork do
				Process.setpgrp
				self.app_class.run
			end
			self.handler_pids << pid
			Process.setpgid( pid, 0 )
		end
	end


	### Clean up after any children that have died.
	def reap_children
		pid, status = Process.waitpid2( -1, Process::WNOHANG|Process::WUNTRACED )
		self.log.debug "  waitpid2 returned: [ %p, %p ]" % [ pid, status ]
		while pid
			self.handler_pids.delete( pid )
			pid, status = Process.waitpid2( -1, Process::WNOHANG|Process::WUNTRACED )
			self.log.debug "  waitpid2 returned: [ %p, %p ]" % [ pid, status ]
		end
	end


	### Kill all current children with the specified +signal+. Returns
	### +true+ if the signal was sent to one or more children.
	def kill_children( signal=:TERM )
		return false if self.handler_pids.empty?

		self.log.info "Sending %s signal to %d task pids: %p." %
			 [ signal, self.handler_pids.length, self.handler_pids ]
		self.handler_pids.each do |pid|
			begin
				Process.kill( signal, pid )
			rescue Errno::ESRCH => err
				self.log.error "%p when trying to %s child %d: %s" %
					[ err.class, signal, pid, err.message ]
			end
		end

		return true
	rescue Errno::ESRCH
		self.log.debug "Ignoring signals to unreaped children."
	end


	### Handle signals.
	def handle_signal( sig )
		self.log.debug "Handling signal %s in PID %d" % [ sig, Process.pid ]
		case sig
		when :INT, :TERM, :QUIT
			if @running
				self.log.warn "%s signal: graceful shutdown" % [ sig ]
				self.kill_children( sig )
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

