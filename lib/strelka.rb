# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require 'mongrel2'
require 'configurability'
require 'configurability/config'

# An application framework for Ruby-mongrel2
#
# == Author/s
#
# * Michael Granger <ged@FaerieMUD.org>
#
# :title: Strelka Web Application Framework
# :main: README.rdoc
#
module Strelka

	# Library version constant
	VERSION = '0.0.1'

	# Version-control revision constant
	REVISION = %q$Revision$


	require 'strelka/logging'
	extend Strelka::Logging

	# Combine Strelka, Mongrel2, and Configurability logging
	Mongrel2.logger = Strelka.logger
	Configurability.logger = Strelka.logger

	require 'strelka/constants'
	include Strelka::Constants

	require 'strelka/exceptions'
	require 'strelka/mixins'
	extend Strelka::MethodUtilities


	### Get the library version. If +include_buildnum+ is true, the version string will
	### include the VCS rev ID.
	def self::version_string( include_buildnum=false )
		vstring = "%s %s" % [ self.name, VERSION ]
		vstring << " (build %s)" % [ REVISION[/: ([[:xdigit:]]+)/, 1] || '0' ] if include_buildnum
		return vstring
	end


	##
	# The Pathname of the directory that will be searched for default applications,
	# config, etc.
	singleton_attr_accessor :datadir
	self.datadir = DEFAULT_DATADIR

	require 'strelka/app'
	require 'strelka/httprequest'
	require 'strelka/httpresponse'


	# The installed Configurability::Config object
	@config = nil
	class << self; attr_accessor :config; end


	### Convenience method -- Load the Configurability::Config from +configfile+
	### and install it.
	def self::load_config( configfile, defaults={} )
		Strelka.log.info "Loading universal config from %p" % [ configfile ]
		self.config = Configurability::Config.load( configfile, defaults )
		self.config.install
	end

end # module Strelka

