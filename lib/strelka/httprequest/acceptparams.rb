# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require 'loggability'
require 'strelka/mixins'
require 'strelka/httprequest'

class Strelka::HTTPRequest

	# A parser for request Accept[rdoc-ref:Strelka::HTTPRequest::MediaType] ,
	# {Accept-encoding}[rdoc-ref:Strelka::HTTPRequest::Encoding] ,
	# {Accept-charset}[rdoc-ref:Strelka::HTTPRequest::Charset] , and
	# {Accept-language}[rdoc-ref:Strelka::HTTPRequest::Language]
	# header values. They provide weighted and wildcard comparisions between two values
	# of the same field.
	#
	#   require 'strelka/httprequest/acceptparam'
	#   mediatype = Strelka::HTTPRequest::AcceptParam.parse_mediatype( "text/html;q=0.9;level=2" )
	#
	#   ap.type         #=> 'text'
	#   ap.subtype      #=> 'html'
	#   ap.qvalue       #=> 0.9
	#   ap =~ 'text/*'  #=> true
	#
	#   language = Strelka::HTTPRequest::AcceptParam.parse_language( "en-gb" )
	#
	#   ap.type         #=> :en
	#   ap.subtype      #=> :gb
	#   ap.qvalue       #=> 1.0
	#   ap =~ 'en'      #=> true
	#
	#   encoding = Strelka::HTTPRequest::AcceptParam.parse_encoding( "compress; q=0.7" )
	#
	#   ap.type          #=> :compress
	#   ap.subtype       #=> nil
	#   ap.qvalue        #=> 0.7
	#   ap =~ 'compress' #=> true
	#
	#   charset = Strelka::HTTPRequest::AcceptParam.parse_charset( "koi8-r" )
	#
	#   ap.type          #=> 'koi8-r'
	#   ap.subtype       #=> nil
	#   ap.qvalue        #=> 1.0
	#   ap =~ 'koi8-r'   #=> true
	#
	# == Authors
	#
	# * Michael Granger <ged@FaerieMUD.org>
	# * Mahlon E. Smith <mahlon@martini.nu>
	#
	class AcceptParam
		extend Loggability
		include Comparable,
		        Strelka::AbstractClass


		# Loggability API -- set up logging under the 'strelka' log host
		log_to :strelka


		# The default quality value (weight) if none is specified
		Q_DEFAULT = 1.0

		# The maximum quality value
		Q_MAX = Q_DEFAULT


		#################################################################
		###	I N S T A N C E   M E T H O D S
		#################################################################

		### Create a new Strelka::HTTPRequest::AcceptParam with the given media
		### +range+, quality value (+qval+), and extensions
		def initialize( type, subtype='*', qval=Q_DEFAULT, *extensions )
			type    = nil if type == '*'
			subtype = nil if subtype == '*'

			@type       = type
			@subtype    = subtype
			@qvalue     = normalize_qvalue( qval )
			@extensions = extensions.flatten
		end


		######
		public
		######

		pure_virtual :to_s


		# The 'type' part of the media range
		attr_reader :type

		# The 'subtype' part of the media range
		attr_reader :subtype

		# The weight of the param
		attr_reader :qvalue

		# An array of any accept-extensions specified with the parameter
		attr_reader :extensions


		### Match operator -- returns true if +other+ matches the receiving
		### AcceptParam.
		def =~( other )
			unless other.is_a?( self.class )
				other = self.class.parse( other.to_s ) rescue nil
				return false unless other
			end

			# */* returns true in either side of the comparison.
			# ASSUMPTION: There will never be a case when a type is wildcarded
			#             and the subtype is specific. (e.g., */xml)
			#             We gave up trying to read RFC 2045.
			return true if other.type.nil? || self.type.nil?

			# text/html =~ text/html
			# text/* =~ text/html
			# text/html =~ text/*
			if other.type == self.type
				return true if other.subtype.nil? || self.subtype.nil?
				return true if other.subtype == self.subtype
			end

			return false
		end


		### Return a human-readable version of the object
		def inspect
			return "#<%s:0x%07x '%s/%s' q=%0.3f %p>" % [
				self.class.name,
				self.object_id * 2,
				self.type || '*',
				self.subtype || '*',
				self.qvalue,
				self.extensions,
			]
		end


		### The weighting or "qvalue" of the parameter in the form "q=<value>"
		def qvaluestring
			# 3 digit precision, trim excess zeros
			return sprintf( "q=%0.3f", self.qvalue ).gsub(/0{1,2}$/, '')
		end


		### Return a String containing any extensions for this parameter, joined
		### with ';'
		def extension_strings
			return nil if self.extensions.empty?
			return self.extensions.compact.join('; ')
		end


		### Comparable interface. Sort parameters by weight: Returns -1 if +other+
		### is less specific than the receiver, 0 if +other+ is as specific as
		### the receiver, and +1 if +other+ is more specific than the receiver.
		def <=>( other )

			if rval = (other.qvalue <=> @qvalue).nonzero?
				return rval
			end

			if self.type.nil?
				return 1 if ! other.type.nil?
			elsif other.type.nil?
				return -1
			end

			if self.subtype.nil?
				return 1 if ! other.subtype.nil?
			elsif other.subtype.nil?
				return -1
			end

			if rval = (self.extensions.length <=> other.extensions.length).nonzero?
				return rval
			end

			return self.to_s <=> other.to_s
		end


		#######
		private
		#######

		### Given an input +qvalue+, return the Float equivalent.
		def normalize_qvalue( qvalue )
			return Q_DEFAULT unless qvalue
			qvalue = Float( qvalue.to_s.sub(/q=/, '') ) unless qvalue.is_a?( Float )

			if qvalue > Q_MAX
				self.log.warn "Squishing invalid qvalue %p to %0.1f" %
					[ qvalue, Q_DEFAULT ]
				return Q_DEFAULT
			end

			return qvalue
		end

	end # class AcceptParam


	# A mediatype parameter such as one you'd find in an +Accept+ header.
	class MediaType < Strelka::HTTPRequest::AcceptParam

		### Parse the given +accept_param+ as a mediatype and return a
		### Strelka::HTTPRequest::MediaType object for it.
		def self::parse( accept_param )
			raise ArgumentError, "Bad Accept param: no media-range in %p" % [accept_param] unless
				accept_param.include?( '/' )
			media_range, *stuff = accept_param.split( /\s*;\s*/ )
			type, subtype = media_range.downcase.split( '/', 2 )
			qval, opts = stuff.partition {|par| par =~ /^q\s*=/ }

			return new( type, subtype, qval.first, *opts )
		end


		### The mediatype of the parameter, consisting of the type and subtype
		### separated by '/'.
		def mediatype
			return "%s/%s" % [ self.type || '*', self.subtype || '*' ]
		end
		alias_method :mimetype, :mediatype
		alias_method :content_type, :mediatype


		### Return the parameter as a String suitable for inclusion in an Accept
		### HTTP header
		def to_s
			return [
				self.mediatype,
				self.qvaluestring,
				self.extension_strings
			].compact.join(';')
		end

	end # class MediaType


	# A natural language specification parameter, such as one you'd find in an
	# <tt>Accept-Language</tt> header.
	class Language < Strelka::HTTPRequest::AcceptParam

		### Parse the given +accept_param+ as a language range and return a
		### Strelka::HTTPRequest::Language object for it.
		def self::parse( accept_param )
			language_range, *stuff = accept_param.split( /\s*;\s*/ )
			type, subtype = language_range.downcase.split( '-', 2 )
			qval, opts = stuff.partition {|par| par =~ /^q\s*=/ }

			return new( type, subtype, qval.first, *opts )
		end


		######
		public
		######

		alias_method :primary_tag, :type
		alias_method :subtag, :subtype

		### Return the language range of the parameter as a String.
		def language_range
			return [ self.primary_tag, self.subtag ].compact.join( '-' )
		end

		### Return the parameter as a String suitable for inclusion in an
		### Accept-language header.
		def to_s
			return [
				self.language_range,
				self.qvaluestring,
				self.extension_strings,
			].compact.join( ';' )
		end

	end # class Language


	# A content encoding parameter, such as one you'd find in an <tt>Accept-Encoding</tt> header.
	class Encoding < Strelka::HTTPRequest::AcceptParam

		### Parse the given +accept_param+ as a content coding and return a
		### Strelka::HTTPRequest::Encoding object for it.
		def self::parse( accept_param )
			content_coding, *stuff = accept_param.split( /\s*;\s*/ )
			qval, opts = stuff.partition {|par| par =~ /^q\s*=/ }

			return new( content_coding, nil, qval.first, *opts )
		end


		######
		public
		######

		alias_method :content_coding, :type


		### Return the parameter as a String suitable for inclusion in an
		### Accept-language header.
		def to_s
			return [
				self.content_coding,
				self.qvaluestring,
				self.extension_strings,
			].compact.join( ';' )
		end

	end # class Encoding


	# A content character-set parameter, such as one you'd find in an <tt>Accept-Charset</tt> header.
	class Charset < Strelka::HTTPRequest::AcceptParam

		### Parse the given +accept_param+ as a charset and return a
		### Strelka::HTTPRequest::Charset object for it.
		def self::parse( accept_param )
			charset, *stuff = accept_param.split( /\s*;\s*/ )
			qval, opts = stuff.partition {|par| par =~ /^q\s*=/ }

			return new( charset, nil, qval.first, *opts )
		end


		######
		public
		######

		alias_method :name, :type


		### Return the parameter as a String suitable for inclusion in an
		### Accept-language header.
		def to_s
			return [
				self.name,
				self.qvaluestring,
				self.extension_strings,
			].compact.join( ';' )
		end


		### Return the Ruby Encoding object that is associated with the parameter's charset.
		def encoding_object
			return ::Encoding.find( self.name )
		rescue ArgumentError => err
			self.log.warn( err.message )
			# self.log.debug( err.backtrace.join($/) )
			return nil
		end


		### Match operator -- returns true if +other+ matches the receiving
		### AcceptParam.
		def =~( other )
			unless other.is_a?( self.class )
				other = self.class.parse( other.to_s ) rescue nil
				return false unless other
			end

			# The special value "*", if present in the Accept-Charset field,
			# matches every character set (including ISO-8859-1) which is not
			# mentioned elsewhere in the Accept-Charset field.
			return true if other.name.nil? || self.name.nil?

			# Same downcased names or different names for the same encoding should match
			return true if other.name.downcase == self.name.downcase ||
			               other.encoding_object == self.encoding_object

			return false
		end

	end # class Charset


end # class Strelka::HTTPRequest

# vim: set nosta noet ts=4 sw=4:
