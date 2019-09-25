# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# frozen-string-literal: true

require_relative 'helpers'

require 'rspec'
require 'strelka'

RSpec.describe Strelka do

	before( :all ) do
		@original_config_env = ENV[Strelka::CONFIG_ENV]
	end

	before( :each ) do
		ENV.delete(Strelka::CONFIG_ENV)
		Strelka.after_configure_hooks.clear
	end

	after( :all ) do
		ENV[Strelka::CONFIG_ENV] = @original_config_env
	end



	describe "version methods" do

		it "returns a version string if asked" do
			expect( described_class.version_string ).to match( /\w+ [\d.]+/ )
		end


		it "returns a version string with a build number if asked" do
			expect( described_class.version_string(true) ).
				to match(/\w+ [\d.]+ \(build [[:xdigit:]]+\)/)
		end

	end


	# let( :config ) { Configurability::Config.new(TESTING_CONFIG_SOURCE) }


	it "will load a local config file if it exists and none is specified" do
		config_object = double( "Configurability::Config object" )
		allow( config_object ).to receive( :[] ).with( :strelka ).and_return( {} )

		expect( Configurability ).to receive( :gather_defaults ).
			and_return( {} )
		expect( Strelka::LOCAL_CONFIG_FILE ).to receive( :exist? ).
			and_return( true )
		expect( Configurability::Config ).to receive( :load ).
			with( Strelka::LOCAL_CONFIG_FILE, {} ).
			and_return( config_object )
		expect( config_object ).to receive( :install )

		Strelka.load_config
	end


	it "will load a default config file if none is specified and there's no local config" do
		config_object = double( "Configurability::Config object" )
		allow( config_object ).to receive( :[] ).with( :strelka ).and_return( {} )

		expect( Configurability ).to receive( :gather_defaults ).
			and_return( {} )
		expect( Strelka::LOCAL_CONFIG_FILE ).to receive( :exist? ).
			and_return( false )
		expect( Configurability::Config ).to receive( :load ).
			with( Strelka::DEFAULT_CONFIG_FILE, {} ).
			and_return( config_object )
		expect( config_object ).to receive( :install )

		Strelka.load_config
	end


	it "will load a config file given in an environment variable" do
		ENV['STRELKA_CONFIG'] = '/usr/local/etc/strelka.yml'

		config_object = double( "Configurability::Config object" )
		allow( config_object ).to receive( :[] ).with( :strelka ).and_return( {} )

		expect( Configurability ).to receive( :gather_defaults ).
			and_return( {} )
		expect( Configurability::Config ).to receive( :load ).
			with( '/usr/local/etc/strelka.yml', {} ).
			and_return( config_object )
		expect( config_object ).to receive( :install )

		Strelka.load_config
	end


	it "will load a config file and install it if one is given" do
		config_object = double( "Configurability::Config object" )
		allow( config_object ).to receive( :[] ).with( :strelka ).and_return( {} )

		expect( Configurability ).to receive( :gather_defaults ).
			and_return( {} )
		expect( Configurability::Config ).to receive( :load ).
			with( 'a/configfile.yml', {} ).
			and_return( config_object )
		expect( config_object ).to receive( :install )

		Strelka.load_config( 'a/configfile.yml' )
	end


	it "will override default values when loading the config if they're given" do
		config_object = double( "Configurability::Config object" )
		allow( config_object ).to receive( :[] ).with( :strelka ).and_return( {} )

		expect( Configurability ).to_not receive( :gather_defaults )
		expect( Configurability::Config ).to receive( :load ).
			with( 'a/different/configfile.yml', {database: {dbname: 'test'}} ).
			and_return( config_object )
		expect( config_object ).to receive( :install )

		Strelka.load_config( 'a/different/configfile.yml', database: {dbname: 'test'} )
	end


	it "will call any registered callbacks after the config is installed" do
		config_object = double( "Configurability::Config object" )
		allow( config_object ).to receive( :[] ).with( :strelka ).and_return( {} )

		expect( Configurability ).to receive( :gather_defaults ).
			and_return( {} )
		expect( Configurability::Config ).to receive( :load ).
			with( 'a/configfile.yml', {} ).
			and_return( config_object )
		expect( config_object ).to receive( :install )

		hook_was_called = false
		Strelka.after_configure do
			hook_was_called = true
		end
		Strelka.load_config( 'a/configfile.yml' )

		expect( hook_was_called ).to be( true )
	end


	it "will immediately call after_config callbacks registered after the config is installed" do
		config_object = double( "Configurability::Config object" )
		allow( config_object ).to receive( :[] ).with( :strelka ).and_return( {} )

		expect( Configurability ).to receive( :gather_defaults ).
			and_return( {} )
		expect( Configurability::Config ).to receive( :load ).
			with( 'a/configfile.yml', {} ).
			and_return( config_object )
		expect( config_object ).to receive( :install )

		hook_was_called = false
		Strelka.load_config( 'a/configfile.yml' )

		Strelka.after_configure do
			hook_was_called = true
		end

		expect( hook_was_called ).to be( true )
	end


	it "can add new after_configure hooks even while the current ones are being run" do
		config_object = double( "Configurability::Config object" )
		allow( config_object ).to receive( :[] ).with( :strelka ).and_return( {} )

		expect( Configurability ).to receive( :gather_defaults ).
			and_return( {} )
		expect( Configurability::Config ).to receive( :load ).
			with( 'a/configfile.yml', {} ).
			and_return( config_object )
		expect( config_object ).to receive( :install )

		hook_was_called = false
		Strelka.after_configure do
			Strelka.after_configure do
				hook_was_called = true
			end
		end

		Strelka.load_config( 'a/configfile.yml' )

		expect( hook_was_called ).to be( true )
	end


	it "provides a way to register blocks that should run before a fork" do
		callback_ran = false
		Strelka.before_fork { callback_ran = true }
		Strelka.call_before_fork_hooks

		expect( callback_ran ).to be( true )
	end

	it "raises an exception if .before_fork is called without a block" do
		expect {
			Strelka.before_fork
		}.to raise_error( LocalJumpError, /no block given/i )
	end

end

