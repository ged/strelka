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
		app_glob_pattern: '{apps,handlers}/**/*',
		local_data_dirs:  'data/*',
	}.freeze


	##
	# The Hash of Strelka::App subclasses, keyed by the Pathname of the file they were
	# loaded from, or +nil+ if they weren't loaded via ::load.
	singleton_attr_reader :subclasses

	##
	# The glob(3) pattern for matching Apps during discovery
	singleton_attr_accessor :app_glob_pattern

	##
	# The glob(3) pattern for matching local data directories during discovery. Local
	# data directories are evaluated relative to the CWD.
	singleton_attr_accessor :local_data_dirs

	##
	# The name of the file that's currently being loaded (if any)
	singleton_attr_reader :loading_file


	# Module instance variables
	@subclasses       = Hash.new {|h,k| h[k] = [] }
	@loading_file     = nil
	@app_glob_pattern = CONFIG_DEFAULTS[:app_glob_pattern]
	@local_data_dirs  = CONFIG_DEFAULTS[:local_data_dirs]


	### Configure the App. Override this if you wish to add additional configuration
	### to the 'app' section of the config that will be passed to you when the config
	### is loaded.
	def self::configure( config=nil )
		config = self.defaults.merge( config || {} )

		self.app_glob_pattern = config[:app_glob_pattern]
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


	### Return a Hash of Strelka app files as Pathname objects from installed gems,
	### keyed by gemspec name .
	def self::discover_paths
		appfiles = {}

		self.discover_data_dirs.each do |gemname, dir|
			pattern = File.join( dir, self.app_glob_pattern )
			appfiles[ gemname ] = Pathname.glob( pattern )
		end

		return appfiles
	end


	### Return an Array of Strelka::App classes loaded from the installed Strelka gems.
	def self::discover
		discovered_apps = []
		app_paths = self.discover_paths

		self.log.debug "Loading apps from %d discovered paths" % [ app_paths.length ]
		app_paths.each do |gemname, paths|
			self.log.debug "  loading gem %s" % [ gemname ]
			gem( gemname ) unless gemname == ''

			self.log.debug "  loading apps from %s: %d handlers" % [ gemname, paths.length ]
			paths.each do |path|
				classes = begin
					self.load( path )
				rescue StandardError, ScriptError => err
					self.log.error "%p while loading Strelka apps from %s: %s" %
						[ err.class, path, err.message ]
					self.log.debug "Backtrace: %s" % [ err.backtrace.join("\n\t") ]
					[]
				end
				self.log.debug "  loaded app classes: %p" % [ classes ]

				discovered_apps += classes
			end
		end

		return discovered_apps
	end


	### Find the first app with the given +appname+ and return the path to its file and the name of
	### the gem it's from. If the optional +gemname+ is given, only consider apps from that gem.
	### Raises a RuntimeError if no app with the given +appname+ was found.
	def self::find( appname, gemname=nil )
		discovered_apps = self.discover_paths

		path = nil
		if gemname
			discovered_apps[ gemname ].each do |apppath|
				self.log.debug "    %s (%s)" % [ apppath, apppath.basename('.rb') ]
				if apppath.basename('.rb').to_s == appname
					path = apppath
					break
				end
			end
		else
			self.log.debug "No gem name; searching them all:"
			discovered_apps.each do |disc_gemname, paths|
				self.log.debug "  %s: %d paths" % [ disc_gemname, paths.length ]
				path = paths.find do |apppath|
					self.log.debug "    %s (%s)" % [ apppath, apppath.basename('.rb') ]
					self.log.debug "    %p vs. %p" % [ apppath.basename('.rb').to_s, appname ]
					apppath.basename('.rb').to_s == appname
				end or next
				gemname = disc_gemname
				break
			end
		end

		unless path
			msg = "Couldn't find an app named '#{appname}'"
			msg << " in the #{gemname} gem" if gemname
			raise( msg )
		end
		self.log.debug "  found: %s" % [ path ]

		return path, gemname
	end


	### Load the specified +file+, and return any Strelka::App subclasses that are loaded
	### as a result.
	def self::load( file )
		self.log.debug "Loading application/s from %p" % [ file ]
		@loading_file = Pathname( file ).expand_path
		self.subclasses.delete( @loading_file )
		Kernel.load( @loading_file.to_s )
		new_subclasses = self.subclasses[ @loading_file ]
		self.log.debug "  loaded %d new app class/es" % [ new_subclasses.size ]

		return new_subclasses
	ensure
		@loading_file = nil
	end


	### Register the given +subclass+ as having inherited a class that has been extended
	### with Discovery.
	def self::add_inherited_class( subclass )
		self.log.debug "Registering discovered subclass %p" % [ subclass ]
		self.subclasses[ self.loading_file ] << subclass
	end


	### Inheritance callback -- register the subclass with its parent for discovery.
	def inherited( subclass )
		super
		Strelka::Discovery.log.info "%p inherited by discoverable class %p" % [ self, subclass ]
		Strelka::Discovery.add_inherited_class( subclass )
	end

end # module Strelka::Discovery

