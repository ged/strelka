# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# frozen-string-literal: true

require 'rubygems'
require 'strelka' unless defined?( Strelka )


# The Strelka application-discovery system.
#
# This module provides a mechanism for registering Strelka apps and their
# resources for discovery by the strelka CLI and other systems.
#
# It's responsible for three kinds of discovery:
#
# - Discovery of Strelka app files via Rubygems discovery
# - Discovery and loading of Strelka app classes by name
# - Discovery of data directories for strelka apps
#
# As such it can be used in several different ways.
#
# == \App File \Discovery
#
# If you have an app that you wish to be discoverable, create a
# <tt>lib/strelka/apps.rb</tt> file. This file will be added to those returned
# by the ::app_discovery_files call, which is the list loaded by
# ::discovered_apps.
#
# == \App \Discovery Registration
#
# To add a name and file path to Strelka::Discovery.discovered_apps, you can
# call ::register_app. This will check to make sure no other apps are registered
# with the same name. To register several at the same time, call
# ::register_apps with a Hash of <tt>name => path</tt> pairs.
#
# == Loading Discovered Apps
#
# To load a discovered app, call ::load with its registered name.
#
# This will load the associated file and returns the first Ruby class to inherit
# from a discoverable app class like Strelka::App or Strelka::WebSocketServer.
#
# === Putting it all together
#
# Say, for example, you were putting together an <tt>acme-apps</tt> gem for the
# Acme company that contained Strelka apps for a web store and a CMS. You could
# add a <tt>lib/strelka/apps.rb</tt> file to the <tt>acme-apps</tt> gem that
# contained the following:
#
#     # -*- ruby -*-
#     require 'strelka/discovery'
#
#     Strelka::Discovery.register_apps(
#         'acme-store' => 'lib/acme/store.rb',
#         'acme-cms' => 'lib/acme/cms.rb'
#     )
#
# This would let you do:
#
#     $ gem install acme-apps
#     $ strelka start acme-store
#
#
# == Data Directory \Discovery
#
# If your app requires some filesystem resources, a good way to distribute these
# is in your gem's "data directory". This is a directory in your gem called
# <tt>data/«your gem name»</tt>, and can be found via:
#
#    Gem.datadir( your_gem_name )
#
# Strelka::Discoverable builds on top of this, and can return a Hash of glob
# patterns that will match the data directories of all gems that depend on
# Strelka, keyed by gem name. You can use this to populate search paths for
# templates, static assets, etc.
#
#    template_paths = Strelka::Discovery.discover_data_dirs.
#        flat_map {|_, pattern| Dir.glob(pattern + '/templates') }
#
# == Making a class Discoverable
#
# If you write your own app base class (e.g., Strelka::App,
# Strelka::WebSocketServer), you can make it discoverable by extending it with
# this module. You typically won't have to do this unless you're working on
# Strelka itself.
#
module Strelka::Discovery
	extend Loggability,
	       Configurability,
	       Strelka::MethodUtilities


	# Loggability API -- log to the Strelka logger
	log_to :strelka

	# Configurability API -- use the 'discovery' section of the config
	configurability( 'strelka.discovery' ) do

		##
		# The glob(3) pattern for matching the discovery hook file.
		setting :app_discovery_file, default: 'strelka/apps.rb'

		##
		# The glob(3) pattern for matching local data directories during discovery. Local
		# data directories are evaluated relative to the CWD.
		setting :local_data_dirs, default: 'data/*'

	end


	##
	# The Hash of Strelka::App subclasses, keyed by the Pathname of the file they were
	# loaded from, or +nil+ if they weren't loaded via ::load.
	singleton_attr_reader :discovered_classes

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
			warn "Can't register a second '%s' app at %s; already have one at %s" %
				[ name, path, @discovered_apps[name] ]
			return
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


	### Return a Hash of glob patterns for matching data directories for the latest
	### versions of all installed gems which have a dependency on Strelka, keyed
	### by gem name.
	def self::discover_data_dirs
		datadirs = {
			'' => self.local_data_dirs
		}

		# Find all the gems that depend on Strelka
		gems = Gem::Specification.latest_specs.find_all do |gemspec|
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

		return new_subclasses.last
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

