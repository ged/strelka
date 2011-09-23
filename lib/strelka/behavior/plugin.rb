#!/usr/bin/env ruby

require 'rspec'

require 'strelka'
require 'strelka/app'
require 'strelka/app/plugins'


# This is a shared behavior for specs which different Strelka::App
# plugins share in common. If you're creating a Strelka::App plugin,
# you can test its conformity to the expectations placed on them by
# adding this to your spec:
# 
#    require 'strelka/behavior/plugin'
#
#    describe YourPlugin do
#
#      it_should_behave_like "A Strelka::App Plugin"
#
#    end

shared_examples_for "A Strelka::App Plugin" do

	let( :plugin ) do
		described_class
	end


	it "extends Strelka::App::Plugin" do
		plugin.should be_a( Strelka::App::Plugin )
	end

end


