# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# frozen-string-literal: true

require 'rspec'

require 'strelka'
require 'strelka/app'
require 'strelka/plugins'


# This is a shared behavior for specs which different Strelka::App
# plugins share in common. If you're creating A Strelka Plugin,
# you can test its conformity to the expectations placed on them by
# adding this to your spec:
#
#    require 'strelka/behavior/plugin'
#
#    describe YourPlugin do
#
#      it_should_behave_like "A Strelka Plugin"
#
#    end

RSpec.shared_examples_for "A Strelka Plugin" do

	let( :plugin ) do
		described_class
	end


	it "extends Strelka::Plugin" do
		expect( plugin ).to be_a( Strelka::Plugin )
	end

end


