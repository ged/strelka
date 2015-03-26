# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require_relative '../helpers'

require 'rspec'

require 'strelka'
require 'strelka/plugins'


#####################################################################
###	C O N T E X T S
#####################################################################

class Strelka::Pluggable
	extend Strelka::PluginLoader
end


describe "Strelka plugin system" do

	before( :all ) do
		@original_registry = Strelka::Pluggable.loaded_plugins.dup
	end

	after( :each ) do
		Strelka::Pluggable.loaded_plugins.clear
	end

	after( :all ) do
		Strelka::Pluggable.loaded_plugins = @original_registry
	end


	RSpec::Matchers.define( :order ) do |item|
		match do |enumerable|
			raise "%p doesn't include %p" % [ enumerable, item ] unless
				enumerable.include?( item )
			if defined?( @before )
				raise "%p doesn't include %p" % [ enumerable, @before ] unless
					enumerable.include?( @before )
				enumerable.index( @before ) > enumerable.index( item )
			elsif defined?( @after )
				raise "%p doesn't include %p" % [ enumerable, @after ] unless
					enumerable.include?( @after )
				Strelka.log.debug "Enumerable is: %p" % [ enumerable ]
				enumerable.index( @after ) < enumerable.index( item )
			else
				raise "No .before or .after to compare against!"
			end
		end

		chain :before do |item|
			@before = item
		end

		chain :after do |item|
			@after = item
		end
	end


	describe "Plugin module" do

		before( :each ) do
			@plugin = Module.new do
				def self::name; "Strelka::Pluggable::TestPlugin"; end
				extend Strelka::Plugin
			end
		end

		it "registers itself with a plugin registry" do
			expect( Strelka::Pluggable.loaded_plugins ).to include( @plugin.plugin_name => @plugin )
		end


		context "that declares that it should run before another" do

			before( :each ) do
				modname = @plugin.plugin_name
				@before_mod = Module.new do
					def self::name; "Strelka::Pluggable::BeforeTestPlugin"; end
					extend Strelka::Plugin
					run_outside( modname )
				end
			end


			it "sorts before it in the plugin registry" do
				expect(Strelka::Pluggable.loaded_plugins.tsort).
					to order( @plugin.plugin_name ).after( @before_mod.plugin_name )
			end

		end

		context "that declares that it should run after another" do

			before( :each ) do
				modname = @plugin.plugin_name
				@after_mod = Module.new do
					def self::name; "Strelka::Pluggable::AfterTestPlugin"; end
					extend Strelka::Plugin
					run_inside( modname )
				end
			end


			it "sorts after it in the plugin registry" do
				expect(Strelka::Pluggable.loaded_plugins.tsort).
					to order( @plugin.plugin_name ).before( @after_mod.plugin_name )
			end

		end

	end


	context "loading" do

		it "requires plugins from a directory based on the name of the loader" do
			expect( Strelka::Pluggable ).to receive( :require ).
				with( 'strelka/pluggable/scheduler' ) do
					Module.new do
						def self::name; "Strelka::Pluggable::Scheduler"; end
						extend Strelka::Plugin
					end
				end

			Class.new( Strelka::Pluggable ) { plugin :scheduler }
		end

		it "appends class methods if the plugin has them" do
			plugin = Module.new do
				def self::name; "Strelka::Pluggable::ClassMethodsTestPlugin"; end
				include Strelka::Plugin
				module ClassMethods
					def a_class_method; return "yep."; end
				end
			end

			app = Class.new( Strelka::Pluggable )
			app.register_plugin( plugin )

			expect( app.a_class_method ).to eq( "yep." )
		end

		it "adds class-instance variables to the class if the plugin has them" do
			plugin = Module.new do
				def self::name; "Strelka::Pluggable::ClassInstanceMethodsTestPlugin"; end
				include Strelka::Plugin
				module ClassMethods
					@testing_value = :default
					attr_accessor :testing_value
				end
			end

			app = Class.new( Strelka::Pluggable )
			app.register_plugin( plugin )

			expect( app.testing_value ).to eq( :default )
			app.testing_value = :not_the_default
			expect( app.testing_value ).to eq( :not_the_default )
		end

		it "adds class-instance variables to the class if the plugin has them" do
			plugin = Module.new do
				def self::name; "Strelka::Pluggable::ClassInstanceMethodsTestPlugin"; end
				include Strelka::Plugin
				module ClassMethods
					@testing_value = :default
					attr_accessor :testing_value
				end
			end

			app = Class.new( Strelka::Pluggable )
			app.instance_variable_set( :@testing_value, :pre_existing_value )
			app.register_plugin( plugin )

			expect( app.testing_value ).to eq( :pre_existing_value )
		end

	end


	context "PluginLoader module" do

		before( :each ) do
			@routing_plugin = Module.new do
				def self::name; "Strelka::Pluggable::Routing"; end
				extend Strelka::Plugin
				module ClassMethods
					@routed = false
					attr_reader :routed
					def route_some_stuff
						@routed = true
					end
				end
			end
			@templating_plugin = Module.new do
				def self::name; "Strelka::Pluggable::Templating"; end
				extend Strelka::Plugin
				run_outside :routing
			end
		end


		it "can declare a single plugin to load" do
			klass = Class.new( Strelka::Pluggable ) do
				plugin :routing
			end
			klass.install_plugins

			expect( klass.ancestors ).to include( @routing_plugin )
		end

		it "can declare a list of plugins to load" do
			klass = Class.new( Strelka::Pluggable ) do
				plugins :templating, :routing
			end
			klass.install_plugins
			expect( klass.ancestors ).to include( @routing_plugin, @templating_plugin )
		end

		it "has an introspection method for examining the list of loaded plugins" do
			klass = Class.new( Strelka::Pluggable ) do
				plugins :templating, :routing
			end
			klass.install_plugins
			expect( klass.application_stack ).to eq( [ @templating_plugin, @routing_plugin ] )
		end


		it "installs the plugins in the right order even if they're loaded at separate times" do
			superclass = Class.new( Strelka::Pluggable ) do
				plugin :routing
			end
			subclass = Class.new( superclass ) do
				plugin :templating
			end
			subclass.install_plugins

			expect( subclass.ancestors ).to order( @templating_plugin ).before( @routing_plugin )
		end

		it "adds information about where plugins were installed" do
			klass = Class.new( Strelka::Pluggable ) do
				plugin :routing
			end
			expect( klass.plugins_installed_from ).to be_nil()
			klass.install_plugins
			expect( klass.plugins_installed_from ).to match( /#{__FILE__}:#{__LINE__ - 1}/ )
		end

		it "are inherited by subclasses" do
			parentclass = Class.new( Strelka::Pluggable ) do
				plugin :routing
			end
			subclass = Class.new( parentclass ) do
				route_some_stuff
			end

			expect( subclass.routed ).to be_truthy()
		end

	end

end

