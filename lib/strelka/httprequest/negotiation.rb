# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require 'strelka/constants'
require 'strelka/httprequest' unless defined?( Strelka::HTTPRequest )
require 'strelka/httprequest/acceptparams'


# The mixin that adds methods to Strelka::HTTPRequest for content-negotiation.
#
#   request.accepts?( 'application/json' )
#   request.explicitly_accepts?( 'application/xml+rdf' )
#   request.accepts_charset?( Encoding::UTF_8 )
#   request.accepts_charset?( 'iso-8859-15' )
#   request.accepts_encoding?( 'compress' )
#   request.accepts_language?( 'en' )
#   request.explicitly_accepts_language?( 'en' )
#   request.explicitly_accepts_language?( 'en-gb' )
#
module Strelka::HTTPRequest::Negotiation
	include Strelka::Constants

	### Extension callback -- add instance variables to extended objects.
	def initialize( * )
		super
		@accepted_mediatypes = nil
		@accepted_charsets   = nil
		@accepted_encodings  = nil
		@accepted_languages  = nil
	end


	### Fetch the value of the given +header+, split apart the values, and parse
	### each one using the specified +paramclass+. If no values are parsed from
	### the header, and a block is given, the block is called and its return value
	### is appended to the empty Array before returning it.
	def parse_negotiation_header( header, paramclass )
		self.log.debug "Parsing %s header into %p objects" % [ header, paramclass ]
		rval = []
		headerval = self.headers[ header ]
		self.log.debug "  raw header value: %p" % [ headerval ]

		# Handle the case where there's more than one of the header in question by
		# forcing everything to an Array
		Array( headerval ).compact.flatten.each do |paramstr|
			paramstr.split( /\s*,\s*/ ).each do |param|
				self.log.debug "    parsing param: %p" % [ param ]
				rval << paramclass.parse( param )
			end
		end

		if rval.empty? && block_given?
			self.log.debug "  no parsed values; calling the fallback block"
			rval << yield
		end

		return rval.flatten
	end


	#
	# :section: Mediatype negotiation
	#

	### Return an Array of Strelka::HTTPRequest::MediaType objects for each
	### type in the 'Accept' header.
	def accepted_mediatypes
		@accepted_mediatypes ||= self.parse_accept_header
		return @accepted_mediatypes
	end
	alias_method :accepted_types, :accepted_mediatypes


	### Returns boolean true/false if the requestor can handle the given
	### +content_type+.
	def accepts?( content_type )
		self.log.debug "Checking to see if request accepts %p" % [ content_type ]
		atype = self.accepted_types.find {|type| type =~ content_type }
		self.log.debug "  find returned: %p" % [ atype ]
		return atype ? true : false
	end
	alias_method :accept?, :accepts?


	### Returns boolean true/false if the requestor can handle the given
	### +content_type+, not including mime wildcards.
	def explicitly_accepts?( content_type )
		non_wildcard_types = self.accepted_types.reject {|param| param.subtype.nil? }
		return non_wildcard_types.find {|type| type =~ content_type } ? true : false
	end
	alias_method :explicitly_accept?, :explicitly_accepts?


	### Parse the receiver's 'Accept' header and return it as an Array of
	### Strelka::HTTPRequest::MediaType objects.
	def parse_accept_header
		return self.parse_negotiation_header( :accept, Strelka::HTTPRequest::MediaType ) do
			Strelka::HTTPRequest::MediaType.new( '*', '*' )
		end
	rescue => err
		self.log.error "%p while parsing the Accept header: %s" % [ err.class, err.message ]
		self.log.debug "  %s" % [ err.backtrace.join("\n  ") ]
		finish_with HTTP::BAD_REQUEST, "Malformed Accept header"
	end


	#
	# :section: Charset negotiation
	#

	### Return an Array of Strelka::HTTPRequest::Charset objects for each
	### type in the 'Accept-Charset' header.
	def accepted_charsets
		@accepted_charsets ||= self.parse_accept_charset_header
		return @accepted_charsets
	end


	### Returns boolean true/false if the requestor can handle the given
	### +charset+.
	def accepts_charset?( charset )
		self.log.debug "Checking to see if request accepts charset: %p" % [ charset ]
		aset = self.accepted_charsets.find {|cs| cs =~ charset }
		self.log.debug "  find returned: %p" % [ aset ]
		return aset ? true : false
	end
	alias_method :accept_charset?, :accepts_charset?


	### Returns boolean true/false if the requestor can handle the given
	### +charset+, not including the wildcard tag if present.
	def explicitly_accepts_charset?( charset )
		non_wildcard_charsets = self.accepted_charsets.reject {|param| param.charset.nil? }
		return non_wildcard_charsets.find {|cs| cs =~ charset } ? true : false
	end
	alias_method :explicitly_accept_charset?, :explicitly_accepts_charset?


	### Parse the receiver's 'Accept-Charset' header and return it as an Array of
	### Strelka::HTTPRequest::Charset objects.
	def parse_accept_charset_header
		return self.parse_negotiation_header( :accept_charset, Strelka::HTTPRequest::Charset ) do
			Strelka::HTTPRequest::Charset.new( '*' )
		end
	end


	#
	# :section: Encoding negotiation
	#

	### Return an Array of Strelka::HTTPRequest::Encoding objects for each
	### type in the 'Accept-Encoding' header.
	def accepted_encodings
		@accepted_encodings ||= self.parse_accept_encoding_header
		return @accepted_encodings
	end


	### Returns boolean true/false if the requestor can handle the given
	### +encoding+.
	def accepts_encoding?( encoding )
		self.log.debug "Checking to see if request accepts encoding: %p" % [ encoding ]
		return true if self.accepted_encodings.empty?
		found_encoding = self.accepted_encodings.find {|enc| enc =~ encoding }
		self.log.debug "  find returned: %p" % [ found_encoding ]

		# If there was no match, then it's not accepted, unless it's the 'identity'
		# encoding, which is accepted unless it's disabled.
		return encoding == 'identity' if !found_encoding

		return found_encoding.qvalue.nonzero?
	end
	alias_method :accept_encoding?, :accepts_encoding?


	### Returns boolean true/false if the requestor can handle the given
	### +encoding+, not including the wildcard encoding if present.
	def explicitly_accepts_encoding?( encoding )
		non_wildcard_encodings = self.accepted_encodings.reject {|enc| enc.content_coding.nil? }
		found_encoding = non_wildcard_encodings.find {|enc| enc =~ encoding } or
			return false
		return found_encoding.qvalue.nonzero?
	end
	alias_method :explicitly_accept_encoding?, :explicitly_accepts_encoding?


	### Parse the receiver's 'Accept-Encoding' header and return it as an Array of
	### Strelka::HTTPRequest::Encoding objects.
	def parse_accept_encoding_header
		return self.parse_negotiation_header( :accept_encoding, Strelka::HTTPRequest::Encoding ) do
			# If the Accept-Encoding field-value is empty, then only the "identity"
			# encoding is acceptable.
			if self.headers.include?( :accept_encoding )
				self.log.debug "Empty accept-encoding header: identity-only"
				[ Strelka::HTTPRequest::Encoding.new('identity') ]

			# I have no idea how this is different than an empty accept-encoding header
			# for any practical case, but RFC2616 says:
			#   If no Accept-Encoding field is present in a request, the server MAY
			#   assume that the client will accept any content coding.  In this
			#   case, if "identity" is one of the available content-codings, then
			#   the server SHOULD use the "identity" content-coding, unless it has
			#   additional information that a different content-coding is meaningful
			#   to the client.
			else
				self.log.debug "No accept-encoding header: identity + any encoding"
				[
					Strelka::HTTPRequest::Encoding.new( 'identity' ),
					Strelka::HTTPRequest::Encoding.new( '*', nil, 0.9 )
				]
			end
		end
	end



	#
	# :section: Language negotiation
	#

	### Return an Array of Strelka::HTTPRequest::Language objects for each
	### type in the 'Accept-Language' header.
	def accepted_languages
		@accepted_languages ||= self.parse_accept_language_header
		return @accepted_languages
	end


	### Returns boolean true/false if the requestor can handle the given
	### +language+.
	def accepts_language?( language )
		self.log.debug "Checking to see if request accepts language: %p" % [ language ]
		found_language = self.accepted_languages.find {|langcode| langcode =~ language }
		self.log.debug "  find returned: %p" % [ found_language ]
		return found_language && found_language.qvalue.nonzero?
	end
	alias_method :accept_language?, :accepts_language?


	### Returns boolean true/false if the requestor can handle the given
	### +language+, not including the wildcard language if present.
	def explicitly_accepts_language?( language )
		non_wildcard_languages = self.accepted_languages.reject {|enc| enc.content_coding.nil? }
		found_language = non_wildcard_languages.find {|enc| enc =~ language }
		return found_language.qvalue.nonzero?
	end
	alias_method :explicitly_accept_language?, :explicitly_accepts_language?


	### Parse the receiver's 'Accept-Language' header and return it as an Array of
	### Strelka::HTTPRequest::Language objects.
	def parse_accept_language_header
		return self.parse_negotiation_header( :accept_language, Strelka::HTTPRequest::Language ) do
			Strelka::HTTPRequest::Language.new( '*' )
		end
	end


end # module RequestMethods


