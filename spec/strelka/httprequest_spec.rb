# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent

	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
}

require 'uri'
require 'rspec'
require 'spec/lib/helpers'
require 'strelka/httprequest'
require 'strelka/cookie'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::HTTPRequest do

	before( :all ) do
		setup_logging()
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

		it "knows what the request's parsed URI is when it's an HTTPS request" do
			@req.headers.url_scheme = 'https'
			@req.uri.should be_a( URI )
			@req.uri.to_s.should == 'https://localhost:8080/directory/userinfo/ged'
		end

		it "doesn't error when run under earlier versions of Mongrel that didn't set the " +
		   "url-scheme header" do
			@req.headers.url_scheme = nil
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

		it "can redirect the request to a different URI" do
			uri = 'http://www.google.com/'
			expect {
				@req.redirect( uri )
			}.to finish_with( HTTP::MOVED_TEMPORARILY, nil, :location => uri )

			expect {
				@req.redirect( uri, true )
			}.to finish_with( HTTP::MOVED_PERMANENTLY, nil, :location => uri )
		end
	end


	context "instance with URI-escaped characters in its path" do

		before( :each ) do
			@req = @request_factory.get( '/directory/user%20info/ged%00' )
		end

		it "knows what the request's parsed URI is" do
			@req.uri.should be_a( URI )
			@req.uri.to_s.should == 'http://localhost:8080/directory/user%20info/ged%00'
		end

		it "knows what Mongrel2 route it followed" do
			@req.pattern.should == "/directory"
		end

		it "knows what the URI of the route handling the request is" do
			@req.base_uri.should be_a( URI )
			@req.base_uri.to_s.should == 'http://localhost:8080/directory'
		end

		it "knows what the path of the request past its route is" do
			@req.app_path.should == "/user info/ged\0"
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
			@req.app_path.should == '/userinfo/ged' # make sure the slice is non-destructive
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


		context "a POST request without a content type" do
			before( :each ) do
				@req = @request_factory.post( '/directory/path', '' )
			end


			it "responds with a 400 (BAD_REQUEST)" do
				expected_info = {
					status: 400,
					message: "Malformed request (no content type?)",
					headers: {}
				}

				expect {
					@req.params
				}.to finish_with( HTTP::BAD_REQUEST, /no content type/i )
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
					'Content-type' => 'multipart/form-data; boundary=--a_boundary' )
			end

			it "returns a hash for form parameters" do
				@req.body = "----a_boundary\r\n" +
					%{Content-Disposition: form-data; name="title"\r\n} +
					%{\r\n} +
					%{An Impossible Task\r\n} +
					%{----a_boundary--\r\n}

				@req.params.should == {'title' => 'An Impossible Task'}
			end

		end


		context "a POST request with a 'application/json' body" do
			before( :each ) do
				@req = @request_factory.post( '/directory/path', '',
					'Content-type' => 'application/json' )
			end

			it "returns nil for an empty body" do
				@req.body = ''
				@req.params.should be_nil()
			end

			it "has the JSON data as the params if it has a body with JSON object in it" do
				data = {
					'animal' => 'ducky',
					'adjectives' => ['fluffy', 'puddle-ey'],
				}
				@req.body = Yajl.dump( data )
				@req.params.should == data
			end

		end

	end


	describe "cookie support" do

		before( :each ) do
			@req = @request_factory.get( '/directory/userinfo/ged' )
		end


		it "parses a single cookie into a cookieset with the cookie in it" do
			@req.header.cookie = 'foom=chuckUfarly'
			@req.cookies.should have( 1 ).member
			@req.cookies['foom'].value.should == 'chuckUfarly'
		end

		it "parses multiple cookies into a cookieset with multiple cookies in it" do
			@req.header.cookie = 'foom=chuckUfarly; glarn=hotchinfalcheck'

			@req.cookies.should have( 2 ).members
			@req.cookies['foom'].value.should == 'chuckUfarly'
			@req.cookies['glarn'].value.should == 'hotchinfalcheck'
		end

	end

end

