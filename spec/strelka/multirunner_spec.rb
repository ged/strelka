# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# frozen-string-literal: true

require_relative '../helpers'
require 'rspec'

require 'strelka'
require 'strelka/multirunner'


#####################################################################
###	C O N T E X T S
#####################################################################
RSpec.describe Strelka::MultiRunner do

	let( :handler_class )  { double( "A Strelka Handler", run: true ) }
	let( :multirunner ) { described_class.new( handler_class, 3 ) }

	before( :each ) do
		allow( Process ).to receive( :fork ).and_yield.and_return( 1, 2, 3 )
		allow( Process ).to receive( :waitpid2 ).and_return( [1, nil], [2, nil], [3, nil] )
		allow( Process ).to receive( :setpgrp )
		allow( Process ).to receive( :setpgid )
		allow( Process ).to receive( :kill )
	end

	it "spawns the requested number of child handlers" do
		allow( multirunner ).to receive( :running ).and_return( false )
		expect( handler_class ).to receive( :run ).exactly( 3 ).times
		multirunner.run
		expect( multirunner.handler_pids.size ).to eq( 3 )
	end

	it "exits gracefully on a SIGINT" do
		thr = Thread.new{ multirunner.run }
		sleep 0.1 until multirunner.running || !thr.alive?

		expect( multirunner.handler_pids.size ).to eq( 3 )
		expect {
			multirunner.simulate_signal( :INT )
			thr.join( 2 )
		}.to change { multirunner.running }.from( true ).to( false )
		expect( multirunner.handler_pids.size ).to eq( 0 )
	end

	it "exits gracefully on a SIGTERM" do
		thr = Thread.new{ multirunner.run }
		sleep 0.1 until multirunner.running || !thr.alive?

		expect( multirunner.handler_pids.size ).to eq( 3 )
		expect {
			multirunner.simulate_signal( :TERM )
			thr.join( 2 )
		}.to change { multirunner.running }.from( true ).to( false )
		expect( multirunner.handler_pids.size ).to eq( 0 )
	end
end

