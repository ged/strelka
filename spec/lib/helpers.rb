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

require 'configurability'
require 'pathname'
require 'tmpdir'

require 'rspec'
require 'mongrel2'
require 'mongrel2/testing'

require 'strelka'

require 'spec/lib/constants'
# require 'spec/lib/matchers'

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
		Mongrel2.reset_logger
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
		Mongrel2.logger.level = level

		# Only do this when executing from a spec in TextMate
		if ENV['HTML_LOGGING'] || (ENV['TM_FILENAME'] && ENV['TM_FILENAME'] =~ /_spec\.rb/)
			Thread.current['logger-output'] = []
			logdevice = ArrayLogger.new( Thread.current['logger-output'] )
			Strelka.logger = Logger.new( logdevice )
			# Strelka.logger.level = level
			Strelka.logger.formatter = Strelka::Logging::HtmlFormatter.new( logger )
			Mongrel2.logger = Strelka.logger
		end
	end

	### Set up a Mongrel2 configuration database according to the specified +dbspec+.
	def setup_config_db( dbspec=':memory:' )
		Mongrel2::Config.configure( :configdb => dbspec ) unless
			Mongrel2::Config.db.uri[ %r{sqlite:/(.*)}, 1 ] == dbspec
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

