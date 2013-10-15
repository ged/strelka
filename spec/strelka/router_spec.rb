# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require_relative '../helpers'

require 'rspec'

require 'strelka'
require 'strelka/router'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::Router do

	before( :all ) do
		setup_logging( :fatal )
		@request_factory = Mongrel2::RequestFactory.new( route: '/user' )
	end

	after( :all ) do
		reset_logging()
	end


	it "looks for plugins under strelka/router" do
		expect( Strelka::Router.plugin_prefixes ).to include( 'strelka/router' )
	end


	it "is abstract" do
		expect {
			Strelka::Router.new
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

