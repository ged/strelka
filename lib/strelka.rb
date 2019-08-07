# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# frozen-string-literal: true

require 'mongrel2'
require 'loggability'
require 'configurability'
require 'configurability/config'


# A Ruby application framework for Mongrel2[http://mongrel2.org/].
#
# == Author/s
#
# * Michael Granger <ged@FaerieMUD.org>
# * Mahlon E. Smith <mahlon@martini.nu>
#
# :title: Strelka Web Application Framework
# :main: README.rdoc
#
module Strelka
	extend Loggability

	# Library version constant
	VERSION = '0.15.0'

	# Version-control revision constant
	REVISION = %q$Revision$

	# The name of the environment variable that can be used to specify a configfile
	# to load.
	CONFIG_ENV = 'STRELKA_CONFIG'

	# The name of the config file for local overrides.
	LOCAL_CONFIG_FILE = Pathname( '~/.strelka.yml' ).expand_path

	# The name of the config file that's loaded if none is specified.
	DEFAULT_CONFIG_FILE = Pathname( 'config.yml' ).expand_path


	# Loggability API -- set up a logger for this namespace.
	log_as :strelka


	require 'strelka/mixins'
	require 'strelka/constants'
	require 'strelka/exceptions'
	include Strelka::Constants
	extend Strelka::MethodUtilities

	require 'strelka/app'
	require 'strelka/httprequest'
	require 'strelka/httpresponse'
	require 'strelka/discovery'


	### Get the library version. If +include_buildnum+ is true, the version string will
	### include the VCS rev ID.
	def self::version_string( include_buildnum=false )
		vstring = "%s %s" % [ self.name, VERSION ]
		vstring << " (build %s)" % [ REVISION[/: ([[:xdigit:]]+)/, 1] || '0' ] if include_buildnum
		return vstring
	end


	### Get the library version. If +include_buildnum+ is true, the version string will
	### include the VCS rev ID.
	def self::version_string( include_buildnum=false )
		vstring = "%s %s" % [ self.name, VERSION ]
		vstring << " (build %s)" % [ REVISION[/: ([[:xdigit:]]+)/, 1] || '0' ] if include_buildnum
		return vstring
	end


	##
	# An Array of callbacks to be run after the config is loaded
	singleton_attr_reader :after_configure_hooks
	@after_configure_hooks = Set.new

	##
	# True if the after_configure hooks have already (started to) run.
	singleton_predicate_reader :after_configure_hooks_run
	@after_configure_hooks_run = false


	#
	# :section: Configuration API
	#

	### Get the loaded config (a Configurability::Config object)
	def self::config
		Configurability.loaded_config
	end


	### Returns +true+ if the configuration has been loaded at least once.
	def self::config_loaded?
		return self.config ? true : false
	end


	### Register a callback to be run after the config is loaded.
	def self::after_configure( &block )
		raise LocalJumpError, "no block given" unless block
		self.after_configure_hooks << block

		# Call the block immediately if the hooks have already been called or are in
		# the process of being called.
		block.call if self.after_configure_hooks_run?
	end
	singleton_method_alias :after_configuration, :after_configure


	### Call the post-configuration callbacks.
	def self::call_after_configure_hooks
		self.log.debug "  calling %d post-config hooks" % [ self.after_configure_hooks.length ]
		@after_configure_hooks_run = true

		self.after_configure_hooks.to_a.each do |hook|
			self.log.debug "    %s line %s..." % hook.source_location
			hook.call
		end
	end


	### Load the specified +config_file+, install the config in all objects with
	### Configurability, and call any callbacks registered via #after_configure.
	def self::load_config( config_file=nil, defaults=nil )
		config_file ||= ENV[ CONFIG_ENV ]
		config_file ||= LOCAL_CONFIG_FILE if LOCAL_CONFIG_FILE.exist?
		config_file ||= DEFAULT_CONFIG_FILE

		defaults    ||= Configurability.gather_defaults

		self.log.warn "Loading config from %p with defaults for sections: %p." %
			[ config_file, defaults.keys ]
		config = Configurability::Config.load( config_file, defaults )
		config.install

		self.call_after_configure_hooks
	end


	### Look up the application class of +appname+, optionally limiting it to the gem
	### named +gemname+. Returns the first matching class, or raises an exception if no
	### app class was found.
	def self::App( appname )
		return Strelka::Discovery.load( appname )
	end

end # module Strelka

