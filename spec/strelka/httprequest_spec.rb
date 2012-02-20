#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent

	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
}

require 'uri'
require 'rspec'
require 'spec/lib/helpers'
require 'strelka/httprequest'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::HTTPRequest do

	before( :all ) do
		setup_logging( :fatal )
		@request_factory = Mongrel2::RequestFactory.new( route: '/directory' )
	end

	after( :all ) do
		reset_logging()
	end

	context "instance" do

		before( :each ) do
			@req = @request_factory.get( '/directory/userinfo/ged' )
		end

		it "knows what the request's parsed URI is" do
			@req.uri.should be_a( URI )
			@req.uri.to_s.should == 'http://localhost:8080/directory/userinfo/ged'
		end

		it "knows what Mongrel2 route it followed" do
			@req.pattern.should == '/directory'
		end

		it "knows what the URI of the route handling the request is" do
			@req.base_uri.should be_a( URI )
			@req.base_uri.to_s.should == 'http://localhost:8080/directory'
		end

		it "knows what the path of the request past its route is" do
			@req.app_path.should == '/userinfo/ged'
		end

		it "knows what HTTP verb the request used" do
			@req.verb.should == :GET
		end

		it "can get and set notes for communication between plugins" do
			@req.notes.should be_a( Hash )
			@req.notes[:routing].should be_a( Hash )
			@req.notes[:routing][:route].should be_a( Hash )
		end

	end


	context "instance with a query string" do

		before( :each ) do
			@req = @request_factory.get( '/directory/userinfo/ged?limit=10;offset=20' )
		end

		it "knows what the request's parsed URI is" do
			@req.uri.should be_a( URI )
			@req.uri.to_s.should == 'http://localhost:8080/directory/userinfo/ged?limit=10;offset=20'
		end

		it "knows what Mongrel2 route it followed" do
			@req.pattern.should == '/directory'
		end

		it "knows what the URI of the route handling the request is" do
			@req.base_uri.should be_a( URI )
			@req.base_uri.to_s.should == 'http://localhost:8080/directory'
		end

		it "knows what the path of the request past its route is" do
			@req.app_path.should == '/userinfo/ged'
		end

		it "knows what HTTP verb the request used" do
			@req.verb.should == :GET
		end

	end


	describe "request-parameter parsing" do

		context "a GET request" do
			it "has an empty params Hash if the request doesn't have a query string " do
				req = @request_factory.get( '/directory/path' )
				req.params.should == {}
			end

			it "has a params Hash with the key/value pair in it if the query string has " +
			   "one key/value pair" do
				req = @request_factory.get( '/directory/path?foo=bar' )
				req.params.should == {'foo' => 'bar'}
			end

			it "has a params Hash with the key/value pairs in it if the query string has " +
			   "two pairs seperated with a an ampersand" do
				req = @request_factory.get( '/directory/path?foo=bar&chunky=pork' )
				req.params.should == {
					'foo'    => 'bar',
					'chunky' => 'pork',
				}
			end

			it "has a params Hash with the key/value pairs in it if the query string has " +
			   "two pairs with a semi-colon separator" do
				req = @request_factory.get( '/directory/path?potato=gun;legume=bazooka' )
				req.params.should == {
					'potato' => 'gun',
					'legume' => 'bazooka',
				}
			end

			it "has a params Hash with an Array of values if the query string has two values " +
			   "for the same key" do
				req = @request_factory.get( '/directory/path?foo=bar&foo=baz' )
				req.params.should == {
					'foo'    => ['bar', 'baz'],
				}
			end

			it "has a params Hash with one Array of values and a scalar value if the query " +
			   "string has three values and two keys" do
				req = @request_factory.get( '/directory/path?foo=bar&foo=pork;mirror=sequel' )
				req.params.should == {
					'foo'    => ['bar', 'pork'],
					'mirror' => 'sequel',
				}
			end
		end

		context "a POST request with a 'application/x-www-form-urlencoded' body" do

			before( :each ) do
				@req = @request_factory.post( '/directory/path', '',
					'Content-type' => 'application/x-www-form-urlencoded' )
			end

			it "returns an empty Hash for an empty body" do
				@req.body = ''
				@req.params.should == {}
			end

			it "has a params Hash with the key/value pair in it if the form data has " +
			   "one key/value pair" do
				@req.body = 'foo=bar'
				@req.params.should == {'foo' => 'bar'}
			end

			it "has a params Hash with the key/value pairs in it if the form data has " +
			   "two pairs seperated with a an ampersand" do
				@req.body = 'foo=bar&chunky=pork'
				@req.params.should == {
					'foo'    => 'bar',
					'chunky' => 'pork',
				}
			end

			it "has a params Hash with the key/value pairs in it if the form data has " +
			   "two pairs with a semi-colon separator" do
				@req.body = 'potato=gun;legume=bazooka'
				@req.params.should == {
					'potato' => 'gun',
					'legume' => 'bazooka',
				}
			end

			it "has a params Hash with an Array of values if the form data has two values " +
			   "for the same key" do
				@req.body = 'foo=bar&foo=baz'
				@req.params.should == { 'foo' => ['bar', 'baz'] }
			end

			it "has a params Hash with one Array of values and a scalar value if the form " +
			   "data has three values and two keys" do
				@req.body = 'foo=bar&foo=pork;mirror=sequel'
				@req.params.should == {
					'foo'    => ['bar', 'pork'],
					'mirror' => 'sequel',
				}
			end
		end

		context "a POST request with a 'multipart/form-data' body" do

			before( :each ) do
				@req = @request_factory.post( '/directory/path', '',
					'Content-type' => 'multipart/form-data' )
			end

			it "returns an empty Hash for an empty body" do
				pending "multipart/form-data support" do
					@req.body = ''
					@req.params.should == {}
				end
			end

		end


	end

end

