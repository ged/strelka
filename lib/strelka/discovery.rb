# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require 'rubygems'
require 'strelka' unless defined?( Strelka )


# The Strelka application-discovery system.
module Strelka::Discovery
	extend Loggability,
	       Configurability,
	       Strelka::MethodUtilities


	# Loggability API -- log to the Strelka logger
	log_to :strelka

	# Configurability API -- use the 'discovery' section of the config
	config_key :discovery


	# Default config
	CONFIG_DEFAULTS = {
		app_discovery_file: 'strelka/apps.rb',
		local_data_dirs:  'data/*',
	}.freeze


	##
	# The Hash of Strelka::App subclasses, keyed by the Pathname of the file they were
	# loaded from, or +nil+ if they weren't loaded via ::load.
	singleton_attr_reader :discovered_classes

	##
	# The glob(3) pattern for matching the discovery hook file.
	singleton_attr_accessor :app_discovery_file

	##
	# The glob(3) pattern for matching local data directories during discovery. Local
	# data directories are evaluated relative to the CWD.
	singleton_attr_accessor :local_data_dirs

	##
	# The name of the file that's currently being loaded (if any)
	singleton_attr_reader :loading_file


	# Class instance variables
	@discovered_classes = Hash.new {|h,k| h[k] = [] }
	@app_discovery_file = CONFIG_DEFAULTS[:app_discovery_file]
	@local_data_dirs  = CONFIG_DEFAULTS[:local_data_dirs]
	@discovered_apps    = nil


	### Register an app with the specified +name+ that can be loaded from the given
	### +path+.
	def self::register_app( name, path )
		@discovered_apps ||= {}

		if @discovered_apps.key?( name )
			raise "Can't register a second '%s' app at %s; already have one at %s" %
				[ name, path, @discovered_apps[name] ]
		end

		self.log.debug "Registered app at %s as %p" % [ path, name ]
		@discovered_apps[ name ] = path
	end


	### Register multiple apps by passing +a_hash+ of names and paths.
	def self::register_apps( a_hash )
		a_hash.each do |name, path|
			self.register_app( name, path )
		end
	end


	### Return a Hash of apps discovered by loading #app_discovery_files.
	def self::discovered_apps
		unless @discovered_apps
			@discovered_apps ||= {}
			self.app_discovery_files.each do |path|
				self.log.debug "Loading discovery file %p" % [ path ]
				Kernel.load( path )
			end
		end

		return @discovered_apps
	end


	### Return an Array of app discovery hook files found in the latest installed gems and
	### the current $LOAD_PATH.
	def self::app_discovery_files
		return Gem.find_latest_files( self.app_discovery_file )
	end


	### Configure the App. Override this if you wish to add additional configuration
	### to the 'app' section of the config that will be passed to you when the config
	### is loaded.
	def self::configure( config=nil )
		config = self.defaults.merge( config || {} )

		self.app_discovery_file = config[:app_discovery_file]
		self.local_data_dirs  = config[:local_data_dirs]
	end


	### Return a Hash of glob patterns for matching data directories for the latest
	### versions of all installed gems which have a dependency on Strelka, keyed
	### by gem name.
	def self::discover_data_dirs
		datadirs = {
			'' => self.local_data_dirs
		}

		# Find all the gems that depend on Strelka
		gems = Gem::Specification.find_all do |gemspec|
			gemspec.dependencies.find {|dep| dep.name == 'strelka'}
		end

		self.log.debug "Found %d gems with a Strelka dependency" % [ gems.length ]

		# Find all the files under those gems' data directories that match the application
		# pattern
		gems.sort.reverse.each do |gemspec|
			# Only look at the latest version of the gem
			next if datadirs.key?( gemspec.name )
			datadirs[ gemspec.name ] = File.join( gemspec.full_gem_path, "data", gemspec.name )
		end

		self.log.debug "  returning data directories: %p" % [ datadirs ]
		return datadirs
	end


	### Attempt to load the file associated with the specified +app_name+ and return
	### the first Strelka::App class declared in the process.
	def self::load( app_name )
		apps = self.discovered_apps or return nil
		file = apps[ app_name ] or return nil

		return self.load_file( file )
	end


	### Load the specified +file+ and return the first class that extends Strelka::Discovery.
	def self::load_file( file )
		self.log.debug "Loading application/s from %p" % [ file ]
		Thread.current[ :__loading_file ] = loading_file = file
		self.discovered_classes.delete( loading_file )

		Kernel.load( loading_file.to_s )

		new_subclasses = self.discovered_classes[ loading_file ]
		self.log.debug "  loaded %d new app class/es" % [ new_subclasses.size ]

		return new_subclasses.first
	ensure
		Thread.current[ :__loading_file ] = nil
	end


	### Return the Pathname of the file being loaded by the current thread (if there is one)
	def self::loading_file
		return Thread.current[ :__loading_file ]
	end


	### Register the given +subclass+ as having inherited a class that has been extended
	### with Discovery.
	def self::add_inherited_class( subclass )
		self.log.debug "Registering discovered subclass %p" % [ subclass ]
		self.discovered_classes[ self.loading_file ] << subclass
	end


	### Inheritance callback -- register the subclass with its parent for discovery.
	def inherited( subclass )
		super
		Strelka::Discovery.log.info "%p inherited by discoverable class %p" % [ self, subclass ]
		Strelka::Discovery.add_inherited_class( subclass )
	end

end # module Strelka::Discovery

