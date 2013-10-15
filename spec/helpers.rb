#!/usr/bin/ruby
# coding: utf-8

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent

	srcdir = basedir.parent
	mongrel2dir = srcdir + 'Mongrel2/lib'

	$LOAD_PATH.unshift( mongrel2dir.to_s ) unless
		!mongrel2dir.directory? || $LOAD_PATH.include?( mongrel2dir.to_s )
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
require 'loggability/spechelpers'
require 'configurability'
require 'pathname'
require 'tmpdir'

require 'rspec'
require 'mongrel2'
require 'mongrel2/testing'

require 'strelka'
require 'strelka/testing'

require_relative 'constants'

Loggability.format_with( :color ) if $stdout.tty?


### RSpec helper functions.
module Strelka::SpecHelpers
	include Strelka::TestConstants,
	        Strelka::Testing

	###############
	module_function
	###############

	### Make an easily-comparable version vector out of +ver+ and return it.
	def vvec( ver )
		return ver.split('.').collect {|char| char.to_i }.pack('N*')
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


	### Create a temporary working directory and return
	### a Pathname object for it.
	###
	def make_tempdir
		dirname = "%s.%d.%0.4f" % [
			'strelka_spec',
			Process.pid,
			(Time.now.to_f % 3600),
		  ]
		tempdir = Pathname.new( Dir.tmpdir ) + dirname
		tempdir.mkpath

		return tempdir
	end


	### Make and return a dummy gemspec with the given +name+ and +version+, and inject a
	### dependency on 'strelka' if +strelka_dep+ is true.
	def make_gemspec( name, version, strelka_dep=true )
		spec = Gem::Specification.new( name, version )
		spec.add_runtime_dependency( 'strelka', '~> 0.0' ) if strelka_dep
		return spec
	end


end


### Mock with RSpec
RSpec.configure do |config|
	include Strelka::TestConstants

	config.treat_symbols_as_metadata_keys_with_true_values = true
	config.run_all_when_everything_filtered = true
	config.filter_run :focus
	config.order = 'random'
	config.mock_with( :rspec ) do |mock|
		mock.syntax = :expect
	end

	config.extend( Strelka::TestConstants )

	config.include( Loggability::SpecHelpers )
	config.include( Mongrel2::SpecHelpers )
	config.include( Strelka::SpecHelpers )
end

# vim: set nosta noet ts=4 sw=4:

