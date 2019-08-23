# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# frozen-string-literal: true

require 'loggability'

require 'rspec'
require 'rspec/matchers'

require 'strelka' unless defined?( Strelka )


# A collection of testing functions and classes for use in Strelka handlers
# and libraries.
module Strelka::Testing

	#
	# Matchers
	#

	# Route matcher
	RSpec::Matchers.define( :match_route ) do |routename|
		match do |route|
			route[:action] == routename
		end
	end

	RSpec::Matchers.define_negated_matcher( :exclude, :include )


	# finish_with matcher
	class FinishWithMatcher
		extend Loggability

		log_to :strelka


		### Create a new matcher for the specified +status+, +expected_message+, and
		### +expected_headers+.
		def initialize( status, expected_message=nil, expected_headers={} )

			# Allow headers, but no message
			if expected_message.is_a?( Hash )
				expected_headers = expected_message
				expected_message = nil
			end

			@expected_status  = status
			@expected_message = expected_message
			@expected_headers = expected_headers || {}

			@failure = nil
		end


		######
		public
		######

		##
		# The data structures expected to be part of the response's status_info.
		attr_reader :expected_status, :expected_message, :expected_headers


		### Matcher API -- return true to enable the use of block expectations.
		def supports_block_expectations?
			return true
		end


		### Also expect a header with the given +name+ and +value+ from the response.
		def and_header( name, value=nil )
			if name.is_a?( Hash )
				self.expected_headers.merge!( name )
			else
				self.expected_headers[ name ] = value
			end
			return self
		end


		### RSpec matcher API -- call the +given_proc+ and ensure that it behaves in
		### the expected manner.
		def matches?( given_proc )
			result = nil
			status_info = catch( :finish ) do
				given_proc.call
				nil
			end

			self.log.debug "Test proc called; status info is: %p" % [ status_info ]

			return self.check_finish( status_info ) &&
			       self.check_status_code( status_info ) &&
			       self.check_message( status_info ) &&
			       self.check_headers( status_info )
		end


		### Check the result from calling the proc to ensure it's a status
		### info Hash, returning true if so, or setting the failure message and
		### returning false if not.
		def check_finish( status_info )
			return true if status_info && status_info.is_a?( Hash )
			@failure = "an abnormal status"
			return false
		end


		### Check the result's status code against the expectation, returning true if
		### it was the same, or setting the failure message and returning false if not.
		def check_status_code( status_info )
			return true if status_info[:status] == self.expected_status
			@failure = "a %d status, but got %d instead" %
				[ self.expected_status, status_info[:status] ]
			return false
		end


		### Check the result's status message against the expectation, returning true if
		### it was present and matched the expectation, or setting the failure message
		### and returning false if not.
		def check_message( status_info )
			msg = self.expected_message or return true

			if msg.respond_to?( :match )
				return true if msg.match( status_info[:message] )
				@failure = "a message matching %p, but got: %p" % [ msg, status_info[:message] ]
				return false
			else
				return true if msg == status_info[:message]
				@failure = "the message %p, but got: %p" % [ msg, status_info[:message] ]
				return false
			end
		end


		### Check the result's headers against the expectation, returning true if all
		### expected headers were present and set to expected values, or setting the failure
		### message and returning false if not.
		def check_headers( status_info )
			headers = self.expected_headers or return true
			return true if headers.empty?

			status_headers = Mongrel2::Table.new( status_info[:headers] )
			headers.each do |name, value|
				self.log.debug "Testing for %p header: %p" % [ name, value ]
				unless status_value = status_headers[ name ]
					@failure = "a %s header" % [ name ]
					return false
				end

				if status_value.empty?
					@failure = "a %s header matching %p, but it was blank" % [ name, value ]
					return false
				end

				self.log.debug "  got value: %p" % [ status_value ]
				if value.respond_to?( :match )
					unless value.match( status_value )
						@failure = "a %s header matching %p, but got %p" %
							[ name, value, status_value ]
						return false
					end
				else
					unless value == status_value
						@failure = "the %s header %p, but got %p" %
							[ name, value, status_value ]
						return false
					end
				end
			end

			return true
		end


		### Return a message suitable for describing when the matcher fails when it should succeed.
		def failure_message
			return "expected response to finish_with %s" % [ @failure ]
		end


		### Return a message suitable for describing when the matcher succeeds when it should fail.
		def failure_message_when_negated
			return "expected response not to finish_with %s" % [ @failure ]
		end


	end # class FinishWithMatcher


	# RSpec matcher for matching Strelka::HTTPResponse body
	#
	# Expect that the response consists of JSON of some sort:
	#
	#   expect( last_response ).to have_json_body
	#
	# Expect that it's a JSON body that deserializes as an Object:
	#
	#   expect( last_response ).to have_json_body( Object )
	#   # -or-
	#   expect( last_response ).to have_json_body( Hash )
	#
	# Expect that it's a JSON body that deserializes as an Array:
	#
	#   expect( last_response ).to have_json_body( Array )
	#
	# Expect that it's a JSON body that deserializes as an Object that has
	# expected keys:
	#
	#   expect( last_response ).to have_json_body( Object ).
	#       that_includes( :id, :first_name, :last_name )
	#
	# Expect that it's a JSON body that deserializes as an Object that has
	# expected keys and values:
	#
	#   expect( last_response ).to have_json_body( Object ).
	#       that_includes(
	#           id: 118,
	#           first_name: 'Princess',
	#           last_name: 'Buttercup'
	#       )
	#
	# Expect that it's a JSON body that has other expected stuff:
	#
	#   expect( last_response ).to have_json_body( Object ).
	#       that_includes(
	#           last_name: a_string_matching(/humperdink/i),
	#           profile: a_hash_including(:age, :eyecolor, :tracking_ability)
	#       )
	#
	# Expect a JSON Array with objects that all match the criteria:
	#
	#   expect( last_response ).to have_json_body( Array ).
	#       of_lenth( 20 ).
	#       and( all( be_an(Integer) ) )
	#
	class HaveJSONBodyMatcher
		extend Loggability
		include RSpec::Matchers


		log_to :strelka


		### Create a new matcher that expects a response with a JSON body. If +expected_type+
		### is not specified, any JSON body will be sufficient for a match.
		def initialize( expected_type=nil )
			@expected_type = expected_type
			@additional_expectations = []
			@response = nil
			@failure_description = nil
		end


		attr_reader :expected_type,
			:additional_expectations,
			:response,
			:failure_description


		### RSpec matcher API -- returns +true+ if all expectations of the specified
		### +response+ are met.
		def matches?( response )
			@response = response

			return self.correct_content_type? &&
				self.correct_json_type? &&
				self.matches_additional_expectations?
		rescue Yajl::ParseError => err
			return self.fail_with "Response has invalid JSON body: %s" % [ err.message ]
		end


		### RSpec matcher API -- return a message describing an expectation failure.
		def failure_message
			return "\n---\n%s\n---\n\nReason: %s\n" % [
				self.pretty_print_response,
				self.failure_description
			]
		end


		### RSpec matcher API -- return a message describing an expectation being met
		### when the matcher was used in a negated context.
		def failure_message_when_negated
			msg = "expected response not to have a %s" % [ self.describe_type_expectation ]
			msg << " and " << self.describe_additional_expectations.join( ', ' ) unless
				self.additional_expectations.emtpy?
			msg << ", but it did."

			return "\n---\n%s\n---\n\nReason: %s\n" % [
				self.pretty_print_response,
				msg
			]
		end


		### Return the response's body parsed as JSON.
		def parsed_response_body
			return @parsed_response_body ||=
				Yajl::Parser.parse( self.response.body, check_utf8: true, symbolize_keys: true )
		end


		#
		# Mutators
		#

		### Add an additional expectation that the JSON body contains the specified +members+.
		def that_includes( *memberset )
			@additional_expectations << include( *memberset )
			return self
		end
		alias_method :which_includes, :that_includes


		### Add an additional expectation that the JSON body does not contain the
		### specified +members+.
		def that_excludes( *memberset )
			@additional_expectations << exclude( *memberset )
			return self
		end


		### Add an additional expectation that the JSON body contain the specified
		### +number+ of members.
		def of_length( number )
			@additional_expectations << have_attributes( length: number )
			return self
		end
		alias_method :of_size, :of_length


		### Add the specified +matchers+ as expectations of the Hash or Array that's
		### parsed from the JSON body.
		def and( *matchers )
			@additional_expectations.concat( matchers )
			return self
		end


		#########
		protected
		#########

		### Return a String that contains a pretty-printed version of the response object.
		def pretty_print_response
			return self.response.to_s
		end


		### Return +false+ after setting the failure message to +message+.
		def fail_with( message )
			@failure_description = message
			self.log.error "Failing with: %s" % [ message ]
			return false
		end


		### Returns +true+ if the response has a JSON content-type header.
		def correct_content_type?
			content_type = self.response.headers[:content_type] or
				return self.fail_with "response doesn't have a Content-type header"

			return fail_with "response's Content-type is %p" % [ content_type ] unless
				content_type.start_with?( 'application/json' ) ||
				content_type.match?( %r|\Aapplication/(vnd\.)?\w+\+json\b| )

			return true
		end


		### Return an Array of text describing the expectation that the body be an
		### Object or an Array, if a type was expected. If no type was expected, returns
		### an empty Array.
		def describe_type_expectation
			return case self.expected_type
				when Object, Hash
					"a JSON Object/Hash body"
				when Array
					"a JSON Array body"
				else
					"a JSON body"
				end
		end


		### Check that the JSON body of the response has the correct type, if a type
		### was specified.
		def correct_json_type?
			return self.parsed_response_body unless self.expected_type

			if self.expected_type == Array
				return self.fail_with( "response body isn't a JSON Array" ) unless
					self.parsed_response_body.is_a?( Array )
			elsif self.expected_type == Object || self.expected_type == Hash
				return self.fail_with( "response body isn't a JSON Object" ) unless
					self.parsed_response_body.is_a?( Hash )
			else
				warn "A valid JSON response can't be a %p!" % [ self.expected_type ]
			end

			return true
		end


		### Return an Array of descriptions of the members that were expected to be included in the
		### response body, if any were specified. If none were specified, returns an empty
		### Array.
		def describe_additional_expectations
			return self.additional_expectations.map( &:description )
		end


		### Check that any additional matchers registered via the `.and` mutator also
		### match the parsed response body.
		def matches_additional_expectations?
			return self.additional_expectations.all? do |matcher|
				matcher.matches?( self.parsed_response_body ) or
					fail_with( matcher.failure_message )
			end
		end

	end # class HaveJSONBodyMatcher


	# RSpec matcher for matching Strelka::HTTPResponse body from a collection endpoint
	#
	# Expect that the response is a JSON Array of Objects:
	#
	#   expect( last_response ).to have_json_collection
	#
	# Expect that there be 4 Objects in the collection:
	#
	#   expect( last_response ).to have_json_collection.of_length( 4 )
	#
	# Expect that the collection's objects each have an `id` field with the specified
	# IDs:
	#
	#   expect( last_response ).to have_json_collection.with_ids( 3, 6, 11, 14 )
	#   # -or- with an Array of IDs (no need to splat them)
	#   ids = [3, 6, 11, 14]
	#   expect( last_response ).to have_json_collection.with_ids( ids )
	#
	# Expect that the collection's objects have the same IDs as an Array of model
	# objects (or other objects that respond to #pk):
	#
	#   payments = payment_fixture_factory.take( 4 )
	#   expect( last_response ).to have_json_collection.
	#       with_same_ids_as( payments )
	#
	# Expect that the collection's objects have the same IDs as an Array of Hashes with
	# `:id` fields:
	#
	#   payment_rows = payments_table.where( sender_id: 71524 ).all
	#   expect( last_response ).to have_json_collection.
	#       with_same_ids_as( payment_rows )
	#
	# Expect that the collection's objects appear in the same order as the source Array:
	#
	#   payments = payment_fixture_factory.take( 4 )
	#   expect( last_response ).to have_json_collection.
	#       with_same_ids_as( payments ).in_same_order
	#
	# Add aggregate matchers for each object in the collection:
	#
	#   expect( last_response ).to have_json_collection.
	#       with_same_ids_as( payments ).
	#       and_all( include(amount_cents: a_value > 0) )
	#
	class HaveJSONCollectionMatcher < HaveJSONBodyMatcher
		include RSpec::Matchers


		### Overridden to set the expected type to Array.
		def initialize # :notnew:
			super( Array )

			@additional_expectations << all( be_a Hash )

			@expected_ids   = nil
			@collection_ids = nil
			@extra_ids      = nil
			@missing_ids    = nil
			@order_enforced = false
		end


		######
		public
		######

		# Sets of IDs, actual vs. expected
		attr_reader :expected_ids,
			:collection_ids,
			:extra_ids,
			:missing_ids,
			:order_enforced


		### Overridden to include matching against collection IDs.
		def matches?( response )
			return false unless super( response )

			if @expected_ids
				@collection_ids = self.parsed_response_body.collect {|obj| obj[:id] }
				@extra_ids = @collection_ids - @expected_ids
				@missing_ids = @expected_ids - @collection_ids
			end

			return self.has_required_ids?
		end


		### Return an Array of text describing the expectation that the body be an
		### Object or an Array, if a type was expected. If no type was expected, returns
		### an empty Array.
		def describe_type_expectation
			return "a JSON collection (Array of Objects)"
		end


		### Add the specified +matchers+ as expectations of each member of the collection.
		def and_all( *matchers )
			matchers = matchers.map {|m| all( m ) }
			@additional_expectations.concat( matchers )
			return self
		end


		### Set the expectation that the given +expected_ids+ will be present as the
		### values of the `:id` field of the collection.
		def with_ids( *expected_ids )
			self.and_all( include :id )
			@expected_ids = expected_ids.flatten( 1 )
			return self
		end


		### Add an expectation that the collection's objects all have an ':id' field,
		### and that the corresponding values be the same as the primary key values of
		### the given +objects+ (fetched via their #pk methods).
		def with_same_ids_as( *objects )
			objects.flatten!( 1 )

			ids = if objects.first.respond_to?( :pk )
					objects.flatten.map( &:pk )
				else
					objects.map {|obj| obj[:id] }
				end

			return self.with_ids( *ids )
		end


		### Enforce ordering when matching IDs.
		def in_same_order
			@order_enforced = true
			return self
		end


		### Adds an expectation that all members of the resulting collection have each
		### of the keys in the specified +fieldset+.
		def with_fields( *fieldset )
			return self.and_all( include *fieldset )
		end
		alias_method :and_fields, :with_fields


		#########
		protected
		#########

		### Returns +true+ if the collection contains exactly the IDs specified by
		### #with_same_ids_as, or if no IDs were specified.
		def has_required_ids?
			return true unless @expected_ids

			if @order_enforced && @expected_ids != @collection_ids
				return self.fail_with "expected collection IDs to be %p, but they were: %p" %
					[ @expected_ids, @collection_ids ]
			elsif @missing_ids && !@missing_ids.empty?
				return self.fail_with( "collection is missing expected IDs: %p" % [@missing_ids] )
			elsif @extra_ids && !@extra_ids.empty?
				return self.fail_with( "collection has extra IDs: %p" % [@extra_ids] )
			end

			return true
		end

	end # class HaveJSONCollectionMatcher



	###############
	module_function
	###############

	### Match a response thrown via the +finish_with+ function.
	def finish_with( status, message=nil, headers={} )
		return FinishWithMatcher.new( status, message, headers )
	end


	### Create a new matcher that will expect the response to have a JSON body of
	### the +expected_type+. If +expected_type+ is omitted, any JSON body will be sufficient
	### for a match.
	def have_json_body( expected_type=nil )
		return HaveJSONBodyMatcher.new( expected_type )
	end


	### Create a new matcher that will expect the response to have a JSON body which is
	### an Array of Objects (Hashes).
	def have_json_collection
		return HaveJSONCollectionMatcher.new
	end


	### Parse the body of the last response and return it as a Ruby object.
	def last_response_json_body( expected_type=nil )
		@have_json_body_matcher ||= begin
			matcher = have_json_body( expected_type )
			expect( last_response ).to( matcher )
			matcher
		end

		return @have_json_body_matcher.parsed_response_body
	end

end # module Strelka::Testing


