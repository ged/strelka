#!/usr/bin/env ruby

require 'set'
require 'tsort'

require 'strelka' unless defined?( Strelka )
require 'strelka/app' unless defined?( Strelka::App )

# Pluggable functionality mixin for Strelka::App.
class Strelka::App

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

	# The Hash of loaded plugin modules, keyed by their downcased and symbolified 
	# name (e.g., Strelka::App::Templating => :templating)
	class << self; attr_reader :loaded_plugins; end
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


		### Extension callback -- add instance variables to extending objects.
		def self::extended( object )
			super
			object.instance_variable_set( :@plugins, {} )
		end


		### Class methods to add to classes with plugins.
		module ClassMethods

			### Load the plugin with the given +name+, or nil if 
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


			### Install the plugin +mod+ in the receiving class.
			def install_plugin( mod )
				Strelka.log.debug "  adding %p to %p" % [ mod, self ]
				include( mod )

				if mod.const_defined?( :ClassMethods )
					cm_mod = mod.const_get(:ClassMethods)
					Strelka.log.debug "  adding class methods from %p" % [ cm_mod ]

					extend( cm_mod )
					cm_mod.instance_variables.each do |ivar|
						Strelka.log.debug "  copying class instance variable %s" % [ ivar ]
						ival = cm_mod.instance_variable_get( ivar )

						# Don't duplicate modules/classes or immediates
						case ival
						when Module, TrueClass, FalseClass, Symbol, Numeric, NilClass
							instance_variable_set( ivar, ival )
						else
							instance_variable_set( ivar, ival.dup )
						end
					end
				end
			end


			### Load the plugins with the given +names+ and install them.
			def plugins( *names )
				# Load the associated Plugin Module objects
				names.flatten.each {|name| self.load_plugin(name) }

				# Install the plugins in reverse-sorted order
				Strelka::App.loaded_plugins.tsort.reverse.each do |name|
					plugin = Strelka::App.loaded_plugins[ name ]
					Strelka.log.debug "Considering %p" % [ name ]
					if names.include?( name ) || names.include?( plugin )
						Strelka.log.debug "  installing"
						self.install_plugin( plugin )
					else
						Strelka.log.debug "  not used by this app; skipping"
					end
				end
			end
			alias_method :plugin, :plugins

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
		### to alter or replace the +response+ to the specified +request+ after the regular 
		### request/response cycle is finished.
		def fixup_response( request, response )
			return response
		end

	end # module Plugins

end # class Strelka::App


