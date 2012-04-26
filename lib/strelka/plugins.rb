# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require 'set'
require 'tsort'

require 'strelka' unless defined?( Strelka )
require 'strelka/mixins'

module Strelka
	extend Strelka::MethodUtilities

	# A topologically-sorted hash for plugin management
	class PluginRegistry < Hash
		include TSort
		alias_method :tsort_each_node, :each_key
		def tsort_each_child( node, &block )
			mod = fetch( node ) { [] }
			if mod.respond_to?( :successors )
				mod.successors.each( &block )
			else
				mod.each( &block )
			end
		end
	end


	# Plugin Module extension -- adds registration, load-order support, etc.
	module Plugin

		### Extension hook -- Extend the given object with methods for setting it
		### up as a plugin for its containing namespace.
		def self::extended( object )
			super

			# Find the plugin's namespace container, which will be the
			# pluggable class/module
			pluggable_name = object.name.split( '::' )[ 0..-2 ]
			pluggable = pluggable_name.inject( Object ) do |mod, name|
				mod.const_get( name )
			end

			Strelka.log.debug "Extending %p as a Strelka::Plugin for %p" % [ object, pluggable ]
			object.successors = Set.new
			object.pluggable = pluggable

			# Register any pending dependencies for the newly-loaded plugin
			name = object.plugin_name
			if (( deps = pluggable.loaded_plugins[name] ))
				Strelka.log.debug "  installing deferred deps for %p" % [ name ]
				object.run_after( *deps )
			end

			Strelka.log.debug "  adding %p (%p) to the plugin registry for %p" %
				[ name, object, pluggable ]
			pluggable.loaded_plugins[ name ] = object
		end


		#############################################################
		###	A P P E N D E D   M E T H O D S
		#############################################################

		# An Array that tracks which plugins should be installed after itself.
		attr_accessor :successors

		# The Class/Module that this plugin belongs to
		attr_accessor :pluggable


		### Return the name of the receiving plugin
		def plugin_name
			name = self.name || "anonymous#{self.object_id}"
			name.sub!( /.*::/, '' )
			return name.downcase.to_sym
		end


		### Register the receiver as needing to be run before +other_plugins+ for requests, and
		### *after* them for responses.
		def run_before( *other_plugins )
			name = self.plugin_name
			other_plugins.each do |other_name|
				self.pluggable.loaded_plugins[ other_name ] ||= []
				mod = self.pluggable.loaded_plugins[ other_name ]

				if mod.respond_to?( :run_after )
					mod.run_after( name )
				else
					Strelka.log.debug "%p plugin not yet loaded; setting up pending deps" % [ other_name ]
					mod << name
				end
			end
		end


		### Register the receiver as needing to be run after +other_plugins+ for requests, and
		### *before* them for responses.
		def run_after( *other_plugins )
			Strelka.log.debug "  %p will run after %p" % [ self, other_plugins ]
			self.successors.merge( other_plugins )
		end

	end # module Plugin


	# Module API for the plugin system. This mixin adds the ability to load
	# and install plugins into the extended object.
	module PluginLoader

		### Extension callback -- initialize some data structures in the extended
		### object.
		def self::extended( mod )
			super
			mod.loaded_plugins = Strelka::PluginRegistry.new
			mod.plugin_path_prefix = mod.name.downcase.gsub( /::/, File::SEPARATOR )
		end


		##
		# The Hash of loaded plugin modules, keyed by their downcased and symbolified
		# name (e.g., Strelka::App::Templating => :templating)
		attr_accessor :loaded_plugins

		##
		# If plugins have already been installed, this will be the call frame
		# they were first installed from. This is used to warn about installing
		# plugins twice.
		attr_accessor :plugins_installed_from


		##
		# The prefix path for loading plugins
		attr_accessor :plugin_path_prefix


		### Returns +true+ if the plugins for the extended app class have already
		### been installed.
		def plugins_installed?
			return !self.plugins_installed_from.nil?
		end


		### Extension callback -- add instance variables to extending objects.
		def inherited( subclass )
			super
			@plugins ||= []

			subclass.loaded_plugins = self.loaded_plugins
			subclass.plugin_path_prefix = self.plugin_path_prefix
			subclass.plugins_installed_from = nil
			subclass.instance_variable_set( :@plugins, @plugins.dup )
		end


		### Load the plugins with the given +names+ and install them.
		def plugins( *names )
			Strelka.log.info "Adding plugins: %s" % [ names.flatten.map(&:to_s).join(', ') ]

			# Load the associated Plugin Module objects
			names.flatten.each {|name| self.load_plugin(name) }

			# Add the name/s to the list of mixins to apply on startup
			@plugins |= names

			# Install the declarative half of the plugin immediately
			names.each do |name|
				plugin = nil

				if name.is_a?( Module )
					plugin = name
				else
					plugin = self.loaded_plugins[ name ]
				end

				Strelka.log.debug "  registering %p" % [ name ]
				self.register_plugin( plugin )
			end
		end
		alias_method :plugin, :plugins


		### Load the plugin with the given +name+
		def load_plugin( name )

			# Just return Modules as-is
			return name if name.is_a?( Strelka::Plugin )
			mod = self.loaded_plugins[ name.to_sym ]

			unless mod.is_a?( Module )
				pluginpath = File.join( self.plugin_path_prefix, name.to_s )
				require( pluginpath )
				mod = self.loaded_plugins[ name.to_sym ] or
					raise "#{name} plugin didn't load correctly."
			end

			return mod
		end


		### Register the plugin +mod+ in the receiving class. This adds any
		### declaratives and class-level data necessary for configuring the
		### plugin.
		def register_plugin( mod )
			if mod.const_defined?( :ClassMethods )
				cm_mod = mod.const_get(:ClassMethods)
				Strelka.log.debug "  adding class methods from %p" % [ cm_mod ]

				extend( cm_mod )
				cm_mod.instance_variables.each do |ivar|
					next if instance_variable_defined?( ivar )
					Strelka.log.debug "  copying class instance variable %s" % [ ivar ]
					ival = cm_mod.instance_variable_get( ivar )

					# Don't duplicate modules/classes or immediates
					instance_variable_set( ivar, Strelka::DataUtilities.deep_copy(ival) )
				end
			end
		end


		### Install the mixin part of plugins immediately before the first instance
		### is created.
		def new( * )
			self.install_plugins unless self.plugins_installed?
			super
		end


		### Install the mixin part of the plugin, in the order determined by
		### the plugin registry based on the run_before and run_after specifications
		### of the plugins themselves.
		def install_plugins
			if self.plugins_installed?
				Strelka.log.warn "Plugins were already installed for %p from %p" %
					[ self, self.plugins_installed_from ]
				Strelka.log.info "I'll attempt to install any new ones, but plugin ordering"
				Strelka.log.info "and other functionality might exhibit strange behavior."
			else
				Strelka.log.info "Installing plugins for %p." % [ self ]
			end

			sorted_plugins = self.loaded_plugins.tsort.reverse

			sorted_plugins.each do |name|
				mod = self.loaded_plugins[ name ]

				unless @plugins.include?( name ) || @plugins.include?( mod )
					Strelka.log.debug "  skipping %s" % [ name ]
					next
				end

				Strelka.log.info "  including %p." % [ mod ]
				include( mod )
			end

			self.plugins_installed_from = caller( 1 ).first
		end



		### Output the application stack into the logfile.
		def dump_application_stack
			stack = self.class.ancestors.
				reverse.
				drop_while {|mod| mod != Strelka::PluginLoader }.
				select {|mod| mod.respond_to?(:plugin_name) }.
				collect {|mod| mod.plugin_name }.
				reverse

			self.log.info "Application stack: request -> %s" % [ stack.join(" -> ") ]
		end

	end # module PluginLoader

end # class Strelka


