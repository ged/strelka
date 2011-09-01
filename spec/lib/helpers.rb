#!/usr/bin/ruby
# coding: utf-8

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent
	m2dir = basedir.expand_path.parent + 'Mongrel2'
	m2libdir = m2dir + "lib"

	# Add the Mongrel2 libdir to the LOAD_PATH to allow for parallel development
	$LOAD_PATH.unshift( m2libdir.to_s ) unless $LOAD_PATH.include?( m2libdir.to_s )
}

# SimpleCov test coverage reporting; enable this using the :coverage rake task
if ENV['COVERAGE']
	require 'simplecov'
	SimpleCov.start do
		add_filter 'spec'
		add_group "Config Classes" do |file|
			file.filename =~ %r{/config/}
		end
		add_group "Needing tests" do |file|
			file.covered_percent < 90
		end
	end
end

require 'pathname'
require 'tmpdir'

require 'rspec'
require 'strelka'
require 'spec/lib/constants'

### IRb.start_session, courtesy of Joel VanderWerf in [ruby-talk:42437].
require 'irb'
require 'irb/completion'

module IRB # :nodoc:
	def self.start_session( obj )
		unless @__initialized
			args = ARGV
			ARGV.replace( ARGV.dup )
			IRB.setup( nil )
			ARGV.replace( args )
			@__initialized = true
		end

		workspace = WorkSpace.new( obj )
		irb = Irb.new( workspace )

		@CONF[:IRB_RC].call( irb.context ) if @CONF[:IRB_RC]
		@CONF[:MAIN_CONTEXT] = irb.context

		begin
			prevhandler = Signal.trap( 'INT' ) do
				irb.signal_handle
			end

			catch( :IRB_EXIT ) do
				irb.eval_input
			end
		ensure
			Signal.trap( 'INT', prevhandler )
		end

	end
end




### RSpec helper functions.
module Strelka::SpecHelpers
	include Strelka::TestConstants

	class ArrayLogger
		### Create a new ArrayLogger that will append content to +array+.
		def initialize( array )
			@array = array
		end

		### Write the specified +message+ to the array.
		def write( message )
			@array << message
		end

		### No-op -- this is here just so Logger doesn't complain
		def close; end

	end # class ArrayLogger


	unless defined?( LEVEL )
		LEVEL = {
			:debug => Logger::DEBUG,
			:info  => Logger::INFO,
			:warn  => Logger::WARN,
			:error => Logger::ERROR,
			:fatal => Logger::FATAL,
		  }
	end

	###############
	module_function
	###############

	### Make an easily-comparable version vector out of +ver+ and return it.
	def vvec( ver )
		return ver.split('.').collect {|char| char.to_i }.pack('N*')
	end


	### Reset the logging subsystem to its default state.
	def reset_logging
		Strelka.reset_logger
	end


	### Alter the output of the default log formatter to be pretty in SpecMate output
	def setup_logging( level=Logger::FATAL )

		# Turn symbol-style level config into Logger's expected Fixnum level
		if Strelka::Logging::LOG_LEVELS.key?( level.to_s )
			level = Strelka::Logging::LOG_LEVELS[ level.to_s ]
		end

		logger = Logger.new( $stderr )
		Strelka.logger = logger
		Strelka.logger.level = level

		# Only do this when executing from a spec in TextMate
		if ENV['HTML_LOGGING'] || (ENV['TM_FILENAME'] && ENV['TM_FILENAME'] =~ /_spec\.rb/)
			Thread.current['logger-output'] = []
			logdevice = ArrayLogger.new( Thread.current['logger-output'] )
			Strelka.logger = Logger.new( logdevice )
			# Strelka.logger.level = level
			Strelka.logger.formatter = Strelka::Logging::HtmlFormatter.new( logger )
		end
	end

end # module Strelka::SpecHelpers


abort "You need a version of RSpec >= 2.6.0" unless defined?( RSpec )

### Mock with RSpec
RSpec.configure do |c|
	include Strelka::TestConstants

	c.mock_with :rspec

	c.extend( Strelka::TestConstants )
	c.include( Strelka::TestConstants )
	c.include( Strelka::SpecHelpers )

	c.filter_run_excluding( :ruby_1_8_only => true ) if
		Strelka::SpecHelpers.vvec( RUBY_VERSION ) >= Strelka::SpecHelpers.vvec('1.9.1')
	c.filter_run_excluding( :mri_only => true ) if
		defined?( RUBY_ENGINE ) && RUBY_ENGINE != 'ruby'
end

# vim: set nosta noet ts=4 sw=4:

