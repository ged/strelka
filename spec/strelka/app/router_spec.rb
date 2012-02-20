#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent.parent
	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
}

require 'rspec'

require 'spec/lib/helpers'

require 'strelka'
require 'strelka/app/router'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::App::Router do

	before( :all ) do
		setup_logging( :fatal )
		@request_factory = Mongrel2::RequestFactory.new( route: '/user' )
	end

	after( :all ) do
		reset_logging()
	end


	it "looks for plugins under strelka/app" do
		Strelka::App::Router.derivative_dirs.should include( 'strelka/app' )
	end


	it "is abstract" do
		expect {
			Strelka::App::Router.new
		}.to raise_error()
	end


	describe "concrete subclasses" do

		subject { Class.new(described_class).new }

		it "raises NotImplementedErrors if they don't implement #add_route" do
			expect {
				subject.add_route(:GET, '', lambda {})
			}.to raise_error(NotImplementedError)
		end

		it "raises NotImplementedErrors if they don't implement #route_request" do
			expect {
				subject.route_request(:request)
			}.to raise_error(NotImplementedError)
		end
	end

end

