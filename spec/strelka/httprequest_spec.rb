# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require_relative '../helpers'

require 'uri'
require 'rspec'
require 'strelka/httprequest'
require 'strelka/cookie'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::HTTPRequest do

	before( :all ) do
		@request_factory = Mongrel2::RequestFactory.new( route: '/directory' )
	end


	context "instance" do

		before( :each ) do
			@req = @request_factory.get( '/directory/userinfo/ged' )
		end

		it "knows what the request's parsed URI is" do
			expect( @req.uri ).to be_a( URI )
			expect( @req.uri.to_s ).to eq( 'http://localhost:8080/directory/userinfo/ged' )
		end

		it "knows what the request's parsed URI is when it's an HTTPS request" do
			@req.headers.url_scheme = 'https'
			expect( @req.uri ).to be_a( URI )
			expect( @req.uri.to_s ).to eq( 'https://localhost:8080/directory/userinfo/ged' )
		end

		it "doesn't error when run under earlier versions of Mongrel that didn't set the " +
		   "url-scheme header" do
			@req.headers.url_scheme = nil
			expect( @req.uri ).to be_a( URI )
			expect( @req.uri.to_s ).to eq( 'http://localhost:8080/directory/userinfo/ged' )
		end

		it "knows what Mongrel2 route it followed" do
			expect( @req.pattern ).to eq( '/directory' )
		end

		it "knows what the URI of the route handling the request is" do
			expect( @req.base_uri ).to be_a( URI )
			expect( @req.base_uri.to_s ).to eq( 'http://localhost:8080/directory' )
		end

		it "doesn't modify its URI when calculating its base URI" do
			expect { @req.base_uri }.to_not change { @req.uri }
		end

		it "knows what the path of the request past its route is" do
			expect( @req.app_path ).to eq( '/userinfo/ged' )
		end

		it "knows what HTTP verb the request used" do
			expect( @req.verb ).to eq(:GET)
		end

		it "can get and set notes for communication between plugins" do
			expect( @req.notes ).to be_a( Hash )
			expect( @req.notes[:routing] ).to be_a( Hash )
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
			expect( @req.uri ).to be_a( URI )
			expect( @req.uri.to_s ).to eq( 'http://localhost:8080/directory/user%20info/ged%00' )
		end

		it "knows what Mongrel2 route it followed" do
			expect( @req.pattern ).to eq('/directory')
		end

		it "knows what the URI of the route handling the request is" do
			expect( @req.base_uri ).to be_a( URI )
			expect( @req.base_uri.to_s ).to eq( 'http://localhost:8080/directory' )
		end

		it "knows what the path of the request past its route is" do
			expect( @req.app_path ).to eq("/user info/ged\0")
		end

	end


	context "instance with a query string" do

		before( :each ) do
			@req = @request_factory.get( '/directory/userinfo/ged?limit=10;offset=20' )
		end

		it "knows what the request's parsed URI is" do
			expect( @req.uri ).to be_a( URI )
			expect( @req.uri.to_s ).to eq( 'http://localhost:8080/directory/userinfo/ged?limit=10;offset=20' )
		end

		it "knows what Mongrel2 route it followed" do
			expect( @req.pattern ).to eq( '/directory' )
		end

		it "knows what the URI of the route handling the request is" do
			expect( @req.base_uri ).to be_a( URI )
			expect( @req.base_uri.to_s ).to eq( 'http://localhost:8080/directory' )
		end

		it "knows what the path of the request past its route is" do
			expect( @req.app_path ).to eq( '/userinfo/ged' )
			expect( @req.app_path ).to eq( '/userinfo/ged' ) # make sure the slice is non-destructive
		end

		it "knows what HTTP verb the request used" do
			expect( @req.verb ).to eq(:GET)
		end

	end


	describe "request-parameter parsing" do

		context "a GET request" do
			it "has an empty params Hash if the request doesn't have a query string " do
				req = @request_factory.get( '/directory/path' )
				expect( req.params ).to eq({})
			end

			it "has a params Hash with the key/value pair in it if the query string has " +
			   "one key/value pair" do
				req = @request_factory.get( '/directory/path?foo=bar' )
				expect( req.params ).to eq({'foo' => 'bar'})
			end

			it "has a params Hash with the key/value pairs in it if the query string has " +
			   "two pairs seperated with a an ampersand" do
				req = @request_factory.get( '/directory/path?foo=bar&chunky=pork' )
				expect( req.params ).to eq({
					'foo'    => 'bar',
					'chunky' => 'pork',
				})
			end

			it "has a params Hash with the key/value pairs in it if the query string has " +
			   "two pairs with a semi-colon separator" do
				req = @request_factory.get( '/directory/path?potato=gun;legume=bazooka' )
				expect( req.params ).to  eq({
					'potato' => 'gun',
					'legume' => 'bazooka',
				})
			end

			it "has a params Hash with an Array of values if the query string has two values " +
			   "for the same key" do
				req = @request_factory.get( '/directory/path?foo=bar&foo=baz' )
				expect( req.params ).to eq({
					'foo'    => ['bar', 'baz'],
				})
			end

			it "has a params Hash with one Array of values and a scalar value if the query " +
			   "string has three values and two keys" do
				req = @request_factory.get( '/directory/path?foo=bar&foo=pork;mirror=sequel' )
				expect( req.params ).to eq({
					'foo'    => ['bar', 'pork'],
					'mirror' => 'sequel',
				})
			end

			it "responds with a 400 (BAD_REQUEST) for a malformed query string" do
				req = @request_factory.get( '/directory/path?foo' )
				expect {
					req.params
				}.to finish_with( HTTP::BAD_REQUEST, /malformed/i )
			end
		end


		context "a DELETE request without a content type" do
			before( :each ) do
				@req = @request_factory.delete( '/directory/path' )
			end


			it "params are all nil" do
				expect( @req.params[:foo] ).to be_nil
			end
		end


		context "a DELETE request with a 'multipart/form-data' body" do

			before( :each ) do
				@req = @request_factory.delete( '/directory/path',
					'Content-type' => 'multipart/form-data; boundary=--a_boundary' )
			end

			it "returns a hash for form parameters" do
				@req.body = "----a_boundary\r\n" +
					%{Content-Disposition: form-data; name="reason"\r\n} +
					%{\r\n} +
					%{I really don't like this path.\r\n} +
					%{----a_boundary--\r\n}

				expect( @req.params ).to eq({'reason' => "I really don't like this path."})
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
				}.to finish_with( HTTP::BAD_REQUEST, /content type/i )
			end
		end


		context "a POST request with a 'application/x-www-form-urlencoded' body" do

			before( :each ) do
				@req = @request_factory.post( '/directory/path', '',
					'Content-type' => 'application/x-www-form-urlencoded' )
			end

			it "returns an empty Hash for an empty body" do
				@req.body = ''
				expect( @req.params['foo'] ).to be_nil
			end

			it "has a params Hash with the key/value pair in it if the form data has " +
			   "one key/value pair" do
				@req.body = 'foo=bar'
				expect( @req.params ).to eq({'foo' => 'bar'})
			end

			it "has a params Hash with the key/value pairs in it if the form data has " +
			   "two pairs seperated with a an ampersand" do
				@req.body = 'foo=bar&chunky=pork'
				expect( @req.params ).to eq({
					'foo'    => 'bar',
					'chunky' => 'pork',
				})
			end

			it "has a params Hash with the key/value pairs in it if the form data has " +
			   "two pairs with a semi-colon separator" do
				@req.body = 'potato=gun;legume=bazooka'
				expect( @req.params ).to eq({
					'potato' => 'gun',
					'legume' => 'bazooka',
				})
			end

			it "has a params Hash with an Array of values if the form data has two values " +
			   "for the same key" do
				@req.body = 'foo=bar&foo=baz'
				expect( @req.params ).to eq({ 'foo' => ['bar', 'baz'] })
			end

			it "has a params Hash with one Array of values and a scalar value if the form " +
			   "data has three values and two keys" do
				@req.body = 'foo=bar&foo=pork;mirror=sequel'
				expect( @req.params ).to eq({
					'foo'    => ['bar', 'pork'],
					'mirror' => 'sequel',
				})
			end

			it "responds with a 400 (BAD_REQUEST) for malformed parameters" do
				@req.body = '<? skrip_kiddie_stuff ?>'
				expect {
					@req.params
				}.to finish_with( HTTP::BAD_REQUEST, /malformed/i )
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

				expect( @req.params ).to eq({'title' => 'An Impossible Task'})
			end

		end


		context "a POST request with a 'application/json' body" do
			before( :each ) do
				@req = @request_factory.post( '/directory/path', '',
					'Content-type' => 'application/json' )
			end

			it "returns a default params hash for an empty body" do
				@req.body = ''
				expect( @req.params[:foo] ).to be_nil
			end

			it "has the JSON data as the params if it has a body with a JSON object in it" do
				data = {
					'animal' => 'ducky',
					'adjectives' => ['fluffy', 'puddle-ey'],
				}
				@req.body = Yajl.dump( data )
				expect( @req.params ).to eq( data )
			end

			it "has the array as the default param value if the body has a JSON array in it" do
				data = %w[an array of stuff]
				@req.body = Yajl.dump( data )
				expect( @req.params[:foo] ).to eq( data )
			end

			it "responds with a 400 (BAD_REQUEST) for malformed JSON body" do
				@req.body = '<? skrip_kiddie_stuff ?>'
				expect {
					@req.params
				}.to finish_with( HTTP::BAD_REQUEST, /malformed/i )
			end

		end

		context "a POST request with a 'text/x-yaml' body" do
			before( :each ) do
				@req = @request_factory.post( '/directory/path', '',
					'Content-type' => 'text/x-yaml' )
			end

			it "returns a params hash in which all values are nil for an empty body" do
				@req.body = ''
				expect( @req.params[:profile] ).to be_falsey
			end

			it "has the YAML data as the params if it has a body with YAML in it" do
				data = {
					'animal' => 'ducky',
					'adjectives' => ['fluffy', 'puddle-ey'],
				}
				@req.body = data.to_yaml
				expect( @req.params ).to eq( data )
			end

			it "doesn't deserialize Symbols from the YAML body" do
				data = {
					animal: 'horsie',
					adjectives: ['cuddly', 'stompery'],
				}
				@req.body = data.to_yaml

				expect( @req.params.keys ).not_to include( :animal, :adjectives )
			end

			it "doesn't deserialize unsafe objects" do
				obj = OpenStruct.new
				obj.foo = 'stuff'
				obj.bar = 'some other stuff'
				@req.body = obj.to_yaml

				expect( @req.params ).not_to be_a( OpenStruct )
				expect( @req.params ).to eq({
					"table" => {
						":foo" => "stuff",
						":bar" => "some other stuff"
					},
					"modifiable"=>true
				})
			end

			it "handles null entity bodies by returning an empty Hash" do
				@req.body = ''
				expect( @req.params ).to eq( {} )
			end

			it "responds with a 400 (BAD_REQUEST) for malformed YAML body" do
				@req.body = "---\npork:\nwoo\nhooooooooo\n\n"
				expect {
					@req.params
				}.to finish_with( HTTP::BAD_REQUEST, /malformed/i )
			end

		end

	end


	describe "cookie support" do

		before( :each ) do
			@req = @request_factory.get( '/directory/userinfo/ged' )
		end


		it "parses a single cookie into a cookieset with the cookie in it" do
			@req.header.cookie = 'foom=chuckUfarly'
			expect( @req.cookies.size ).to eq(  1  )
			expect( @req.cookies['foom'].value ).to eq( 'chuckUfarly' )
		end

		it "parses multiple cookies into a cookieset with multiple cookies in it" do
			@req.header.cookie = 'foom=chuckUfarly; glarn=hotchinfalcheck'

			expect( @req.cookies.size ).to eq(  2  )
			expect( @req.cookies['foom'].value ).to eq( 'chuckUfarly' )
			expect( @req.cookies['glarn'].value ).to eq( 'hotchinfalcheck' )
		end

		it "responds with a 400 (BAD_REQUEST) response for malformed cookies" do
			@req.header.cookie = 'pork'

			expect {
				@req.cookies
			}.to finish_with( HTTP::BAD_REQUEST, /malformed/i )
		end

	end

end

