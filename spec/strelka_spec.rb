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

	describe "version methods" do
		it "returns a version string if asked" do
			described_class.version_string.should =~ /\w+ [\d.]+/
		end


		it "returns a version string with a build number if asked" do
			described_class.version_string(true).should =~ /\w+ [\d.]+ \(build [[:xdigit:]]+\)/
		end
	end

end

