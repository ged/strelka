# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require 'set'
require 'tsort'

require 'strelka' unless defined?( Strelka )
require 'strelka/app' unless defined?( Strelka::App )
require 'strelka/mixins'

class Strelka::App
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


	##
	# The Hash of loaded plugin modules, keyed by their downcased and symbolified
	# name (e.g., Strelka::App::Templating => :templating)
	singleton_attr_reader :loaded_plugins
	@loaded_plugins = PluginRegistry.new


	# Plugin Module extension -- adds registration, load-order support, etc.
	module Plugin

		### Mixin hook -- extend including objects instead.
		def self::included( mod )
			mod.extend( self )
		end


		### Extension hook -- Extend the given object with methods for setting it
		### up as a plugin for Strelka::Apps.
		def self::extended( object )
			Strelka.log.debug "Extending %p as a Strelka::App::Plugin" % [ object ]

			super
			name = object.plugin_name
			object.instance_variable_set( :@successors, Set.new )

			# Register any pending dependencies for the newly-loaded plugin
			if (( deps = Strelka::App.loaded_plugins[name] ))
				Strelka.log.debug "  installing deferred deps for %p" % [ name ]
				object.run_after( *deps )
			end

			Strelka.log.debug "  adding %p (%p) to the plugin registry" % [ name, object ]
			Strelka::App.loaded_plugins[ name ] = object
		end


		#############################################################
		###	A P P E N D E D   M E T H O D S
		#############################################################

		# An Array that tracks which plugins should be installed after itself.
		attr_reader :successors


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
				Strelka::App.loaded_plugins[ other_name ] ||= []
				mod = Strelka::App.loaded_plugins[ other_name ]

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


	# Plugin system
	module Plugins

		### Inclusion callback -- add class methods and instance variables without
		### needing a separate call to #extend.
		def self::included( klass )
			klass.extend( ClassMethods )
			super
		end


		### Class methods to add to classes with plugins.
		module ClassMethods

			##
			# If plugins have already been installed, this will be the call frame
			# they were first installed from. This is used to warn about installing
			# plugins twice.
			attr_accessor :plugins_installed_from


			### Returns +true+ if the plugins for the extended app class have already
			### been installed.
			def plugins_installed?
				return !self.plugins_installed_from.nil?
			end


			### Extension callback -- add instance variables to extending objects.
			def inherited( subclass )
				super
				@plugins ||= []
				subclass.instance_variable_set( :@plugins, @plugins.dup )
				subclass.instance_variable_set( :@plugins_installed_from, nil )
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
						plugin = Strelka::App.loaded_plugins[ name ]
					end

					Strelka.log.debug "  registering %p" % [ name ]
					self.register_plugin( plugin )
				end
			end
			alias_method :plugin, :plugins


			### Load the plugin with the given +name+
			def load_plugin( name )

				# Just return Modules as-is
				return name if name.is_a?( Strelka::App::Plugin )
				mod = Strelka::App.loaded_plugins[ name.to_sym ]

				unless mod.is_a?( Module )
					Strelka.log.debug "Loading plugin from strelka/app/#{name}"
					require "strelka/app/#{name}"
					mod = Strelka::App.loaded_plugins[ name.to_sym ] or
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

				sorted_plugins = Strelka::App.loaded_plugins.tsort.reverse

				sorted_plugins.each do |name|
					mod = Strelka::App.loaded_plugins[ name ]

					unless @plugins.include?( name ) || @plugins.include?( mod )
						Strelka.log.debug "  skipping %s" % [ name ]
						next
					end

					Strelka.log.info "  including %p." % [ mod ]
					include( mod )
				end

				self.plugins_installed_from = caller( 1 ).first
			end

		end # module ClassMethods


		#
		# :section: Extension Points
		#

		### The main extension-point for the plugin system. Strelka::App supers to this method
		### with a block that processes the actual request, and the plugins implement this
		### method to add their own functionality.
		def handle_request( request, &block )
			raise LocalJumpError,
				"no block given; plugin supering without preserving arguments?" unless block
			return block.call( request )
		end


		### An alternate extension-point for the plugin system. Plugins can implement this method
		### to alter or replace the +request+ before the regular request/response cycle begins.
		def fixup_request( request )
			return request
		end


		### An alternate extension-point for the plugin system. Plugins can implement this method
		### to alter or replace the +response+ after the regular request/response cycle is finished.
		def fixup_response( response )
			return response
		end

	end # module Plugins

end # class Strelka::App


