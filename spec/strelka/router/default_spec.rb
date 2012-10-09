# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent.parent
	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
}

require 'rspec'

require 'spec/lib/helpers'

require 'strelka'
require 'strelka/router/default'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::Router::Default do

	before( :all ) do
		setup_logging( :fatal )
		@request_factory = Mongrel2::RequestFactory.new( route: '/user' )
	end

	before( :each ) do
		@router = Strelka::Router.create( 'default' )
	end

	after( :all ) do
		reset_logging()
	end


	context "a router with routes for 'foo', 'foo/bar'" do

		before( :each ) do
			@router.add_route( :GET, ['foo'], route(:GET_foo) )
			@router.add_route( :GET, ['foo','bar'], route(:GET_foo_bar) )
			@router.add_route( :POST, ['foo', 'bar'], route(:POST_foo_bar) )
		end

		it "routes GET /user/foo/bar/baz to the GET foo/bar action" do
			req = @request_factory.get( '/user/foo/bar/baz' )
			@router.route_request( req ).should match_route( :GET_foo_bar )
		end

		it "routes GET /user/foo/bar to the GET foo/bar action" do
			req = @request_factory.get( '/user/foo/bar' )
			@router.route_request( req ).should match_route( :GET_foo_bar )
		end

		it "routes GET /user/foo to the GET foo action" do
			req = @request_factory.get( '/user/foo' )
			@router.route_request( req ).should match_route( :GET_foo )
		end

		it "doesn't route GET /user" do
			req = @request_factory.get( '/user' )
			@router.route_request( req ).should be_nil()
		end

		it "doesn't route GET /user/something/foo/bar" do
			req = @request_factory.get( '/user/something/foo/bar' )
			@router.route_request( req ).should be_nil()
		end

		it "doesn't route GET /user/other" do
			req = @request_factory.get( '/user/other' )
			@router.route_request( req ).should be_nil()
		end

		it "routes HEAD requests to the GET route" do
			req = @request_factory.head( '/user/foo' )
			@router.route_request( req ).should match_route( :GET_foo )
		end

		it "responds with a 405 (method not allowed) for a DELETE request to /user/foo" do
			req = @request_factory.delete( '/user/foo' )
			expect {
				@router.route_request( req )
			}.to finish_with( HTTP::METHOD_NOT_ALLOWED, /method not allowed/i ).
			     and_header( allow: 'GET, HEAD' )
		end

		it "responds with a 405 (method not allowed) for a POST request to /user/foo" do
			req = @request_factory.post( '/user/foo' )
			expect {
				@router.route_request( req )
			}.to finish_with( HTTP::METHOD_NOT_ALLOWED, /method not allowed/i ).
			     and_header( allow: 'GET, HEAD' )
		end

	end

	context "a router with routes for 'foo', 'foo/bar', and a fallback action" do

		before( :each ) do
			@router.add_route( :GET, [], route(:fallback) )
			@router.add_route( :GET, ['foo'], route(:foo) )
			@router.add_route( :GET, ['foo','bar'], route(:foo_bar) )
		end

		it "routes /user/foo/bar/baz to the foo/bar action" do
			req = @request_factory.get( '/user/foo/bar/baz' )
			@router.route_request( req ).should match_route( :foo_bar )
		end

		it "routes /user/foo/bar to the foo/bar action" do
			req = @request_factory.get( '/user/foo/bar' )
			@router.route_request( req ).should match_route( :foo_bar )
		end

		it "routes /user/foo to the foo action" do
			req = @request_factory.get( '/user/foo' )
			@router.route_request( req ).should match_route( :foo )
		end

		it "routes /user to the fallback action" do
			req = @request_factory.get( '/user' )
			@router.route_request( req ).should match_route( :fallback )
		end

		it "routes /user/other to the fallback action" do
			req = @request_factory.get( '/user/other' )
			@router.route_request( req ).should match_route( :fallback )
		end

	end

	context "a router with routes for 'foo', 'foo/\w{3}', and 'foo/\w{6}'" do

		before( :each ) do
			@router.add_route( :GET, ['foo'], route(:foo) )
			@router.add_route( :GET, ['foo',/\w{3}/], route(:foo_three) )
			@router.add_route( :GET, ['foo',/\w{6}/], route(:foo_six) )
		end

		it "routes /user/foo/barbim/baz to the foo/\w{6} action" do
			req = @request_factory.get( '/user/foo/barbim/baz' )
			@router.route_request( req ).should match_route( :foo_six )
		end

		it "routes /user/foo/barbat to the foo/\w{6} action" do
			req = @request_factory.get( '/user/foo/barbat' )
			@router.route_request( req ).should match_route( :foo_six )
		end

		it "routes /user/foo/bar/baz to the foo/\w{3} action" do
			req = @request_factory.get( '/user/foo/bar/baz' )
			@router.route_request( req ).should match_route( :foo_three )
		end

		it "routes /user/foo/bar to the foo/\w{3} action" do
			req = @request_factory.get( '/user/foo/bar' )
			@router.route_request( req ).should match_route( :foo_three )
		end

		it "routes /user/foo to the foo action" do
			req = @request_factory.get( '/user/foo' )
			@router.route_request( req ).should match_route( :foo )
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
			@router.add_route( :GET, ['foo',/\w{3}/], route(:foo_three) )
			@router.add_route( :GET, ['foo',/\d+/], route(:foo_digit) )
		end

		it "routes /user/foo/1 to the foo/\d+ action" do
			req = @request_factory.get( '/user/foo/1' )
			@router.route_request( req ).should match_route( :foo_digit )
		end

		it "routes /user/foo/12 to the foo/\d+ action" do
			req = @request_factory.get( '/user/foo/12' )
			@router.route_request( req ).should match_route( :foo_digit )
		end

		it "routes /user/foo/123 to the foo/\w{3} action" do
			req = @request_factory.get( '/user/foo/123' )
			@router.route_request( req ).should match_route( :foo_three )
		end

		it "routes /user/foo/1234 to the foo/\d+ action" do
			req = @request_factory.get( '/user/foo/1234' )
			@router.route_request( req ).should match_route( :foo_digit )
		end

	end

	# get '/foo/\d+'
	# get '/foo/\w{3}'

	context "a router with routes for: 'foo/\d+', then 'foo/\w{3}'" do

		before( :each ) do
			@router.add_route( :GET, ['foo',/\d+/], route(:foo_digit) )
			@router.add_route( :GET, ['foo',/\w{3}/], route(:foo_three) )
		end

		it "routes /user/foo/1 to the foo/\d+ action" do
			req = @request_factory.get( '/user/foo/1' )
			@router.route_request( req ).should match_route( :foo_digit )
		end

		it "routes /user/foo/12 to the foo/\d+ action" do
			req = @request_factory.get( '/user/foo/12' )
			@router.route_request( req ).should match_route( :foo_digit )
		end

		it "routes /user/foo/123 to the foo/\d+ action" do
			req = @request_factory.get( '/user/foo/123' )
			@router.route_request( req ).should match_route( :foo_digit )
		end

		it "routes /user/foo/1234 to the foo/\d+ action" do
			req = @request_factory.get( '/user/foo/1234' )
			@router.route_request( req ).should match_route( :foo_digit )
		end

	end

	context "a router with routes for: 'foo', then '/(?<filename>\p{Print}*)\.pdf$/'" do

		before( :each ) do
			@router.add_route( :GET, ['foo'], route(:foo) )
			@router.add_route( :GET, [/(?<filename>\p{Print}*)\.pdf$/], route(:as_pdf) )
		end

		it "routes /user/foo/1 to the foo action" do
			req = @request_factory.get( '/user/foo/1' )
			@router.route_request( req ).should match_route( :foo )
		end

		it "routes /foo.pdf to the regexp action" do
			req = @request_factory.get( '/user/foo.pdf' )
			@router.route_request( req ).should match_route( :as_pdf )
		end

		it "doesn't route /foo%1B.pdf to the regexp action" do
			req = @request_factory.get( "/user/foo%1B.pdf" )
			@router.route_request( req ).should_not match_route( :as_pdf )
		end

		it "routes /zanzibar.pdf to the regexp action" do
			req = @request_factory.get( '/user/zanzibar.pdf' )
			@router.route_request( req ).should match_route( :as_pdf )
		end

	end

end

