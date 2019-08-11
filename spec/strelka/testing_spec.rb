# -*- ruby -*-
# frozen_string_literal: true

require_relative '../helpers'

require 'ostruct'
require 'mongrel2/testing'
require 'strelka/testing'


RSpec.describe( Strelka::Testing ) do

	#
	# Expectation-failure Matchers (stolen from rspec-expectations)
	# See the README for licensing information.
	#

	def fail
		raise_error( RSpec::Expectations::ExpectationNotMetError )
	end


	def fail_with( message )
		raise_error( RSpec::Expectations::ExpectationNotMetError, message )
	end


	def fail_matching( message )
		if String === message
			regexp = /#{Regexp.escape( message )}/
		else
			regexp = message
		end
		raise_error( RSpec::Expectations::ExpectationNotMetError, regexp )
	end


	def fail_including( *messages )
		raise_error do |err|
			expect( err ).to be_a( RSpec::Expectations::ExpectationNotMetError )
			expect( err.message ).to include( *messages )
		end
	end


	before( :all ) do
		@request_factory = Mongrel2::RequestFactory.new( route: '/v1/api' )
	end


	describe "finish_with matcher" do

		before( :each ) do
			@app = Class.new( Strelka::App ) do
				def initialize( &block )
					@block = block
					super( TEST_APPID, TEST_SEND_SPEC, TEST_RECV_SPEC )
				end

				def handle_request( req )
					self.instance_exec( req, &@block )
				end
			end
		end

		let( :request ) { @request_factory.get('/v1/api/users') }


		it "passes if the app finishes with the expected criteria" do
			expect {
				expect {
					@app.new { finish_with(404, "Not found.") }.handle_request( request )
				}.to finish_with( 404, /not found/i )
			}.not_to raise_error
		end


		it "passes if the app finishes with the expected criteria and headers" do
			expect {
				expect {
					@app.new {
						finish_with( 303, "See other resource.", location: 'http://ac.me/resource' )
					}.handle_request( request )
				}.to finish_with( 303, /see other/i, 'Location' => 'http://ac.me/resource' )
			}.not_to raise_error
		end


		it "fails if the app doesn't call finish_with" do
			expect {
				expect {
					@app.new {|req| req.response }.handle_request( request )
				}.to finish_with( 404, /not found/i )
			}.to fail_matching( /expected response to finish_with/i )
		end


		it "fails if the app finishes with a different status" do
			expect {
				expect {
					@app.new {
						finish_with( 415, "Unsupported media type." )
					}.handle_request( request )
				}.to finish_with( 404, /not found/i )
			}.to fail_matching( /with a 404 status, but got 415/i )
		end


		it "fails if the app finishes with the correct status, but the wrong message" do
			expect {
				expect {
					@app.new {
						finish_with( 404, "No such user." )
					}.handle_request( request )
				}.to finish_with( 404, /not found/i )
			}.to fail_matching( /with a message matching/i )
		end


		it "fails if the app finishes with the correct status and message, but missing a header" do
			expect {
				expect {
					@app.new {
						finish_with( 301, "Moved permanently" )
					}.handle_request( request )
				}.to finish_with( 301, /moved/i, location: 'http://ac.me/this' )
			}.to fail_matching( /with a location header/i )
		end


		it "fails if the app finishes with the specified header set to an empty string" do
			expect {
				expect {
					@app.new {
						finish_with( 301, "Moved permanently", location: '' )
					}.handle_request( request )
				}.to finish_with( 301, /moved/i, location: 'http://ac.me/this' )
			}.to fail_matching( /with a location header.*blank/i )
		end


		it "fails if the app finishes with the specified header set to the wrong value" do
			expect {
				expect {
					@app.new {
						finish_with( 301, "Moved permanently", location: 'http://localhost' )
					}.handle_request( request )
				}.to finish_with( 301, /moved/i, location: 'http://ac.me/this' )
			}.to fail_matching( /with a location header.*ac\.me.*localhost/i )
		end

	end


	describe "have_json_body matcher" do

		let( :request ) { @request_factory.get('/v1/api') }


		it "fails if the response doesn't have a content type" do
			response = request.response

			expect {
				expect( response ).to have_json_body
			}.to fail_matching( /doesn't have a content-type/i )
		end


		it "fails if the response doesn't have an 'application/json' content type" do
			response = request.response
			response.content_type = 'text/plain'
			response.puts "Stuff."

			expect {
				expect( response ).to have_json_body
			}.to fail_matching( /content-type is/i )
		end


		it "fails if the response body doesn't contain valid JSON" do
			response = request.response
			response.content_type = 'application/json'
			response.body = '<'

			expect {
				expect( response ).to have_json_body
			}.to fail_matching( /invalid JSON/i )
		end


		context "with no additional criteria" do

			it "passes for a valid JSON response" do
				response = request.response
				response.content_type = 'application/json'
				response.body = '{}'

				expect {
					expect( response ).to have_json_body
				}.to_not raise_error
			end

		end


		context "with a type specification" do

			let( :response ) do
				res = request.response
				res.content_type = 'application/json'
				res.body = '{}'
				res
			end


			it "passes for a valid JSON response of the specified type" do
				expect {
					expect( response ).to have_json_body( Object )
				}.to_not raise_error
			end


			it "fails for a valid JSON response of a different type" do
				expect {
					expect( response ).to have_json_body( Array )
				}.to fail_matching( /response body isn't a JSON Array/i )
			end

		end


		context "with a member specification" do

			let( :object_response ) do
				res = request.response
				res.content_type = 'application/json'
				res.body = '{"message":"the message"}'
				res
			end
			let( :array_response ) do
				res = request.response
				res.content_type = 'application/json'
				res.body = '["message"]'
				res
			end


			it "passes for a valid JSON Object response that includes the specified members" do
				expect {
					expect( object_response ).to have_json_body.that_includes( :message )
				}.to_not raise_error
			end


			it "passes for a valid JSON Array response that includes the specified members" do
				expect {
					expect( array_response ).to have_json_body.that_includes( 'message' )
				}.to_not raise_error
			end


			it "fails for a valid JSON response that doesn't include the specified member" do
				expect {
					expect( object_response ).to have_json_body.that_includes( :code )
				}.to fail_matching( /to include :code/i )
			end


			it "passes for a valid JSON Object response that excludes the specified members" do
				expect {
					expect( object_response ).to have_json_body.that_excludes( :other )
				}.to_not raise_error
			end


			it "passes for a valid JSON Array response that excludes the specified members" do
				expect {
					expect( array_response ).to have_json_body.that_excludes( 'other' )
				}.to_not raise_error
			end


			it "fails for a valid JSON response that doesn't exclude the specified member" do
				expect {
					expect( object_response ).to have_json_body.that_excludes( :message )
				}.to fail_matching( /not to include :message/i )
			end

		end


		context "with a length specification" do

			let( :object_response ) do
				res = request.response
				res.content_type = 'application/json'
				res.body = '{"ebb":"nitzer", "chant":"join in the"}'
				res
			end
			let( :array_response ) do
				res = request.response
				res.content_type = 'application/json'
				res.body = '["lies","gold","guns","fire","gold","judge","guns","fire"]'
				res
			end


			it "passes for a valid JSON Object response that has the specified number of members" do
				expect {
					expect( object_response ).to have_json_body.of_length( 2 )
				}.to_not raise_error
			end


			it "passes for a valid JSON Array response that includes the specified members" do
				expect {
					expect( array_response ).to have_json_body.of_length( 8 )
				}.to_not raise_error
			end


			it "fails for a valid JSON response that doesn't include the specified member" do
				expect {
					expect( array_response ).to have_json_body.of_length( 2 )
				}.to fail_matching( /:length => 2/i )
			end

		end


		context "with a type and a member specification" do

			let( :object_response ) do
				res = request.response
				res.content_type = 'application/json'
				res.body = '{"message":"the message"}'
				res
			end
			let( :array_response ) do
				res = request.response
				res.content_type = 'application/json'
				res.body = '["message"]'
				res
			end


			it "passes for a valid JSON Object response that is of the correct type and includes " +
			   "the specified members" do
				expect {
					expect( object_response ).to have_json_body( Object ).that_includes( :message )
				}.to_not raise_error
			end


			it "fails for a valid JSON response that includes the specified members " +
			   "but is of a different type" do
				expect {
					expect( array_response ).to have_json_body( Object ).that_includes( 'message' )
				}.to fail_matching( /isn't a JSON Object/i )
			end


			it "fails for a valid JSON response that is of the correct type " +
			   "but doesn't include the specified members " do
				expect {
					expect( object_response ).to have_json_body( Object ).that_includes( :code )
				}.to fail_matching( /to include :code/i )
			end

		end


		context	"with a type and a length specification" do

			let( :object_response ) do
				res = request.response
				res.content_type = 'application/json'
				res.body = '{"message":"the message","type":"the type"}'
				res
			end
			let( :array_response ) do
				res = request.response
				res.content_type = 'application/json'
				res.body = '["message","type","brand"]'
				res
			end


			it "passes for a valid JSON Object response that is of the correct type and length" do
				expect {
					expect( object_response ).to have_json_body( Object ).of_length( 2 )
				}.to_not raise_error
			end


			it "fails for a valid JSON response that includes the specified length " +
			   "but is of a different type" do
				expect {
					expect( array_response ).to have_json_body( Object ).of_length( 2 )
				}.to fail_matching( /isn't a JSON Object/i )
			end


			it "fails for a valid JSON response that is of the correct type but a different length" do
				expect {
					expect( array_response ).to have_json_body( Array ).of_length( 2 )
				}.to fail_matching( /length: 2/i )
			end

		end


		context "with additional expectations" do

			let( :object_response ) do
				res = request.response
				res.content_type = 'application/json'
				res.body = '{"message":"the message", "massage":"Shiatsu", "messiah":"complex"}'
				res
			end
			let( :array_response ) do
				res = request.response
				res.content_type = 'application/json'
				res.body = '["message", "note", "postage", "demiurge"]'
				res
			end


			it "passes for a valid JSON Object that matches all of them" do
				expect {
					expect( object_response ).to have_json_body( Object ).
						and( all( satisfy {|key,val| key.length > 4} ) )
				}.to_not raise_error
			end


			it "passes for a valid JSON Array that matches all of them" do
				expect {
					expect( array_response ).to have_json_body( Array ).
						and( all( be_a( String ) ) ).
						and( all( end_with( 'e' ) ) )
				}.to_not raise_error
			end


			it "fails for a valid JSON Object that doesn't match all of them" do
				expect {
					expect( object_response ).to have_json_body( Object ).
						and( all( satisfy {|key,_| key.length > 4} ) ).
						and( all( satisfy {|key,_| key.to_s.end_with?( 'e' )} ) )
				}.to fail_matching( /to all satisfy expression/ )
			end


			it "fails for a valid JSON Array that doesn't match all of them" do
				expect {
					expect( array_response ).to have_json_body( Array ).
						and( all( be_a( String ) ) ).
						and( all( start_with( 'm' ) ) )
				}.to fail_matching( /to all start with "m"/ )
			end

		end

	end


	describe "have_json_collection matcher" do

		let( :request ) { @request_factory.get('/v1/api') }


		it "fails if the response doesn't have a content type" do
			response = request.response

			expect {
				expect( response ).to have_json_collection
			}.to fail_matching( /doesn't have a content-type/i )
		end


		it "fails if the response doesn't have an 'application/json' content type" do
			response = request.response
			response.content_type = 'text/plain'
			response.body = 'Stuff.'

			expect {
				expect( response ).to have_json_collection
			}.to fail_matching( /content-type is/i )
		end


		it "fails if the response body doesn't contain valid JSON" do
			response = request.response
			response.content_type = 'application/json'
			response.body = '<'

			expect {
				expect( response ).to have_json_collection
			}.to fail_matching( /invalid JSON/i )
		end


		it "fails if the response body isn't an Array" do
			response = request.response
			response.content_type = 'application/json'
			response.body = '{}'

			expect {
				expect( response ).to have_json_collection
			}.to fail_matching( /response body isn't a json array/i )
		end


		it "fails if the response body isn't an Array of Objects" do
			response = request.response
			response.content_type = 'application/json'
			response.body = '[[],[]]'

			expect {
				expect( response ).to have_json_collection
			}.to fail_matching( /expected \[\] to be a kind of Hash/i )
		end


		context "with no additional criteria" do

			it "passes for a response that has a JSON array of objects" do
				response = request.response
				response.content_type = 'application/json'
				response.body = '[{},{},{}]'

				expect {
					expect( response ).to have_json_collection
				}.to_not raise_error
			end

		end


		context "with a set of IDs to match" do

			let( :response ) do
				response = request.response
				response.content_type = 'application/json'
				response.body = '[{"id": 11}, {"id": 19}, {"id": 5}]'
				return response
			end


			it "passes for a response that has objects with the same IDs" do
				expect {
					expect( response ).to have_json_collection.with_ids( 5, 11, 19 )
				}.to_not raise_error
			end


			it "fails for a response whose objects don't have ID fields" do
				response = request.response
				response.content_type = 'application/json'
				response.body = '[{"size": 11}, {"size": 19}, {"size": 5}]'

				expect {
					expect( response ).to have_json_collection.with_ids( 5, 11, 19 )
				}.to fail_matching( /expected.*to include :id/i )
			end


			it "fails for a response that has objects with extra IDs" do
				expect {
					expect( response ).to have_json_collection.with_ids( 5, 11 )
				}.to fail_matching( /collection has extra ids: \[19\]/i )
			end


			it "fails for a response that has objects with missing IDs" do
				expect {
					expect( response ).to have_json_collection.with_ids( 5, 11, 19, 23 )
				}.to fail_matching( /collection is missing expected ids: \[23\]/i )
			end


			it "fails for a response that has both missing and extra IDs" do
				expect {
					expect( response ).to have_json_collection.with_ids( 5, 11, 23 )
				}.to fail_matching( /collection is missing expected ids: \[23\]/i )
			end

		end


		context "with a set of model objects to match" do

			let( :response ) do
				response = request.response
				response.content_type = 'application/json'
				response.body = '[{"id": 11}, {"id": 19}, {"id": 5}]'
				return response
			end


			it "passes for a response that has objects with the same PKs" do
				objects = [ 5, 11, 19 ].map {|id| OpenStruct.new( pk: id ) }
				expect {
					expect( response ).to have_json_collection.with_same_ids_as( *objects )
				}.to_not raise_error
			end


			it "doesn't require the object Array to be splatted" do
				objects = [ 5, 11, 19 ].map {|id| OpenStruct.new( pk: id ) }
				expect {
					expect( response ).to have_json_collection.with_same_ids_as( objects )
				}.to_not raise_error
			end


			it "passes for a response that has fields with the same `:id` key" do
				objects = [ { id: 5 }, { id: 11 }, { id: 19 }, ]
				expect {
					expect( response ).to have_json_collection.with_same_ids_as( *objects )
				}.to_not raise_error
			end


			it "fails for a response that has objects with extra IDs" do
				objects = [ 5, 19 ].map {|id| OpenStruct.new( pk: id ) }
				expect {
					expect( response ).to have_json_collection.with_same_ids_as( objects )
				}.to fail_matching( /collection has extra ids: \[11\]/i )
			end

		end


		context	"with a set of ordered IDs to match" do

			let( :response ) do
				response = request.response
				response.content_type = 'application/json'
				response.body = '[{"id": 11}, {"id": 19}, {"id": 5}]'
				return response
			end


			it "passes for a response that has objects with the same IDs in the same order" do
				expect {
					expect( response ).to have_json_collection.with_ids( 11, 19, 5 ).in_same_order
				}.to_not raise_error
			end


			it "fails for a response with the same IDs but in a different order" do
				expect {
					expect( response ).to have_json_collection.with_ids( 5, 11, 19 ).in_same_order
				}.to fail_matching( /expected collection ids to be/i )
			end

		end


		context "with a set of fields to require" do

			let( :response ) do
				response = request.response
				response.content_type = 'application/json'
				response.body = '[{"id": 11, "name": "Chris", "age": 23}, ' +
					'{"id": 19, "name": "Simone", "age": 37}]'
				return response
			end


			it "passes for a response that has the required fields" do
				expect {
					expect( response ).to have_json_collection.with_fields( :id, :name, :age )
				}.to_not raise_error
			end


			it "fails for a response with the same IDs but in a different order" do
				expect {
					expect( response ).to have_json_collection.with_fields( :id, :first_name, :age )
				}.to fail_matching( /to include :first_name/i )
			end


		end

	end


	describe "last_response_json_body" do

		let( :request ) { @request_factory.get('/v1/api') }


		context "with a non-JSON response" do

			let( :last_response ) { request.response }


			it "fails due to the have_json_body expectation first" do
				expect {
					expect( last_response_json_body[:title] ).to eq( 'Ethel the Aardvark' )
				}.to fail_matching( /doesn't have a content-type/i )
			end

		end


		context "with a JSON response" do

			let( :last_response ) do
				response = request.response
				response.content_type = 'application/json'
				response.body = '{"title":"Ethel the Aardvark"}'
				return response
			end


			it "returns the JSON body if the inner expectation passes" do
				expect {
					expect( last_response_json_body[:title] ).to eq( 'Ethel the Aardvark' )
				}.to_not raise_error()
			end


			it "fails if the outer expectation fails" do
				expect {
					expect( last_response_json_body ).to be_empty
				}.to fail_matching( /empty\?/ )
			end

		end

	end

end

