#!/usr/bin/ruby
# coding: utf-8

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent

	srcdir = basedir.parent
	mongrel2dir = srcdir + 'Mongrel2/lib'

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( mongrel2dir.to_s ) unless $LOAD_PATH.include?( mongrel2dir.to_s )
	$LOAD_PATH.unshift( basedir.to_s ) unless $LOAD_PATH.include?( basedir.to_s )
	$LOAD_PATH.unshift( libdir.to_s ) unless $LOAD_PATH.include?( libdir.to_s )
}

# SimpleCov test coverage reporting; enable this using the :coverage rake task
if ENV['COVERAGE']
	$stderr.puts "\n\n>>> Enabling coverage report.\n\n"
	require 'simplecov'
	SimpleCov.start do
		add_filter 'spec'
		add_group "Needing tests" do |file|
			file.covered_percent < 90
		end
	end
end

require 'loggability'
require 'configurability'
require 'pathname'
require 'tmpdir'

require 'rspec'
require 'mongrel2'
require 'mongrel2/testing'

require 'strelka'

require 'spec/lib/constants'


### RSpec helper functions.
module Strelka::SpecHelpers
	include Strelka::TestConstants

	###############
	module_function
	###############

	### Make an easily-comparable version vector out of +ver+ and return it.
	def vvec( ver )
		return ver.split('.').collect {|char| char.to_i }.pack('N*')
	end


	### Reset the logging subsystem to its default state.
	def reset_logging
		Loggability.formatter = nil
		Loggability.output_to( $stderr )
		Loggability.level = :fatal
	end


	### Alter the output of the default log formatter to be pretty in SpecMate output
	def setup_logging( level=:fatal )

		# Only do this when executing from a spec in TextMate
		if ENV['HTML_LOGGING'] || (ENV['TM_FILENAME'] && ENV['TM_FILENAME'] =~ /_spec\.rb/)
			logarray = []
			Thread.current['logger-output'] = logarray
			Loggability.output_to( logarray )
			Loggability.format_as( :html )
			Loggability.level = :debug
		else
			Loggability.level = level
		end
	end


	### Set up a Mongrel2 configuration database according to the specified +dbspec+.
	### Set up a Mongrel2 configuration database in memory.
	def setup_config_db
		Mongrel2::Config.db ||= Mongrel2::Config.in_memory_db
		Mongrel2::Config.init_database
		Mongrel2::Config.db.tables.collect {|t| Mongrel2::Config.db[t] }.each( &:truncate )
	end


	# Helper method
	def route( name )
		return {:action => name.to_sym}
	end


	#
	# Matchers
	#

	# Route matcher
	RSpec::Matchers.define( :match_route ) do |routename|
		match do |route|
			route[:action] == routename
		end
	end

	# Collection .all? matcher
	RSpec::Matchers.define( :all_be_a ) do |expected|
		match do |collection|
			collection.all? {|obj| obj.is_a?(expected) }
		end
	end

	# finish_with matcher
	class FinishWithMatcher

		### Create a new matcher for the specified +status+, +expected_message+, and
		### +expected_headers+.
		def initialize( status, expected_message=nil, expected_headers={} )

			# Allow headers, but no message
			if expected_message.is_a?( Hash )
				expected_headers = expected_message
				expected_message = nil
			end

			@expected_status  = status
			@expected_message = expected_message
			@expected_headers = expected_headers || {}

			@failure = nil
		end


		######
		public
		######

		##
		# The data structures expected to be part of the response's status_info.
		attr_reader :expected_status, :expected_message, :expected_headers


		### Also expect a header with the given +name+ and +value+ from the response.
		def and_header( name, value=nil )
			if name.is_a?( Hash )
				self.expected_headers.merge!( name )
			else
				self.expected_headers[ name ] = value
			end
			return self
		end


		### RSpec matcher API -- call the +given_proc+ and ensure that it behaves in
		### the expected manner.
		def matches?( given_proc )
			result = nil
			status_info = catch( :finish ) do
				given_proc.call
				nil
			end

			return self.check_finish( status_info ) &&
			       self.check_status_code( status_info ) &&
			       self.check_message( status_info ) &&
			       self.check_headers( status_info )
		end


		### Check the result from calling the proc to ensure it's a status
		### info Hash, returning true if so, or setting the failure message and
		### returning false if not.
		def check_finish( status_info )
			return true if status_info && status_info.is_a?( Hash )
			@failure = "an abnormal status"
			return false
		end


		### Check the result's status code against the expectation, returning true if
		### it was the same, or setting the failure message and returning false if not.
		def check_status_code( status_info )
			return true if status_info[:status] == self.expected_status
			@failure = "a %d status, but got %d instead" %
				[ self.expected_status, status_info[:status] ]
			return false
		end


		### Check the result's status message against the expectation, returning true if
		### it was present and matched the expectation, or setting the failure message
		### and returning false if not.
		def check_message( status_info )
			msg = self.expected_message or return true

			if msg.respond_to?( :match )
				return true if msg.match( status_info[:message] )
				@failure = "a message matching %p, but got: %p" % [ msg, status_info[:message] ]
				return false
			else
				return true if msg == status_info[:message]
				@failure = "the message %p, but got: %p" % [ msg, status_info[:message] ]
				return false
			end
		end


		### Check the result's headers against the expectation, returning true if all
		### expected headers were present and set to expected values, or setting the failure
		### message and returning false if not.
		def check_headers( status_info )
			headers = self.expected_headers or return true
			return true if headers.empty?

			status_headers = status_info[:headers]
			headers.each do |name, value|
				unless status_value = status_headers[ name ]
					@failure = "a %s header" % [ name ]
					return false
				end

				if value.respond_to?( :match )
					unless value.match( status_value )
						@failure = "a %s header matching %p, but got %p" %
							[ name, value, status_value ]
						return false
					end
				else
					unless value == status_value
						@failure = "the %s header %p, but got %p" %
							[ name, value, status_value ]
						return false
					end
				end
			end

			return true
		end


		### Return a message suitable for describing when the matcher fails when it should succeed.
		def failure_message_for_should
			return "expected response to finish_with %s" % [ @failure ]
		end


		### Return a message suitable for describing when the matcher succeeds when it should fail.
		def failure_message_for_should_not
			return "expected response not to finish_with %s" % [ @failure ]
		end


	end # class FinishWithMatcher


	### Match a response thrown via the +finish_with+ function.
	def finish_with( status, message=nil, headers={} )
		FinishWithMatcher.new( status, message, headers )
	end


end


abort "You need a version of RSpec >= 2.6.0" unless defined?( RSpec )

### Mock with RSpec
RSpec.configure do |c|
	include Strelka::TestConstants

	c.mock_with( :rspec )

	c.extend( Strelka::TestConstants )
	c.include( Strelka::TestConstants )
	c.include( Mongrel2::SpecHelpers )
	c.include( Strelka::SpecHelpers )
	# c.include( Strelka::Matchers )
end

# vim: set nosta noet ts=4 sw=4:

