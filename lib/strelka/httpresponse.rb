#!/usr/bin/env ruby

require 'mongrel2/httpresponse'
require 'strelka' unless defined?( Strelka )
require 'strelka/cookieset'

# An HTTP response class.
class Strelka::HTTPResponse < Mongrel2::HTTPResponse
	include Strelka::Loggable,
	        Strelka::Constants


	# Pattern for matching a 'charset' parameter in a media-type string, such as the
	# Content-type header
	CONTENT_TYPE_CHARSET_RE = /;\s*charset=(?<charset>\S+)\s*/i


	### Add some instance variables to new HTTPResponses.
	def initialize( * ) # :notnew:
		@charset   = nil
		@languages = []
		@encodings = []
		@cookies   = nil

		super
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
		self.add_cookie_headers( headers )

		return headers
	end


	### Overridden to reset charset, language, and encoding data, too.
	def reset
		super

		@charset = nil
		@languages.clear
		@encodings.clear
	end


	### Returns a Strelka::CookieSet that can be used to manipulate the cookies that are
	### sent with the response, creating it if necessary.
	def cookies
		@cookies = Strelka::CookieSet.new unless @cookies
		return @cookies
	end



	#########
	protected
	#########

	### Add a charset to the content-type header in +headers+ if possible.
	def add_content_type_charset( headers )
		charset = self.find_header_charset
		self.log.debug "Setting the charset in the content-type header to: %p" % [ charset.name ]

		headers.content_type.slice!( CONTENT_TYPE_CHARSET_RE ) and
			self.log.debug "  removed old charset parameter."
		headers.content_type += "; charset=#{charset.name}" unless charset == Encoding::ASCII_8BIT
	end


	### Try to find a character set for the request, using the #charset attribute first,
	### then the 'charset' parameter from the content-type header, then the Encoding object
	### associated with the entity body, then the default external encoding (if it's set). If
	### none of those are found, this method returns ISO-8859-1.
	def find_header_charset
		return ( self.charset || 
		         self.content_type_charset ||
		         self.entity_body_charset || 
		         Encoding.default_external ||
		         Encoding::ISO_8859_1 )
	end


	### Return an Encoding object for the 'charset' parameter of the content-type
	### header, if there is one.
	def content_type_charset
		return nil unless self.content_type
		name = self.content_type[ CONTENT_TYPE_CHARSET_RE, :charset ] or return nil

		enc = Encoding.find( name )
		self.log.debug "Extracted content-type charset: %p" % [ enc ]

		return enc
	end


	### Get the body's charset, if possible. Returns +nil+ if the charset
	### couldn't be determined.
	def entity_body_charset
		self.log.debug "Deriving charset from the entity body..."

		# Have to use the instance variable instead of #body because plugins can
		# override #body

		if @body.respond_to?( :encoding )
			self.log.debug "  String-ish API. Encoding is: %p" % [ @body.encoding ]
			return @body.encoding
		elsif @body.respond_to?( :external_encoding )
			self.log.debug "  IO-ish API. Encoding is: %p" % [ @body.external_encoding ]
			return @body.external_encoding
		end

		self.log.debug "  Body didn't respond to either #encoding or #external_encoding."
		return nil
	end


	### Add Set-Cookie members to +headers+ if the response has any cookies.
	def add_cookie_headers( headers )
		return unless @cookies
		@cookies.each do |cookie|
			headers.append( :set_cookie => cookie.to_s )
		end
	end

end # class Strelka::HTTPResponse


