#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent.parent
	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
}

require 'rspec'

require 'spec/lib/helpers'

require 'strelka'
require 'strelka/app/defaultrouter'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::App::DefaultRouter do

	before( :all ) do
		setup_logging( :fatal )
		@request_factory = Mongrel2::RequestFactory.new( route: '/user' )
	end

	before( :each ) do
		@router = Strelka::App::DefaultRouter.new
	end

	after( :all ) do
		reset_logging()
	end

	context "a router with routes for 'foo', 'foo/bar'" do

		before( :each ) do
			@router.add_route( :GET, ['foo'], :the_foo_action )
			@router.add_route( :GET, ['foo','bar'], :the_foo_bar_action )
		end

		it "routes /user/foo/bar/baz to the foo/bar action" do
			req = @request_factory.get( '/user/foo/bar/baz' )
			@router.route_request( req ).should == :the_foo_bar_action
		end

		it "routes /user/foo/bar to the foo/bar action" do
			req = @request_factory.get( '/user/foo/bar' )
			@router.route_request( req ).should == :the_foo_bar_action
		end

		it "routes /user/foo to the foo action" do
			req = @request_factory.get( '/user/foo' )
			@router.route_request( req ).should == :the_foo_action
		end

		it "doesn't route /user" do
			req = @request_factory.get( '/user' )
			@router.route_request( req ).should be_nil()
		end

		it "doesn't route /user/other" do
			req = @request_factory.get( '/user/other' )
			@router.route_request( req ).should be_nil()
		end

	end

	context "a router with routes for 'foo', 'foo/bar', and a fallback action" do

		before( :each ) do
			@router.add_route( :GET, [], :the_fallback_action )
			@router.add_route( :GET, ['foo'], :the_foo_action )
			@router.add_route( :GET, ['foo','bar'], :the_foo_bar_action )
		end

		it "routes /user/foo/bar/baz to the foo/bar action" do
			req = @request_factory.get( '/user/foo/bar/baz' )
			@router.route_request( req ).should == :the_foo_bar_action
		end

		it "routes /user/foo/bar to the foo/bar action" do
			req = @request_factory.get( '/user/foo/bar' )
			@router.route_request( req ).should == :the_foo_bar_action
		end

		it "routes /user/foo to the foo action" do
			req = @request_factory.get( '/user/foo' )
			@router.route_request( req ).should == :the_foo_action
		end

		it "routes /user to the fallback action" do
			req = @request_factory.get( '/user' )
			@router.route_request( req ).should == :the_fallback_action
		end

		it "routes /user/other to the fallback action" do
			req = @request_factory.get( '/user/other' )
			@router.route_request( req ).should == :the_fallback_action
		end

	end

	context "a router with routes for 'foo', 'foo/\w{3}', and 'foo/\w{6}'" do

		before( :each ) do
			@router.add_route( :GET, ['foo'], :the_foo_action )
			@router.add_route( :GET, ['foo',/\w{3}/], :the_foo_threeaction )
			@router.add_route( :GET, ['foo',/\w{6}/], :the_foo_sixaction )
		end

		it "routes /user/foo/barbim/baz to the foo/\w{6} action" do
			req = @request_factory.get( '/user/foo/barbim/baz' )
			@router.route_request( req ).should == :the_foo_sixaction
		end

		it "routes /user/foo/barbat to the foo/\w{6} action" do
			req = @request_factory.get( '/user/foo/barbat' )
			@router.route_request( req ).should == :the_foo_sixaction
		end

		it "routes /user/foo/bar/baz to the foo/\w{3} action" do
			req = @request_factory.get( '/user/foo/bar/baz' )
			@router.route_request( req ).should == :the_foo_threeaction
		end

		it "routes /user/foo/bar to the foo/\w{3} action" do
			req = @request_factory.get( '/user/foo/bar' )
			@router.route_request( req ).should == :the_foo_threeaction
		end

		it "routes /user/foo to the foo action" do
			req = @request_factory.get( '/user/foo' )
			@router.route_request( req ).should == :the_foo_action
		end

		it "doesn't route /user" do
			req = @request_factory.get( '/user' )
			@router.route_request( req ).should be_nil()
		end

		it "doesn't route /user/other" do
			req = @request_factory.get( '/user/other' )
			@router.route_request( req ).should be_nil()
		end

	end

	# get '/foo/\w{3}'
		# get '/foo/\d+'

	context "a router with routes for: 'foo/\w{3}', then 'foo/\d+'" do

		before( :each ) do
			@router.add_route( :GET, ['foo',/\w{3}/], :the_foo_threeaction )
			@router.add_route( :GET, ['foo',/\d+/], :the_foo_digitaction )
		end

		it "routes /user/foo/1 to the foo/\d+ action" do
			req = @request_factory.get( '/user/foo/1' )
			@router.route_request( req ).should == :the_foo_digitaction
		end

		it "routes /user/foo/12 to the foo/\d+ action" do
			req = @request_factory.get( '/user/foo/12' )
			@router.route_request( req ).should == :the_foo_digitaction
		end

		it "routes /user/foo/123 to the foo/\w{3} action" do
			req = @request_factory.get( '/user/foo/123' )
			@router.route_request( req ).should == :the_foo_threeaction
		end

		it "routes /user/foo/1234 to the foo/\d+ action" do
			req = @request_factory.get( '/user/foo/1234' )
			@router.route_request( req ).should == :the_foo_digitaction
		end

	end

	# get '/foo/\d+'
	# get '/foo/\w{3}'

	context "a router with routes for: 'foo/\d+', then 'foo/\w{3}'" do

		before( :each ) do
			@router.add_route( :GET, ['foo',/\d+/], :the_foo_digitaction )
			@router.add_route( :GET, ['foo',/\w{3}/], :the_foo_threeaction )
		end

		it "routes /user/foo/1 to the foo/\d+ action" do
			req = @request_factory.get( '/user/foo/1' )
			@router.route_request( req ).should == :the_foo_digitaction
		end

		it "routes /user/foo/12 to the foo/\d+ action" do
			req = @request_factory.get( '/user/foo/12' )
			@router.route_request( req ).should == :the_foo_digitaction
		end

		it "routes /user/foo/123 to the foo/\d+ action" do
			req = @request_factory.get( '/user/foo/123' )
			@router.route_request( req ).should == :the_foo_digitaction
		end

		it "routes /user/foo/1234 to the foo/\d+ action" do
			req = @request_factory.get( '/user/foo/1234' )
			@router.route_request( req ).should == :the_foo_digitaction
		end

	end

end
