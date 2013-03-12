# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require 'mongrel2'
require 'loggability'
require 'configurability'
require 'configurability/config'


# A Ruby application framework for Mongrel2[http://mongrel2.org/].
#
# == Author/s
#
# * Michael Granger <ged@FaerieMUD.org>
#
# :title: Strelka Web Application Framework
# :main: README.rdoc
#
module Strelka
	extend Loggability

	# Loggability API -- Set up this module as a log host.
	log_as :strelka

	# Library version constant
	VERSION = '0.3.0'

	# Version-control revision constant
	REVISION = %q$Revision$

	require 'strelka/constants'
	require 'strelka/exceptions'
	include Strelka::Constants

	require 'strelka/app'
	require 'strelka/httprequest'
	require 'strelka/httpresponse'


	### Get the library version. If +include_buildnum+ is true, the version string will
	### include the VCS rev ID.
	def self::version_string( include_buildnum=false )
		vstring = "%s %s" % [ self.name, VERSION ]
		vstring << " (build %s)" % [ REVISION[/: ([[:xdigit:]]+)/, 1] || '0' ] if include_buildnum
		return vstring
	end


	# The installed Configurability::Config object
	@config = nil
	class << self; attr_accessor :config; end


	### Convenience method -- Load the Configurability::Config from +configfile+
	### and install it.
	def self::load_config( configfile, defaults=nil )
		defaults ||= Configurability.gather_defaults
		self.log.info "Loading universal config from %p with defaults for sections: %p." %
			[ configfile, defaults.keys ]
		self.config = Configurability::Config.load( configfile, defaults )
		self.config.install
	end

end # module Strelka

