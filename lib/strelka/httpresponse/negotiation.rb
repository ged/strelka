#!usr/bin/env ruby

require 'set'
require 'yaml'
require 'yajl'

require 'strelka/httpresponse'
require 'strelka/exceptions'


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

	# TODO: Perhaps replace this with something like this:
	#   Mongrel2::Config::Mimetype.to_hash( :extension => :mimetype )
	BUILTIN_MIMETYPES = {
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

	# A collection of stringifier callbacks, keyed by mimetype. If an object other
	# than a String is returned by a content callback, and an entry for the callback's
	# mimetype exists in this Hash, it will be #call()ed to stringify the object.
	STRINGIFIERS = Hash.new( Object.method(:String) )
	STRINGIFIERS[ 'application/x-yaml' ] = YAML.method( :dump )
	STRINGIFIERS[ 'application/json'   ] = Yajl.method( :dump )


	### Add some instance variables for negotiation.
	def initialize( * )
		@mediatype_callbacks = {}
		@language_callbacks  = {}
		@vary_fields         = Set.new

		super
	end


	######
	public
	######

	# The Hash of mediatype alternative callbacks for content negotiation, keyed by mimetype.
	attr_reader :mediatype_callbacks

	# A Set of header fields to add to the 'Vary:' response header.
	attr_reader :vary_fields


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


	#
	# :section: Content-alternative Callbacks
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
			mimetype = BUILTIN_MIMETYPES[ mimetype ] if mimetype.is_a?( Symbol )
			self.mediatype_callbacks[ mimetype ] = callback
		end

		# Include the 'Accept:' header in the 'Vary:' header
		self.vary_fields.add( 'accept' )
	end


	### Overridden to call one of the content-alternative callbacks if the response isn't
	### acceptable.
	def body
		unless self.acceptable?
			self.log.debug "Response is not acceptable as-is; looking for alternatives"
			self.transform_content_type unless self.acceptable_content_type?
			self.transform_language     unless self.acceptable_language?
			self.transform_charset      unless self.acceptable_charset?
			self.transform_encoding     unless self.acceptable_encoding?
		end

		return super
	end


	### Iterate over the originating request's acceptable content types in 
	### qvalue+listed order, looking for a content negotiation callback for
	### each mediatype. If any are found, they are tried in declared order
	### until one returns a true-ish value, which becomes the new entity
	### body. If the body object is not a String, 
	def transform_content_type
		self.log.debug "Trying to transform the entity body to one of the accepted types."
		req = self.request or
			raise Strelka::PluginError, "no originating request object"

		mimetype, new_body = catch( :transformed ) do
			self.request.accepted_mediatypes.sort.each do |acceptparam|
				self.log.debug "  looking for transformations for %p" % [ acceptparam.mimetype ]
				callbacks = self.mediatype_callbacks.find_all do |mimetype, callback|
					acceptparam =~ mimetype
				end

				self.log.debug "    found %d callback/s to try" % [ callbacks.length ]
				callbacks.each do |mimetype, callback|
					self.log.debug "    trying: %p" % [ callback ]
					rval = callback.call( mimetype )
					throw :transformed, [mimetype, rval] if rval
				end
			end

			nil # No transforms succeeded
		end

		if new_body
			self.log.debug "Successfully transformed. Setting up response."
			new_body = STRINGIFIERS[ mimetype ].call( new_body ) unless new_body.is_a?( String )

			self.body = new_body
			self.content_type = mimetype
			self.status = HTTP::OK
		end
	end


	### Iterate over the originating request's acceptable languages in 
	### qvalue+listed order, looking for a content negotiation callback for
	### each language. If any are found, they are tried in declared order
	### until one returns a true-ish value, which becomes the new entity
	### body.
	def transform_language; end


	### Iterate over the originating request's acceptable charsets in 
	### qvalue+listed order, attempting to transcode the current entity body
	### if it
	def transform_charset
		self.log.debug "Trying to transcode the entity body to one of the accepted charsets."

		# Access the instance variable directly, since #body checks for acceptability
		if @body.respond_to?( :encode )
			self.log.debug "  body is a string; trying direct transcoding"
			if self.transcode_body_string( self.request.accepted_charsets )
				self.vary_fields.add( 'accept-charset' )
			end

		# Can change the external_encoding if it's a File that has a #path
		elsif @body.respond_to?( :external_encoding )
			raise NotImplementedError,
				"Support for transcoding %p objects isn't done." % [ @body.class ]
		else
			self.log.warn "Don't know how to transcode a %p" % [ @body.class ]
		end
	end


	### Try to transcode the entity body String to one of the specified +charsets+. Returns
	### the succesful Encoding object if transcoding succeeded, or +nil+ if transcoding
	### failed.
	def transcode_body_string( charsets )
		charsets.each do |charset|
			self.log.debug "    attempting to transcode to: %s" % [ charset.name ]
			unless enc = charset.encoding_object
				self.log.warn "    unsupported charset: %s" % [ charset ]
				next
			end

			succeeded = false
			begin
				succeeded = @body.encode!( enc )
			rescue Encoding::UndefinedConversionError => err
				self.log.error "%p while transcoding: %s" % [ err.class, err.message ]
			end

			if succeeded
				self.log.debug "  success; body is now %p" % [ @body.encoding ]
				return @body.encoding
			end
		end

		return nil
	end


	### Iterate over the originating request's acceptable content types in 
	### qvalue+listed order, looking for a content negotiation callback for
	### each mediatype. If any are found, they are tried in declared order
	### until one returns a true-ish value, which becomes the new entity
	### body.
	def transform_encoding; end


	#
	# :section: Acceptance Predicates
	#

	### Return true if the receiver satisfies all of its originating request's
	### Accept* headers, or it has no originating request.
	def acceptable?
		return true if self.handled? or !self.request

		return self.acceptable_content_type? &&
		       self.acceptable_charset? &&
		       self.acceptable_language? &&
		       self.acceptable_encoding?
	end
	alias_method :is_acceptable?, :acceptable?


	### Returns true if the content-type of the response is set to a
	### mediatype that was designated as acceptable by the originating
	### request, or if there was no originating request.
	def acceptable_content_type?
		req = self.request or return true
		return req.accepts?( self.content_type )
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

		return req.accepts_charset?( charset )
	end
	alias_method :has_acceptable_charset?, :acceptable_charset?


	### Returns true if at least one of the receiver's #languages is set
	### to a value that was designated as acceptable by the originating
	### request, if there was no originating request, or if no #languages
	### have been set.
	def acceptable_language?
		req = self.request or return true
		return true if self.languages.empty?

		# :FIXME: I'm not sure this is how this should work. RFC2616 is somewhat
		# vague about how the Language: tag with multiple values interacts with
		# an Accept-Language: specification.
		# If it should require that *all* languages be in the accept list,
		# just change .any? to .all?
		return self.languages.any? {|lang| req.accepts_language?(lang) }
	end
	alias_method :has_acceptable_language?, :acceptable_language?


	### Returns true if all of the receiver's #encodings were designated 
	### as acceptable by the originating request, if there was no originating
	### request, or if no #encodings have been set.
	def acceptable_encoding?
		req = self.request or return true

		encs = self.encodings.dup
		encs << 'identity' if encs.empty?

		return encs.all? {|enc| req.accepts_encoding?(enc) }
	end
	alias_method :has_acceptable_encoding?, :acceptable_encoding?

end # module Strelka::HTTPResponse::Negotiation

