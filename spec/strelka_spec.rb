#!/usr/bin/env rspec -cfd -b

require_relative 'helpers'

require 'rspec'
require 'strelka'

describe Strelka do

	before( :all ) do
		setup_logging()
	end

	after( :all ) do
		reset_logging()
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

	it "provides syntactic sugar for looking up an app class by name" do
		mox_app = nil
		expect( Pathname ).to receive( :glob ).
			with( 'data/*/{apps,handlers}/**/*' ).
			and_return([ Pathname('data/mox/apps/moxthefox') ])

		expect( Kernel ).to receive( :load ).
			with( File.expand_path 'data/mox/apps/moxthefox' ).
			and_return { mox_app = Class.new(Strelka::App) }

		expect( described_class::App('moxthefox') ).to be( mox_app )
	end

end

