#!/usr/bin/env ruby

require 'yajl'
require 'yaml'
require 'uri'

require 'mongrel2/httprequest'
require 'strelka' unless defined?( Strelka )
require 'strelka/httpresponse'

# An HTTP request class.
class Strelka::HTTPRequest < Mongrel2::HTTPRequest
	include Strelka::Loggable,
	        Strelka::Constants

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
		@uri    = nil
		@verb   = self.headers[:method].to_sym
		@params = nil
		@notes  = Hash.new( &method(:autovivify) )
	end


	######
	public
	######

	# The HTTP verb of the request (as a Symbol)
	attr_accessor :verb

	# The parameters hash parsed from the request
	attr_writer :params

	# A Hash that plugins can use to pass data amongst themselves. The missing-key
	# callback is set to auto-create nested sub-hashes.
	attr_reader :notes


	### Return a URI object parsed from the URI of the request.
	###
	###   # "GET /user/1/profile HTTP/1.1"
	###   request.uri
	###   # => #<URI::HTTP:0x007fe34d16b2e0 URL:http://localhost:8080/user/1/profile>
	def uri
		unless @uri
			# :TODO: Make this detect https scheme once I figure out how to
			# detect it.
			uri = "http://%s%s" % [
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
		rval.path = self.route
		rval.query = nil
		return rval
	end


	### Return the portion of the Request's path that was routed by Mongrel2. This and the
	### #app_path make up the #path.
	###
	###   # For a handler with a route of '/user', for the request:
	###   # "GET /user/1/profile HTTP/1.1"
	###   request.route
	###   # => "/user"
	def route
		return self.headers.pattern
	end
	alias_method :pattern, :route


	### Return the portion of the Request's path relative to the request's #route.
	###
	###   # For a handler with a route of '/user', for the request:
	###   # "GET /user/1/profile HTTP/1.1"
	###   request.app_path
	###   # => "/1/profile"
	def app_path
		rval = self.uri.path.dup
		rval.slice!( 0, self.route.length )
		return rval
	end


	### Parse the request parameters and return them as a Hash. For GET requests, these are
	### take from the query arguments, and for POST requests, from the 
	###
	###   # For a handler with a route of '/user', for the request:
	###   # "GET /user/1/profile?checkbox=1&checkbox=2&text=foo HTTP/1.1"
	###   # r.params
	###   # => {"checkbox"=>["1", "2"], "text"=>"foo"}
	def params
		unless @params
			case self.verb
			when :GET, :HEAD
				@params = self.parse_query_args
			when :POST, :PUT
				@params = self.parse_form_data
			else
				self.log.debug "No parameters for a %s request." % [ self.verb ]
			end
		end

		return @params
	end


	#########
	protected
	#########

	### Return a Hash of request query arguments.  
	### ?arg1=yes&arg2=no&arg3  #=> {'arg1' => 'yes', 'arg2' => 'no', 'arg3' => nil}
	def parse_query_args
		return {} if self.uri.query.nil?
		return merge_query_args( URI.decode_www_form(self.uri.query) )
	end


	### Return a Hash of request form data.
	def parse_form_data
		case self.headers.content_type
		when 'application/x-www-form-urlencoded'
			 return merge_query_args( URI.decode_www_form(self.body) )
		when 'application/json', 'text/javascript'
			return Yajl.load( self.body )
		when 'text/x-yaml', 'application/x-yaml'
			return YAML.load( self.body )
		when 'multipart/form-data'
			raise NotImplementedError, "%p doesn't handle multipart form data yet" %
				[ self.class ]
		else
			raise Strelka::Error, "don't know how to handle %p form data" %
				[ self.headers.content_type ]
		end
	end


	#######
	private
	#######

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


	### Create and return a Hash that will auto-vivify any values it is missing with
	### another auto-vivifying Hash.
	def autovivify( hash, key )
		hash[ key ] = Hash.new( &method(:autovivify) )
	end

end # class Strelka::HTTPRequest
