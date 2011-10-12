#!/usr/bin/env ruby

require 'mongrel2/httpresponse'
require 'strelka' unless defined?( Strelka )

# An HTTP response class.
class Strelka::HTTPResponse < Mongrel2::HTTPResponse
	include Strelka::Loggable,
	        Strelka::Constants


	### Add some instance variables to new HTTPResponses.
	def initialize( * ) # :notnew:
		super
		@charset = nil
		@languages = []
		@encodings = []
	end


	######
	public
	######

	# Overridden charset of the response's entity body, as either an
	# Encoding or a String. This will be appended to the Content-type
	# header when the response is sent to the client, replacing any charset
	# setting in the Content-type header already. Defaults to nil, which
	# will cause the encoding of the entity body object to be used instead
	# unless there's already one present in the Content-type.  In any
	# case, if the encoding is Encoding::ASCII_8BIT, no charset will be
	# appended to the content-type header.
	attr_accessor :charset

	# An Array of any encodings that have been applied to the response's
	# entity body, in the order they were applied. These will be set as
	# the response's Content-Encoding header when it is sent to the client.
	# Defaults to the empty Array.
	attr_accessor :encodings

	# The natural language(s) of the response's entity body. These will be
	# set as the response's Content-Language header when it is sent to the
	# client. Defaults to the empty Array.
	attr_accessor :languages


	### Overridden to add charset, encodings, and languages to outgoing
	### headers if any of them are set.
	def normalized_headers
		headers = super

		self.add_content_type_charset( headers )
		headers.content_encoding ||= self.encodings.join(', ') unless self.encodings.empty?
		headers.content_language ||= self.languages.join(', ') unless self.languages.empty?

		return headers
	end


	#########
	protected
	#########

	### Add a charset to the content-type header in +headers+ if possible.
	def add_content_type_charset( headers )
		enc = self.charset

		# Explicitly-set character set; strip any existing charset from the content-type header
		# and replace it with the explicit one unless it's ASCII-8BIT
		if enc
			enc = Encoding.find( enc ) unless enc.is_a?( Encoding )
			self.log.debug "Adding explicit charset #{enc.name} to content-type header"
			headers.content_type.slice!( /;\s*charset=\S+\s*/ ) # Remove an existing value
			headers.content_type += "; charset=#{enc.name}" unless enc == Encoding::ASCII_8BIT

		# Derived character set; if it doesn't already have one, add a charset based on the
		# entity body's encoding.
		elsif headers.content_type !~ /\bcharset=/i
			enc = self.entity_body_charset
			unless enc == Encoding::ASCII_8BIT
				self.log.debug "Adding derived charset #{enc.name} to content-type header"
				headers.content_type += "; charset=#{enc.name}"
			end
		end
	end


	### Get the body's charset, if possible. Returns +nil+ if the charset
	### couldn't be determined.
	def entity_body_charset
		entity_body = self.body
		self.log.debug "Deriving charset from the entity body..."

		if entity_body.respond_to?( :encoding )
			self.log.debug "  String-ish API. Encoding is: %p" % [ entity_body.encoding ]
			return entity_body.encoding
		elsif entity_body.respond_to?( :external_encoding )
			self.log.debug "  IO-ish API. Encoding is: %p" % [ entity_body.external_encoding ]
			return entity_body.external_encoding
		end

		self.log.debug "  Body didn't respond to either #encoding or #external_encoding."
		return nil
	end

end # class Strelka::HTTPResponse


