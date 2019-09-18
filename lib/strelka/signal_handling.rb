# -*- ruby -*-
#encoding: utf-8

require 'strelka'


# A module containing signal-handling logic for the 'start' command
# line.
module Strelka::SignalHandling

	### Wrap a block in signal-handling.
	def with_signal_handler( *signals )
		self.set_up_signal_handling
		self.set_signal_traps( *signals )
		self.start_signal_handler

		return yield

	ensure
		self.stop_signal_handler
		self.reset_signal_traps( *signals )
	end


	### Set up data structures for signal handling.
	def set_up_signal_handling
		# Self-pipe for deferred signal-handling (ala djb:
		# http://cr.yp.to/docs/selfpipe.html)
		reader, writer       = IO.pipe
		reader.close_on_exec = true
		writer.close_on_exec = true
		@selfpipe            = { reader: reader, writer: writer }

		# Set up a global signal queue
		Thread.main[:signal_queue] = []
	end


	### The body of the signal handler. Wait for at least one signal to arrive and
	### handle it, or timeout and return if a +timeout+ integer is provided.  This
	### should be called inside a loop, either in its own thread or in another loop
	### that doesn't block anywhere else.  Returns true if a signal was handled, or
	### false if a timeout occurred.
	def wait_for_signals( timeout=nil )

		# Wait on the selfpipe for signals
		# self.log.debug "  waiting for the selfpipe"
		fds = IO.select( [@selfpipe[:reader]], [], [], timeout )
		begin
			rval = @selfpipe[:reader].read_nonblock( 11 )
			self.log.debug "    read from the selfpipe: %p" % [ rval ]
		rescue Errno::EAGAIN, Errno::EINTR => err
			# ignore
		end

		# Look for any signals that arrived and handle them
		while sig = Thread.main[:signal_queue].shift
			self.log.debug "  got a queued signal: %p" % [ sig ]
			self.handle_signal( sig )
		end

		return fds ? true : false
	end


	### Wake the main thread up through the self-pipe.
	### Note: since this is a signal-handler method, it needs to be re-entrant.
	def wake_up
		@selfpipe[:writer].write_nonblock('.')
	rescue Errno::EAGAIN
		# Ignore.
	rescue Errno::EINTR
		# Repeated signal. :TODO: Does this need a counter?
		retry
	end


	### Set up signal handlers for common signals that will shut down, restart, etc.
	def set_signal_traps( *signals )
		self.log.debug "Setting up deferred signal handlers."
		signals.each do |sig|
			Signal.trap( sig ) do
				Thread.main[:signal_queue] << sig
				self.wake_up
			end
		end
	end


	### Set all signal handlers to ignore.
	def ignore_signals( *signals )
		self.log.debug "Ignoring signals."
		signals.each do |sig|
			next if sig == :CHLD
			Signal.trap( sig, :IGNORE )
		end
	end


	### Set the signal handlers back to their defaults.
	def reset_signal_traps( *signals )
		self.log.debug "Restoring default signal handlers."
		signals.each do |sig|
			Signal.trap( sig, :DEFAULT )
		end
	end


	### Simulate the receipt of the specified +signal+ (probably only useful
	### in testing).
	def simulate_signal( signal )
		Thread.main[:signal_queue] << signal.to_sym
		self.wake_up
	end

end # module Strelka::SignalHandling

