#!/usr/bin/env rspec -cfd -b

BEGIN {
	require 'pathname'
	basedir = Pathname( __FILE__ ).dirname.parent
	$LOAD_PATH.unshift( basedir.to_s ) unless $LOAD_PATH.include?( basedir.to_s )
}

require 'rspec'
require 'spec/lib/helpers'
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
			described_class.version_string.should =~ /\w+ [\d.]+/
		end


		it "returns a version string with a build number if asked" do
			described_class.version_string(true).should =~ /\w+ [\d.]+ \(build [[:xdigit:]]+\)/
		end
	end

	it "provides syntactic sugar for looking up an app class by name" do
		mox_app = nil
		Pathname.stub( :glob ).with( 'data/*/{apps,handlers}/**/*' ).
			and_return([ Pathname('data/mox/apps/moxthefox') ])
		Kernel.stub( :load ).with( File.expand_path 'data/mox/apps/moxthefox' ).and_return do
			mox_app = Class.new( Strelka::App )
		end

		described_class::App( 'moxthefox' ).should == mox_app
	end

end

