# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# frozen-string-literal: true

require_relative '../helpers'

require 'rspec'
require 'mongrel2'

require 'strelka'
require 'strelka/discovery'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::Discovery do

	before( :all ) do
		@real_discovered_apps = described_class.instance_variable_get( :@discovered_apps )
	end

	after( :all ) do
		described_class.instance_variable_set( :@discovered_apps, @real_discovered_apps )
	end

	before( :each ) do
		described_class.instance_variable_set( :@discovered_apps, nil )
		described_class.configure
	end


	let( :discoverable_class ) { Class.new {extend Strelka::Discovery} }


	#
	# Examples
	#

	it "provides a mechanism for registering apps" do
		described_class.register_app( 'foo', 'a/path/to/foo.rb' )
		described_class.register_app( 'bar', 'a/path/to/bar.rb' )

		expect( described_class.discovered_apps ).to include(
			'foo' => 'a/path/to/foo.rb',
            'bar' => 'a/path/to/bar.rb'
		)
	end


	it "raises an error if two apps try to register with the same name" do
		described_class.register_app( 'foo', 'a/path/to/foo.rb' )
		expect {
			described_class.register_app( 'foo', 'a/path/to/bar.rb' )
		}.to output( /can't register a second 'foo' app/i ).to_stderr
	end


	it "uses Rubygems discovery to find apps" do
		expect( Gem ).to receive( :find_latest_files ).with( 'strelka/apps.rb' ).
			and_return([
				'/some/directory/with/strelka/apps.rb',
				'/some/other/directory/with/strelka/apps.rb'
			])
		expect( Kernel ).to receive( :load ).twice do |file|
			case file
			when %r{some/directory}
				described_class.register_app( 'foo', 'a/path/to/foo.rb' )
			when %r{other/directory}
				described_class.register_app( 'bar', 'a/path/to/bar.rb' )
			end
		end

		expect( described_class.discovered_apps ).to include(
			'foo' => 'a/path/to/foo.rb',
            'bar' => 'a/path/to/bar.rb'
		)
	end


	it "can be configured to look for a different discovery file" do
		acme_discovery_files = [
			'/some/directory/with/acme/apps.rb',
			'/some/other/directory/with/acme/apps.rb'
		]

		expect( Gem ).to receive( :find_latest_files ).with( 'acme/apps.rb' ).
			and_return( acme_discovery_files )

		described_class.configure( app_discovery_file: 'acme/apps.rb' )
		expect( described_class.app_discovery_files ).to eq( acme_discovery_files )
	end


	it "can return the app class associated with an application name" do
		described_class.register_app( 'foo', 'a/path/to/foo.rb' )

		app_class = nil
		expect( Kernel ).to receive( :load ) do |path|
			expect( path ).to eq( 'a/path/to/foo.rb' )

			app_class = Class.new( discoverable_class )
		end

		expect( described_class.load('foo') ).to eq( app_class )
	end


	it "only returns the last class that was declared" do
		described_class.register_app( 'foo', 'a/path/to/foo.rb' )

		app_class = app_class2 = nil
		expect( Kernel ).to receive( :load ) do |path|
			expect( path ).to eq( 'a/path/to/foo.rb' )

			app_class = Class.new( discoverable_class )
			app_class2 = Class.new( discoverable_class )
		end

		expect( described_class.load('foo') ).to eq( app_class2 )
	end

end

