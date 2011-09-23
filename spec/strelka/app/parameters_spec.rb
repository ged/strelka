#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent.parent
	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
}

require 'rspec'

require 'spec/lib/helpers'

require 'strelka'
require 'strelka/app/plugins'
require 'strelka/app/parameters'
require 'strelka/behavior/plugin'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::App::Parameters do

	before( :all ) do
		setup_logging( :fatal )
	end

	after( :all ) do
		reset_logging()
	end


	it_should_behave_like( "A Strelka::App Plugin" )


	describe "an including App" do

		before( :each ) do
			@app = Class.new( Strelka::App ) do
				plugin :parameters
			end
		end

		it "has a parameters Hash" do
			@app.parameters.should be_a( Hash )
		end

		it "can declare a parameter with a validation pattern" do
			@app.class_eval do
				param :username, /\w+/i
			end

			@app.parameters.should have( 1 ).member
			@app.parameters[ :username ].
				should include( :constraint => /(?<username>(?i-mx:\w+))/ )
		end

		it "inherits parameters from its superclass" do
			@app.class_eval do
				param :username, /\w+/i
			end
			subapp = Class.new( @app )

			subapp.parameters.should have( 1 ).member
			subapp.parameters[ :username ].
				should include( :constraint => /(?<username>(?i-mx:\w+))/ )
		end

	end


end

