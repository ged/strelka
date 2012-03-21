# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require 'strelka' unless defined?( Strelka )
require 'strelka/mixins'


# Abstract base class for authentication provider plugins for Strelka::App::Auth.
class Strelka::AuthProvider
	include PluginFactory,
	        Strelka::Loggable,
	        Strelka::Constants,
			Strelka::AbstractClass

	### PluginFactory API -- return the Array of directories to search for concrete
	### AuthProvider classes.
	def self::derivative_dirs
		return ['strelka/authprovider']
	end


	### Configure the auth provider class with the given +options+, which should be a
	### Hash or an object that has a Hash-like interface. This is a no-op by
	### default.
	def self::configure( options )
	end


	

end # class Strelka::AuthProvider

