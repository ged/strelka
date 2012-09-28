# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require 'date'
require 'time'
require 'loggability'

require 'strelka' unless defined?( Strelka )
require 'strelka/exceptions'
require 'strelka/constants'
require 'strelka/mixins'

# The Strelka::Cookie class, a class for parsing and generating HTTP cookies.
#
# Large parts of this code were copied from the Webrick::Cookie class
# in the Ruby standard library. The copyright statements for that module
# are:
#
#   Author: IPR -- Internet Programming with Ruby -- writers
#   Copyright (c) 2000, 2001 TAKAHASHI Masayoshi, GOTOU Yuuzou
#   Copyright (c) 2002 Internet Programming with Ruby writers. All rights
#   reserved.
#
# References:
#
# * http://tools.ietf.org/html/rfc6265
#
class Strelka::Cookie
	include Strelka::Constants::CookieHeader
	extend Loggability

	# Loggability API -- set up logging under the 'strelka' log host
	log_to :strelka


	# The format of the date field
	COOKIE_DATE_FORMAT = '%a, %d %b %Y %H:%M:%S GMT'

	# Number of seconds in the various offset types
	UNIT_SECONDS = {
		's' => 1,
		'm' => 60,
		'h' => 60*60,
		'd' => 60*60*24,
		'M' => 60*60*24*30,
		'y' => 60*60*24*365,
	}


	### Strip surrounding double quotes from a copy of the specified string
	### and return it.
	def self::dequote( string )
		return string.gsub( /^"|"$/, '' )
	end


	### Parse the specified 'Cookie:' +header+ value and return a Hash of
	### one or more new Strelka::Cookie objects, keyed by name.
	def self::parse( header )
		return {} if header.nil? or header.empty?
		self.log.debug "Parsing cookie header: %p" % [ header ]
		cookies = {}
		version = 0
		header = header.strip

		# "$Version" = value
		if m = COOKIE_VERSION.match( header )
			self.log.debug "  Found cookie version %p" % [ m[:version] ]
			version = Integer( dequote(m[:version]) )
			header.slice!( COOKIE_VERSION )
		end

		# cookie-header = "Cookie:" OWS cookie-string OWS
		# cookie-string = cookie-pair *( ";" SP cookie-pair )
		header.split( /;\x20/ ).each do |cookie_pair|
			self.log.debug "  parsing cookie-pair: %p" % [ cookie_pair ]
			next unless match = cookie_pair.match( COOKIE_PAIR )

			self.log.debug "  matched cookie: %p" % [ match ]
			name = match[:cookie_name].untaint
			value = match[:cookie_value]
			value = self.dequote( value ) if value.start_with?( DQUOTE )
			value = nil if value.empty?

			cookies[ name.to_sym ] = new( name, value, :version => version )
		end

		return cookies
	end


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Create a new Strelka::Cookie object with the specified +name+ and
	### +values+. Valid options are:
	###
	### \version::
	###   The cookie version. 0 (the default) is fine for most uses
	### \domain::
	###   The domain the cookie belongs to.
	### \path::
	###   The path the cookie applies to.
	### \secure::
	###   The cookie's 'secure' flag.
	### \expires::
	###   The cookie's expiration (a Time object). See expires= for valid
	###   values.
	### \max_age::
	###   The lifetime of the cookie, in seconds.
	### \httponly::
	###   HttpOnly flag.
	def initialize( name, value, options={} )
		self.log.debug "New cookie: %p = %p (%p)" % [ name, value, options ]
		@name     = name
		@value    = value

		@domain   = nil
		@path     = nil
		@secure   = false
		@httponly = false
		@max_age  = nil
		@expires  = nil
		@version  = 0

		self.log.debug "  setting options..."
		options.each do |meth, val|
			self.log.debug "    cookie.%s= %p" % [ meth, val ]
			self.__send__( "#{meth}=", val )
		end
		self.log.debug "  done setting options..."
	end


	### Return the cookie's options as a hash.
	def options
		return {
			domain:   self.domain,
			path:     self.path,
			secure:   self.secure?,
			httponly: self.httponly?,
			expires:  self.expires,
			max_age:  self.max_age,
			version:  self.version,
		}
	end



	######
	public
	######

	# The name of the cookie
	attr_accessor :name

	# The string value of the cookie
	attr_reader :value

	# The cookie version. 0 (the default) is fine for most uses
	attr_accessor :version

	# The domain the cookie belongs to
	attr_reader :domain

	# The path the cookie applies to
	attr_accessor :path

	# The cookie's 'secure' flag.
	attr_writer :secure

	# The cookie's HttpOnly flag
	attr_accessor :httponly

	# The cookie's expiration (a Time object)
	attr_reader :expires

	# The lifetime of the cookie, in seconds.
	attr_reader :max_age


	### Set the new value of the cookie to +cookie_octets+. This raises an exception
	### if +cookie_octets+ contains any invalid characters. If your value contains
	### non-US-ASCII characters; control characters; or comma, semicolon, or backslash.
	def value=( cookie_octets )
		self.log.debug "Setting cookie value to: %p" % [ cookie_octets ]
		raise Strelka::CookieError,
			"invalid cookie value; value must be composed of non-control us-ascii characters " +
			"other than SPACE, double-quote, comma, semi-colon, and backslash. " +
			"Use #base64_value= for storing arbitrary data." unless
			cookie_octets =~ /^#{COOKIE_VALUE}$/

		@value = cookie_octets
	end


	### Store the base64'ed +data+ as the cookie value. This is just a convenience
	### method for:
	###
	###     cookie.value = [data].pack('m').strip
	###
	def binary_value=( data )
		self.log.debug "Setting cookie value to base64ed %p" % [ data ]
		self.value = [ data ].pack( 'm' ).strip
	end
	alias_method :wrapped_value=, :binary_value=


	### Fetch the cookie's data after un-base64ing it. This is just a convenience
	### method for:
	###
	###     cookie.value.unpack( 'm' ).first
	###
	def binary_value
		return self.value.unpack( 'm' ).first
	end
	alias_method :wrapped_value, :binary_value


	### Returns +true+ if the secure flag is set
	def secure?
		return @secure ? true : false
	end


	### Returns +true+ if the 'httponly' flag is set
	def httponly?
		return @httponly ? true : false
	end


	# Set the lifetime of the cookie. The value is a decimal non-negative
	# integer.  After +delta_seconds+ seconds elapse, the client should
	# discard the cookie.  A value of zero means the cookie should be
	# discarded immediately.
	def max_age=( delta_seconds )
		if delta_seconds.nil?
			@max_age = nil
		else
			@max_age = Integer( delta_seconds )
		end
	end


	### Set the domain for which the cookie is valid. Leading '.' characters
	### will be stripped.
	def domain=( newdomain )
		if newdomain.nil?
			@domain = nil
		else
			newdomain = newdomain.dup
			newdomain.slice!( 0 ) while newdomain.start_with?( '.' )
			@domain = newdomain
		end
	end


	### Set the cookie's expires field. The value can be either a Time object
	### or a String in any of the following formats:
	### +30s::
	###   30 seconds from now
	### +10m::
	###   ten minutes from now
	### +1h::
	###   one hour from now
	### -1d::
	###   yesterday (i.e. "ASAP!")
	### now::
	###   immediately
	### +3M::
	###   in three months
	### +10y::
	###   in ten years time
	### Thursday, 25-Apr-1999 00:40:33 GMT::
	###   at the indicated time & date
	def expires=( time )
		case time
		when NilClass
			@expires = nil

		when Date
			@expires = Time.parse( time.ctime )

		when Time
			@expires = time

		else
			@expires = parse_time_delta( time )
		end
	end


	### Set the cookie expiration to a time in the past
	def expire!
		self.expires = Time.at(0)
	end


	### Return the cookie as a String
	def to_s
		rval = "%s=%s" % [ self.name, self.make_valuestring ]

		rval << make_field( "Version", self.version ) if self.version.nonzero?
		rval << make_field( "Domain", self.domain )
		rval << make_field( "Expires", make_cookiedate(self.expires) ) if self.expires
		rval << make_field( "Max-Age", self.max_age )
		rval << make_field( "Path", self.path )

		rval << '; ' << 'HttpOnly' if self.httponly?
		rval << '; ' << 'Secure' if self.secure?

		return rval
	end


	### Return +true+ if other_cookie has the same name as the receiver.
	def eql?( other_cookie )
		self.log.debug "Comparing %p with other cookie: %p" % [ self, other_cookie ]
		return (self.name == other_cookie.name) ? true : false
	end


	### Generate a Fixnum hash value for this object. Uses the hash of the cookie's name.
	def hash
		return self.name.to_s.hash
	end


	#########
	protected
	#########

	### Make a uri-escaped value string for the cookie's current +values+.
	def make_valuestring
		return self.value
	end


	#######
	private
	#######

	### Make a cookie field for appending to the outgoing header for the
	### specified +value+ and +field_name+. If +value+ is nil, an empty
	### string will be returned.
	def make_field( field_name, value )
		return '' if value.nil? || (value.is_a?(String) && value.empty?)

		return "; %s=%s" % [
			field_name.capitalize,
			value
		]
	end


	### Parse a time delta like those accepted by #expires= into a Time
	### object.
	def parse_time_delta( time )
		return Time.now if time.nil? || time == 'now'
		return Time.at( Integer(time) ) if /^\d+$/.match( time )

		if /^([+-]?(?:\d+|\d*\.\d*))([mhdMy]?)/.match( time )
			offset = (UNIT_SECONDS[$2] || 1) * Integer($1)
			return Time.now + offset
		end

		return Time.parse( time )
	end


	### Make an RFC2109-formatted date out of +date+.
	def make_cookiedate( date )
		return date.gmtime.strftime( COOKIE_DATE_FORMAT )
	end


	### Quote a copy of the given string and return it.
	def quote( val )
		return %q{"%s"} % [ val.to_s.gsub(/"/, '\\"') ]
	end

end # class Strelka::Cookie
