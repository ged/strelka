# -*- rspec -*-
# vim: set nosta noet ts=4 sw=4:

require_relative '../helpers'

require 'rspec'

require 'strelka'
require 'strelka/session'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::Session do

	before( :all ) do
		setup_logging( :fatal )
		@request_factory = Mongrel2::RequestFactory.new( route: '/user' )
	end

	after( :all ) do
		reset_logging()
	end


	it "looks for plugins under strelka/session" do
		expect( described_class.plugin_prefixes ).to include( 'strelka/session' )
	end


	it "is abstract" do
		expect {
			described_class.new
		}.to raise_error( /private method/i )
	end


	it "accepts configuration options" do
		described_class.configure( :cookie_name => 'animal-crackers' )
	end


	it "can be asked to load an instance of itself by session ID" do
		# By default, loading always fails
		expect( described_class.load( 'the_session_id' ) ).to be_nil()
	end


	describe "a concrete subclass with no method overrides" do

		subject { Class.new(described_class).new('an_id') }

		it "raises NotImplementedErrors when #[] is called" do
			expect {
				subject[ :foo ]
			}.to raise_error(NotImplementedError)
		end

		it "raises NotImplementedErrors if they don't implement #[]=" do
			expect {
				subject[ :foo ] = 1
			}.to raise_error(NotImplementedError)
		end

		it "raises NotImplementedErrors if they don't implement #key?" do
			expect {
				subject.key?( :foo )
			}.to raise_error(NotImplementedError)
		end

		it "raises NotImplementedErrors if they don't implement #delete" do
			expect {
				subject.delete( :foo )
			}.to raise_error(NotImplementedError)
		end

		it "raises NotImplementedErrors if they don't implement #namepace=" do
			expect {
				subject.namespace = :myapp
			}.to raise_error(NotImplementedError)
		end

		it "raises NotImplementedErrors if they don't implement #namepace" do
			expect {
				subject.namespace
			}.to raise_error(NotImplementedError)
		end

	end


end

