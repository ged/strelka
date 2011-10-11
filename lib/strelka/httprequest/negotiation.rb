#!/usr/bin/env ruby

require 'strelka/httprequest'
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

	### Extension callback -- add instance variables to extended objects. 
	def self::extended( mod )
		mod.instance_variable_set( :@accepted_mediatypes, nil )
		mod.instance_variable_set( :@accepted_charsets, nil )
		mod.instance_variable_set( :@accepted_encodings, nil )
		mod.instance_variable_set( :@accepted_languages, nil )
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
		return self.accepted_types.find {|type| type =~ content_type } ? true : false
	end
	alias_method :accept?, :accepts?


	### Returns boolean true/false if the requestor can handle the given
	### +content_type+, not including mime wildcards.
	def explicitly_accepts?( content_type )
		non_wildcard_types = self.accepted_types.reject {|param| param.subtype.nil? }
		self.log.debug "Non-wildcard types: %p" % [ non_wildcard_types ]
		return non_wildcard_types.find {|type| type =~ content_type } ? true : false
	end
	alias_method :explicitly_accept?, :explicitly_accepts?


	### Parse the receiver's 'Accept' header and return it as an Array of
	### Strelka::HTTPRequest::MediaType objects.
	def parse_accept_header
		rval = []
		header = self.headers.accept

		# Handle the case where there's more than one 'Accept:' header by
		# forcing everything to an Array
		Array( header ).compact.flatten.each do |headerval|
			headerval.split( /\s*,\s*/ ).each do |param|
				rval << Strelka::HTTPRequest::MediaType.parse( param )
			end
		end

		rval << Strelka::HTTPRequest::MediaType.new( '*', '*' ) if rval.empty?
		return rval
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
		return self.accepted_charsets.find {|cs| cs =~ charset } ? true : false
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
		rval = []
		header = self.headers.accept_charset

		# Handle the case where there's more than one 'Accept-Charset:' header by
		# forcing everything to an Array
		Array( header ).compact.flatten.each do |headerval|
			headerval.split( /\s*,\s*/ ).each do |param|
				rval << Strelka::HTTPRequest::Charset.parse( param )
			end
		end

		rval << Strelka::HTTPRequest::Charset.new( '*' ) if rval.empty?
		return rval
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
		return true if self.accepted_encodings.empty?
		found_encoding = self.accepted_encodings.find {|enc| enc =~ encoding }

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
		rval = []
		header = self.headers.accept_encoding

		# Handle the case where there's more than one 'Accept-Encoding:' header by
		# forcing everything to an Array
		Array( header ).compact.flatten.each do |headerval|
			headerval.split( /\s*,\s*/ ).each do |param|
				rval << Strelka::HTTPRequest::Encoding.parse( param )
			end
		end

		if rval.empty?
			if self.headers.include?( :accept_encoding )
				rval << Strelka::HTTPRequest::Encoding.new( 'identity' )
			else
				rval << Strelka::HTTPRequest::Encoding.new( '*' )
			end
		end

		return rval
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
		found_language = self.accepted_languages.find {|enc| enc =~ language } or
			return false
		return found_language.qvalue.nonzero?
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
		rval = []
		header = self.headers.accept_language

		# Handle the case where there's more than one 'Accept-Language:' header by
		# forcing everything to an Array
		Array( header ).compact.flatten.each do |headerval|
			headerval.split( /\s*,\s*/ ).each do |param|
				rval << Strelka::HTTPRequest::Language.parse( param )
			end
		end

		rval << Strelka::HTTPRequest::Language.new( '*' ) if rval.empty?
		return rval
	end


end # module RequestMethods


