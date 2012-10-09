# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require 'set'
require 'forwardable'
require 'loggability'

require 'strelka' unless defined?( Strelka )
require 'strelka/cookie'


# An object class which provides a convenient way of accessing a set of Strelka::Cookies.
#
# == Synopsis
#
#   cset = Strelka::CookieSet.new()
#   cset = Strelka::CookieSet.new( cookies )
#
#   cset['cookiename']  # => Strelka::Cookie
#
#   cset['cookiename'] = cookie_object
#   cset['cookiename'] = 'cookievalue'
#   cset[:cookiename] = 'cookievalue'
#   cset << Strelka::Cookie.new( *args )
#
#   cset.include?( 'cookiename' )
#   cset.include?( cookie_object )
#
#   cset.each do |cookie|
#      ...
#   end
#
# == Authors
#
# * Michael Granger <ged@FaerieMUD.org>
# * Jeremiah Jordan <phaedrus@FaerieMUD.org>
#
class Strelka::CookieSet
	extend Forwardable,
	       Loggability
	include Enumerable


	# Loggability API -- send logs through the :strelka logger
	log_to :strelka


	### Parse the Cookie header of the specified +request+ into Strelka::Cookie objects
	### and return them in a new CookieSet.
	def self::parse( request )
		self.log.debug "Parsing cookies from header: %p" % [ request.header.cookie ]
		cookies = Strelka::Cookie.parse( request.header.cookie )
		self.log.debug "  found %d cookies: %p" % [ cookies.length, cookies ]
		return new( cookies.values )
	end


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Create a new CookieSet prepopulated with the given cookies
	def initialize( *cookies )
		@cookie_set = Set.new( cookies.flatten )
	end


	######
	public
	######

	def_delegators :@cookie_set, :each, :empty?, :member?, :length, :size



	### Index operator method: returns the Strelka::Cookie with the given +name+ if it
	### exists in the cookieset.
	def []( name )
		name = name.to_s
		return @cookie_set.find {|cookie| cookie.name == name }
	end


	### Index set operator method: set the cookie that corresponds to the given +name+
	### to +value+. If +value+ is not an Strelka::Cookie, one is created and its
	### value set to +value+.
	def []=( name, value )
		value = Strelka::Cookie.new( name.to_s, value ) unless value.is_a?( Strelka::Cookie )
		raise ArgumentError, "cannot set a cookie named '%s' with a key of '%s'" %
			[ value.name, name ] if value.name.to_s != name.to_s

		self << value
	end


	### Returns +true+ if the CookieSet includes either a cookie with the given name or
	### an Strelka::Cookie object.
	def include?( name_or_cookie )
		return true if @cookie_set.include?( name_or_cookie )
		name = name_or_cookie.to_s
		return self[name] ? true : false
	end
	alias_method :key?, :include?


	### Append operator: Add the given +cookie+ to the set, replacing an existing
	### cookie with the same name if one exists.
	def <<( cookie )
		@cookie_set.delete( cookie )
		@cookie_set.add( cookie )

		return self
	end


end # class Strelka::CookieSet

