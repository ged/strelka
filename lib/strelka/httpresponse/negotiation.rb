# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require 'set'
require 'yaml'
require 'yajl'

require 'strelka/constants'
require 'strelka/exceptions'
require 'strelka/mixins'
require 'strelka/httpresponse' unless defined?( Strelka::HTTPResponse )


# The mixin that adds methods to Strelka::HTTPResponse for content-negotiation.
#
#    response = request.response
#    response.for( 'text/html' ) {...}
#    response.for( :json ) {...}
#    response.for_encoding( :en ) {...}
#    response.for_language( :en ) {...}
#
# If the response was created from a request, it also knows whether or not it
# is acceptable according to its request's `Accept*` headers.
#
module Strelka::HTTPResponse::Negotiation
	extend Strelka::MethodUtilities
	include Strelka::Constants

	# TODO: Perhaps replace this with something like this:
	#   Mongrel2::Config::Mimetype.to_hash( :extension => :mimetype )
	BUILTIN_MIMETYPE_MAP = {
		:html => 'text/html',
		:text => 'text/plain',

		:yaml => 'application/x-yaml',
		:json => 'application/json',

		:jpeg => 'image/jpeg',
		:png  => 'image/png',
		:gif  => 'image/gif',

		:rdf  => 'application/rdf+xml',
		:rss  => 'application/rss+xml',
		:atom => 'application/atom+xml',
	}

	# A collection of default stringifier callbacks, keyed by mimetype. If an entry
	# for the content-negotiation callback's mimetype exists in this Hash, it will
	# be #call()ed on the callback's return value to stringify the body.
	BUILTIN_STRINGIFIERS = {
		'application/x-yaml' => YAML.method( :dump ),
		'application/json'   => Yajl.method( :dump ),
		'text/plain'         => Proc.new {|obj| obj.to_s },
	}

	# Transcoding to Unicode is likely enough to work to warrant auto-transcoding. These
	# are the charsets that will be used for auto-transcoding in the case where the whole
	# entity body isn't in memory
	UNICODE_CHARSETS = [
		Encoding::UTF_8,
		Encoding::UTF_16BE,
		Encoding::UTF_32BE,
	]


	##
	# The Hash of symbolic mediatypes of the form:
	#   { <name (Symbol)> => <mimetype> }
	singleton_attr_reader :mimetype_map
	@mimetype_map = BUILTIN_MIMETYPE_MAP.dup

	##
	# The Hash of stringification callbacks, keyed by mimetype.
	singleton_attr_reader :stringifiers
	@stringifiers = BUILTIN_STRINGIFIERS.dup


	### Add some instance variables for negotiation.
	def initialize( * )
		@mediatype_callbacks = {}
		@language_callbacks  = {}
		@encoding_callbacks  = {}

		@vary_fields         = Set.new

		super
	end


	######
	public
	######

	# The Hash of mediatype alternative callbacks for content negotiation,
	# keyed by mimetype.
	attr_reader :mediatype_callbacks

	# The Hash of language alternative callbacks for content negotiation,
	# keyed by language tag String.
	attr_reader :language_callbacks

	# The Hash of document coding alternative callbacks for content
	# negotiation, keyed by coding name.
	attr_reader :encoding_callbacks

	# A Set of header fields to add to the 'Vary:' response header.
	attr_reader :vary_fields


	### Overridden to reset content-negotiation callbacks, too.
	def reset
		super

		@mediatype_callbacks.clear
		@language_callbacks.clear
		@encoding_callbacks.clear

		# Not clearing the Vary: header for now, as it's useful in a 406 to
		# determine what accept-* headers can be modified to get an acceptable
		# response
		# @vary_fields.clear
	end


	### Overridden to add a Vary: header to outgoing headers if the response has
	### any #vary_fields.
	def normalized_headers
		headers = super

		unless self.vary_fields.empty?
			self.log.debug "Adding Vary header for %p" % [ self.vary_fields ]
			headers.vary = self.vary_fields.to_a.join( ', ' )
		end

		return headers
	end


	### Stringify the response -- overridden to use the negotiated body.
	def to_s
		self.negotiate
		super
	end


	### Transform the entity body if it doesn't meet the criteria
	def negotiated_body
		self.negotiate
		return self.body
	end


	### Check for any negotiation that should happen and apply the necessary
	### transforms if they're available.
	def negotiate
		return if !self.request
		self.transform_content_type
		self.transform_language
		self.transform_charset
		self.transform_encoding
	end


	#
	# :section: Acceptance Predicates
	#

	### Return true if the receiver satisfies all of its originating request's
	### Accept* headers, or it's a bodiless response.
	def acceptable?
		# self.negotiate
		return self.bodiless? ||
		       ( self.acceptable_content_type? &&
		         self.acceptable_charset? &&
		         self.acceptable_language? &&
		         self.acceptable_encoding? )
	end
	alias_method :is_acceptable?, :acceptable?


	### Returns true if the content-type of the response is set to a
	### mediatype that was designated as acceptable by the originating
	### request, or if there was no originating request.
	def acceptable_content_type?
		req = self.request or return true
		answer = req.accepts?( self.content_type )
		self.log.warn "Content-type %p NOT acceptable: %p" %
			[ self.content_type, req.accepted_mediatypes ] unless answer

		return answer
	end
	alias_method :has_acceptable_content_type?, :acceptable_content_type?


	### Returns true if the receiver's #charset is set to a value that was
	### designated as acceptable by the originating request, or if there
	### was no originating request.
	def acceptable_charset?
		req = self.request or return true
		charset = self.find_header_charset

		# Types other than text are binary, and so aren't subject to charset
		# acceptability.
		# For 'text/' subtypes:
		#   When no explicit charset parameter is provided by the sender, media
		#   subtypes of the "text" type are defined to have a default charset
		#   value of "ISO-8859-1" when received via HTTP. [RFC2616 3.7.1]
		if charset == Encoding::ASCII_8BIT
			return true unless self.content_type.start_with?( 'text/' )
			charset = Encoding::ISO8859_1
		end

		answer = req.accepts_charset?( charset )
		self.log.warn "Content-charset %p NOT acceptable: %p" %
			[ self.find_header_charset, req.accepted_charsets ] unless answer

		return answer
	end
	alias_method :has_acceptable_charset?, :acceptable_charset?


	### Returns true if at least one of the receiver's #languages is set
	### to a value that was designated as acceptable by the originating
	### request, if there was no originating request, or if no #languages
	### have been set for a non-empty entity body.
	def acceptable_language?
		req = self.request or return true

		# Lack of an accept-language field means all languages are accepted
		return true if req.accepted_languages.empty?

		# If no language is given for an existing entity body, there's no way
		# to know whether or not there's a better alternative
		return true if self.languages.empty?

		# If any of the languages present for the body are accepted, the
		# request is acceptable. Or at least that's what I got out of
		# reading RFC2616, Section 14.4.
		answer = self.languages.any? {|lang| req.accepts_language?(lang) }
		self.log.warn "Content-language %p NOT acceptable: %s" %
			[ self.languages, req.accepted_languages ] unless answer

		return answer
	end
	alias_method :has_acceptable_language?, :acceptable_language?


	### Returns true if all of the receiver's #encodings were designated
	### as acceptable by the originating request, if there was no originating
	### request, or if no #encodings have been set.
	def acceptable_encoding?
		req = self.request or return true

		encs = self.encodings.dup
		encs << 'identity' if encs.empty?

		answer = encs.all? {|enc| req.accepts_encoding?(enc) }
		self.log.warn "Content-encoding %p NOT acceptable: %s" %
			[ encs, req.accepted_encodings ] unless answer

		return answer
	end
	alias_method :has_acceptable_encoding?, :acceptable_encoding?


	#
	# :section: Content-type Callbacks
	#

	### Register a callback that will be called during transparent content
	### negotiation for the entity body if one or more of the specified
	### +mediatypes+ is among the requested alternatives. The +mediatypes+
	### can be either mimetype Strings or Symbols that correspond to keys
	### in the BUILTIN_MIMETYPES hash. The +callback+ will be called with
	### the desired mimetype, and should return the new value for the entity
	### body if it successfully transformed the body, or a false value if
	### the next alternative should be tried instead.
	### If successful, the response's body will be set to the new value,
	### its content_type set to the new mimetype, and its status changed
	### to HTTP::OK.
	def for( *mediatypes, &callback )
		mediatypes.each do |mimetype|
			if mimetype.is_a?( Symbol )
				mimetype = Strelka::HTTPResponse::Negotiation.mimetype_map[ mimetype ] or
					raise "No known mimetype mapped to %p" % [ mimetype ]
			end

			self.mediatype_callbacks[ mimetype ] = callback
		end

		# Include the 'Accept:' header in the 'Vary:' header
		self.vary_fields.add( 'accept' )
	end


	### Returns Strelka::HTTPRequest::MediaType objects for mediatypes that have
	### a higher qvalue than the current response's entity body (if any).
	def better_mediatypes
		req = self.request or return []
		return [] unless req.headers.accept

		current_qvalue = 0.0
		mediatypes = req.accepted_mediatypes.sort

		# If the current mediatype exists in the Accept: header, reset the current qvalue
		# to whatever its qvalue is
		if self.content_type
			mediatype = mediatypes.find {|mt| mt =~ self.content_type }
			current_qvalue = mediatype.qvalue if mediatype
		end

		self.log.debug "Looking for better mediatypes than %p (%0.2f)" %
			[ self.content_type, current_qvalue ]

		return mediatypes.find_all do |mt|
			mt.qvalue > current_qvalue
		end
	end


	### Iterate over the originating request's acceptable content types in
	### qvalue+listed order, looking for a content negotiation callback for
	### each mediatype. If any are found, they are tried in declared order
	### until one returns a true-ish value, which becomes the new entity
	### body. If the body object is not a String,
	def transform_content_type
		self.log.debug "Applying content-type transforms (if any)"
		return if self.mediatype_callbacks.empty?

		self.log.debug "  transform callbacks registered: %p" % [ self.mediatype_callbacks ]
		self.better_mediatypes.each do |mediatype|
			callbacks = self.mediatype_callbacks.find_all do |mimetype, _|
				mediatype =~ mimetype
			end

			if callbacks.empty?
				self.log.debug "    no transforms for %s" % [ mediatype ]
			else
				self.log.debug "    %d transform/s for %s" % [ callbacks.length, mediatype ]
				callbacks.each do |mimetype, callback|
					return if self.try_content_type_callback( mimetype, callback )
				end
			end
		end
	end


	### Attempt to apply the +callback+ for the specified +mediatype+ to the entity
	### body, making the necessary changes to the request and returning +true+ if
	### the callback returns a new entity body, or returning a false value if it doesn't.
	def try_content_type_callback( mimetype, callback )
		self.log.debug "  trying content-type callback %p (%s)" % [ callback, mimetype ]

		new_body = callback.call( mimetype ) or return false

		self.log.debug "  successfully transformed: %p! Setting up response." % [ new_body.class ]
		stringifiers = Strelka::HTTPResponse::Negotiation.stringifiers
		if stringifiers.key?( mimetype )
			new_body = stringifiers[ mimetype ].call( new_body )
		else
			self.log.debug "    no stringifier registered for %p" % [ mimetype ]
		end

		self.body = new_body
		self.content_type = mimetype.dup # :TODO: Why is this frozen?
		self.status ||= HTTP::OK

		return true
	end


	#
	# :section: Language negotiation callbacks
	#

	### Register a callback that will be called during transparent content
	### negotiation for the entity body if one or more of the specified
	### +language_tags+ is among the requested alternatives. The +language_tags+
	### are Strings in the form described by RFC2616, section 3.10. The
	### +callback+ will be called with the desired language code, and should
	### return the new value for the entity body if it has value for the
	### body, or a false value if the next alternative should be tried
	### instead.  If successful, the response's body will be set to the new
	### value, and its status changed to HTTP::OK.
	def for_language( *language_tags, &callback )
		language_tags.flatten.each do |lang|
			self.language_callbacks[ lang.to_sym ] = callback
		end

		# Include the 'Accept-Language:' header in the 'Vary:' header
		self.vary_fields.add( 'accept-language' )
	end


	### Returns Strelka::HTTPRequest::Language objects for natural languages that have
	### a higher qvalue than the current response's entity body (if any).
	def better_languages
		req = self.request or return []

		current_qvalue = 0.0
		accepted_languages = req.accepted_languages.sort

		# If any of the current languages exists in the Accept-Language: header, reset
		# the current qvalue to the highest one among them
		unless self.languages.empty?
			current_qvalue = self.languages.reduce( current_qvalue ) do |qval, lang|
				accepted_lang = accepted_languages.find {|alang| alang =~ lang } or
					next qval
				qval > accepted_lang.qvalue ? qval : accepted_lang.qvalue
			end
		end

		self.log.debug "Looking for better languages than %p (%0.2f)" %
			[ self.languages.join(', '), current_qvalue ]

		return accepted_languages.find_all do |lang|
			lang.qvalue > current_qvalue
		end
	end


	### If there are any languages that have a higher qvalue than the one/s in #languages,
	### look for a negotiation callback that provides that language. If any are found, they
	### are tried in declared order until one returns a true-ish value, which becomes the new
	### entity body.
	def transform_language
		return if self.language_callbacks.empty?

		self.log.debug "Looking for language transformations"
		self.better_languages.uniq.each do |lang|
			callback = langcode = nil

			if lang.primary_tag
				langcode = lang.language_range
				callback = self.language_callbacks[ lang.primary_tag.to_sym ]
			else
				langcode, callback = self.language_callbacks.first
			end

			next unless callback

			self.log.debug "  found a callback for %s: %p" % [ langcode, callback ]
			if (( new_body = callback.call(langcode) ))
				self.body = new_body
				self.languages.replace([ langcode.to_s ])
				self.log.debug "    success."
				break
			end

		end
	end


	#
	# :section: Charset negotiation callbacks
	#

	### Returns Strelka::HTTPRequest::Charset objects for accepted character sets that have
	### a higher qvalue than the one used by the current response.
	def better_charsets
		req = self.request or return []
		return [] unless self.content_type &&
			self.content_type.start_with?( 'text/', 'application/' )
		return [] unless req.headers.accept_charset

		current_qvalue = 0.0
		charsets = req.accepted_charsets.sort
		current_charset = self.find_header_charset

		# If the current charset exists in the Accept-Charset: header, reset the current qvalue
		# to whatever its qvalue is
		if current_charset != Encoding::ASCII_8BIT
			charset = charsets.find {|mt| mt =~ current_charset }
			current_qvalue = charset.qvalue if charset
		end

		self.log.debug "Looking for better charsets than %p (%0.2f)" %
			[ current_charset, current_qvalue ]

		return charsets.sort.find_all do |cs|
			cs.qvalue > current_qvalue
		end
	end


	### Iterate over the originating request's acceptable charsets in
	### qvalue+listed order, attempting to transcode the current entity body
	### if it
	def transform_charset
		self.log.debug "Looking for charset transformations."
		if self.body.respond_to?( :string ) || self.body.respond_to?( :fileno )

			# Try each charset that's better than what we have already
			self.better_charsets.each do |charset|
				self.log.debug "  trying to transcode to: %s" % [ charset ]

				# If it succeeds, indicate that transcoding took place in the Vary header
				if self.transcode_body( charset )
					self.log.debug "  success; body is now %p" % [ charset ]
					self.vary_fields.add( 'accept-charset' )
					break
				end
			end
		else
			self.log.warn "Don't know how to transcode a %p" % [ self.body.class ]
		end
	end


	### Try to transcode the entity body stream to one of the specified +charsets+. Returns
	### the succesful Encoding object if transcoding succeeded, or +nil+ if transcoding
	### failed.
	def transcode_body( charset )
		unless enc = charset.encoding_object
			self.log.warn "    unsupported charset: %s" % [ charset ]
			return false
		end

		begin

			# StringIOs get their internal string transcoded directly
			if self.body.respond_to?( :string )
				self.body.string.encode!( enc )
				return true

			# For other IO objects, the situation is trickier -- we can't know that
			# encoding will succeed for more-restrictive charsets, so we only do
			# automatic transcoding if the 'wanted' one is a Unicode charset.
			# This probably isn't perfect, either.
			# :FIXME: Probably need a list of exceptions, i.e., charsets that don't
			# always transcode nicely into Unicode.
			elsif self.body.respond_to?( :fileno ) && UNICODE_CHARSETS.include?( enc )
				self.log.info "Assuming %s data can be transcoded into %s" %
					[ self.body.internal_encoding, enc ]

				# Don't close the FD when this IO goes out of scope
				oldbody = self.body
				oldbody.autoclose = false

				# Re-open the same file descriptor, but transcoding to the wanted encoding
				self.body = IO.for_fd( oldbody.fileno, internal_encoding: enc )
				return true
			end

		rescue Encoding::UndefinedConversionError => err
			self.log.error "%p while transcoding: %s" % [ err.class, err.message ]
		end

		return false
	end


	#
	# :section: Content-coding negotiation callbacks
	#

	### Register a callback that will be called during transparent content
	### negotiation for the entity body if one or more of the specified
	### +codings+ is among the requested alternatives. The +codings+
	### are Strings in the form described by RFC2616, section 3.5. The
	### +callback+ will be called with the coding name, and should
	### return the new value for the entity body if it has transformed the
	### bod.  If successful, the response's body will be set to the new
	### value, and the coding name added to the appropriate headers.
	def for_encoding( *codings, &callback )
		codings.each do |coding|
			self.encoding_callbacks[ coding ] = callback
		end

		# Include the 'Accept-Encoding:' header in the 'Vary:' header
		self.vary_fields.add( 'accept-encoding' )
	end


	### Returns Strelka::HTTPRequest::Encoding objects for accepted encodings that have
	### a higher qvalue than the one used by the current response.
	def better_encoding
		req = self.request or return []
		return [] unless req.headers.accept_encoding

		current_qvalue = 0.0
		encodings = req.accepted_encodings.sort
		current_encodings = self.encodings.dup
		current_encodings.unshift( 'identity' )

		# Find the highest qvalue of the encodings that have been applied already
		current_qvalue = current_encodings.inject( current_qvalue ) do |qval, current_enc|
			qenc = encodings.find {|enc| enc =~ current_enc } or next qval
			qenc.qvalue > qval ? qenc.qvalue : qval
		end

		self.log.debug "Looking for better encodings than %p (%0.2f)" %
			[ current_encodings, current_qvalue ]

		return encodings.find_all do |enc|
			self.log.debug "  %s (%0.2f) > %0.2f?" % [ enc, enc.qvalue, current_qvalue ]
			enc.qvalue > current_qvalue
		end
	end


	### Iterate over the originating request's acceptable encodings and apply
	### each one in the order they were requested if they're available.
	def transform_encoding
		return if self.encoding_callbacks.empty?

		self.log.debug "Looking for acceptable content codings"
		self.better_encoding.each do |enc|
			self.log.debug "  looking for a callback for %p" % [ enc ]

			if (( callback = self.encoding_callbacks[enc.content_coding.to_sym] ))
				self.log.debug "  trying callback %p for %p" %
					[ callback, enc ]
				if (( new_body = callback.call(enc.content_coding) ))
					self.log.debug "    callback succeeded"
					self.body = new_body
					self.encodings << enc.content_coding
					break
				end
			elsif enc.content_coding == 'identity' && enc.qvalue.nonzero?
				self.log.debug "  identity coding, no callback"
				break
			end
		end
	end


end # module Strelka::HTTPResponse::Negotiation

