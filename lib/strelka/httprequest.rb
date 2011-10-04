#!/usr/bin/env ruby

require 'uri'

require 'mongrel2/httprequest'
require 'strelka' unless defined?( Strelka )

# An HTTP request class.
class Strelka::HTTPRequest < Mongrel2::HTTPRequest
	include Strelka::Loggable,
	        Strelka::Constants

	# Set Mongrel2 to use Strelka's request class for HTTP requests
	register_request_type( self, *HTTP::RFC2616_VERBS )


	### Initialize some additional stuff for Strelka requests.
	def initialize( * ) # :notnew:
		super
		@uri    = nil
		@verb   = self.headers[:method].to_sym
		@params = nil
	end


	######
	public
	######

	# The HTTP verb of the request (as a Symbol)
	attr_accessor :verb

	# The parameters hash parsed from the request
	attr_writer :params


	### Return a URI object parsed from the URI of the request.
	def uri
		return @uri ||= URI( self.headers.uri )
	end


	### Return the portion of the Request's path that was routed by Mongrel2. This and the
	### #app_path make up the #path.
	def pattern
		return self.headers.pattern
	end


	### Return the portion of the Request's path relative to the application's
	### Mongrel2 route.
	def app_path
		return self.path[ self.pattern.length .. -1 ]
	end


	### Parse the request parameters and return them as a Hash.
	def params
		unless @params
			case self.verb
			when :GET, :HEAD
				@params = self.parse_query_args
			when :POST
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


end # class Strelka::HTTPRequest
