# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require 'yajl'
require 'safe_yaml'
require 'uri'
require 'loggability'

require 'mongrel2/httprequest'
require 'strelka' unless defined?( Strelka )
require 'strelka/httpresponse'
require 'strelka/cookieset'
require 'strelka/mixins'
require 'strelka/multipartparser'

# An HTTP request class.
class Strelka::HTTPRequest < Mongrel2::HTTPRequest
	extend Loggability
	include Strelka::Constants,
	        Strelka::ResponseHelpers,
	        Strelka::DataUtilities

	# Loggability API -- set up logging under the 'strelka' log host
	log_to :strelka

	# Set Mongrel2 to use Strelka's request class for HTTP requests
	register_request_type( self, *HTTP::RFC2616_VERBS )


	### Override the type of response returned by this request type.
	def self::response_class
		return Strelka::HTTPResponse
	end


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Initialize some additional stuff for Strelka requests.
	def initialize( * ) # :notnew:
		super
		@uri     = nil
		@verb    = self.headers[:method].to_sym
		@params  = nil
		@notes   = Hash.new {|h,k| h[k] = {} }
		@cookies = nil
	end


	######
	public
	######

	# The HTTP verb of the request (as a Symbol)
	attr_accessor :verb

	# The parameters hash parsed from the request
	attr_writer :params

	# A Hash that plugins can use to pass data amongst themselves. The missing-key
	# callback is set to auto-create nested sub-hashes. If you create an HTTPResponse
	# via #response, the response's notes will be shared with its request.
	attr_reader :notes


	### Return a URI object parsed from the URI of the request.
	###
	###   # "GET /user/1/profile HTTP/1.1"
	###   request.uri
	###   # => #<URI::HTTP:0x007fe34d16b2e0 URL:http://localhost:8080/user/1/profile>
	def uri
		unless @uri
			uri = "%s://%s%s" % [
				self.scheme,
				self.headers.host,
				self.headers.uri
			]
			@uri = URI( uri )
		end

		return @uri
	end


	### Return a URI object for the base of the app being run. This is the #uri with the
	### #app_path and any query string removed.
	###
	###   # For a handler with a route of '/user', for the request:
	###   # "GET /user/1/profile HTTP/1.1"
	###   request.base_uri
	###   # => #<URI::HTTP:0x007fe34d16b2e0 URL:http://localhost:8080/user>
	def base_uri
		rval = self.uri
		rval.path = self.headers.pattern
		rval.query = nil
		return rval
	end


	### Return the unescaped portion of the Request's path that was routed by Mongrel2. This and the
	### #app_path make up the #path.
	###
	###   # For a handler with a route of '/user', for the request:
	###   # "GET /user/1/profile HTTP/1.1"
	###   request.route
	###   # => "/user"
	def route
		return URI.unescape( self.headers.pattern )
	end
	alias_method :pattern, :route


	### Return the unescaped portion of the Request's path relative to the request's #route.
	###
	###   # For a handler with a route of '/user', for the request:
	###   # "GET /user/1/profile HTTP/1.1"
	###   request.app_path
	###   # => "/1/profile"
	def app_path
		rval = URI.unescape( self.uri.path )
		rval.slice!( 0, self.route.bytesize )
		return rval
	end


	### Parse the request parameters and return them as a Hash. For GET requests, these are
	### taken from the query arguments.  For requests that commonly
	### contain an entity-body, this method will attempt to parse that.
	###
	###   # For a handler with a route of '/user', for the request:
	###   # "GET /user/1/profile?checkbox=1&checkbox=2&text=foo HTTP/1.1"
	###   # r.params
	###   # => {"checkbox"=>["1", "2"], "text"=>"foo"}
	###
	### If the request body is not a Hash, an empty Hash with the body's value as the default
	### value will be returned instead.
	def params
		unless @params
			value = nil

			case self.verb
			when :GET, :HEAD
				value = decode_www_form( self.uri.query )
			when :POST, :PUT
				value = self.parse_body
			when :TRACE
				self.log.debug "No parameters for a TRACE request."
			else
				value = self.parse_body if self.content_type
			end

			value = Hash.new( value ) unless value.is_a?( Hash )
			@params = value
		end

		return @params
	rescue => err
		self.log.error "%p while parsing the request body: %s" % [ err.class, err.message ]
		self.log.debug "  %s" % [ err.backtrace.join("\n  ") ]

		finish_with( HTTP::BAD_REQUEST, "Malformed request body or missing content type." )
	end


	# multipart/form-data: http://tools.ietf.org/html/rfc2388
	# Content-disposition header: http://tools.ietf.org/html/rfc2183

	### Parse the request body if it's a representation of a complex data
	### structure.
	def parse_body
		mimetype = self.content_type or
			raise ArgumentError, "Malformed request (no content type?)"

		self.body.rewind

		case mimetype.split( ';' ).first
		when 'application/x-www-form-urlencoded'
			return decode_www_form( self.body.read )
		when 'application/json', 'text/javascript'
			return Yajl.load( self.body )
		when 'text/x-yaml', 'application/x-yaml'
			return nil if self.body.eof?
			return YAML.load( self.body, safe: true )
		when 'multipart/form-data'
			boundary = self.content_type[ /\bboundary=(\S+)/, 1 ] or
				raise Strelka::ParseError, "no boundary found for form data: %p" %
				[ self.content_type ]
			boundary = dequote( boundary )

			parser = Strelka::MultipartParser.new( self.body, boundary )
			return parser.parse
		else
			self.log.debug "don't know how to parse a %p request" % [ self.content_type ]
			return {}
		end
	end


	### Fetch any cookies that accompanied the request as a Strelka::CookieSet, creating
	### it if necessary.
	def cookies
		@cookies = Strelka::CookieSet.parse( self ) unless @cookies
		return @cookies
	rescue => err
		self.log.error "%p while parsing cookies: %s" % [ err.class, err.message ]
		self.log.debug "  %s" % [ err.backtrace.join("\n  ") ]

		finish_with( HTTP::BAD_REQUEST, "Malformed cookie header." )
	end


	### A convenience method for redirecting a request to another URI.
	def redirect( uri, perm=false )
		code = perm ? HTTP::MOVED_PERMANENTLY : HTTP::MOVED_TEMPORARILY
		finish_with( code, "redirect from #{self.uri.path} to #{uri}", :location => uri )
	end
	alias_method :redirect_to, :redirect


	#######
	private
	#######

	### Return a Hash of parameters decoded from a application/x-www-form-urlencoded
	### +query_string+, combining multiple values for the same key into an Array
	### value in the order they occurred.
	def decode_www_form( query_string )
		return {} if query_string.nil?

		query_args = query_string.split( /[&;]/ ).each_with_object([]) do |pair, accum|
			pair = pair.split( '=', 2 )
			raise "malformed parameter pair %p: no '='" % [ pair ] unless pair.length == 2
			accum << pair.map {|part| URI.decode_www_form_component(part) }
		end

		return merge_query_args( query_args )
	end


	### Strip surrounding double quotes from a copy of the specified string
	### and return it.
	def dequote( string )
		return string[ /^"(?<quoted_string>(?:[^"]+|\\.)*)"/, :quoted_string ] || string.dup
	end


	### Return the given +enum+ containing query arguments (such as those returned from
	### URI.decode_www_form) as a Hash, combining multiple values for the same key
	### into an Array.
	def merge_query_args( enum )
		return enum.inject({}) do |hash,(key,val)|

			# If there's already a value in the Hash, turn it into an array if
			# it's not already, and append the new value
			if hash.key?( key )
				hash[ key ] = [ hash[key] ] unless hash[ key ].is_a?( Array )
				hash[ key ] << val
			else
				hash[ key ] = val
			end

			hash
		end
	end


end # class Strelka::HTTPRequest
