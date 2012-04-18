# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent
	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
}

require 'rspec'

require 'spec/lib/helpers'

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
		setup_logging( :fatal )
		@original_registry = Strelka::App.loaded_plugins.dup
	end

	after( :each ) do
		Strelka::App.loaded_plugins.clear
	end

	after( :all ) do
		Strelka::App.loaded_plugins = @original_registry
		reset_logging()
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
				def self::name; "Strelka::App::TestPlugin"; end
				extend Strelka::Plugin
			end
		end

		it "registers itself with a plugin registry" do
			Strelka::App.loaded_plugins.should include( @plugin.plugin_name => @plugin )
		end


		context "that declares that it should run before another" do

			before( :each ) do
				modname = @plugin.plugin_name
				@before_mod = Module.new do
					def self::name; "Strelka::App::BeforeTestPlugin"; end
					extend Strelka::Plugin
					run_before( modname )
				end
			end


			it "sorts before it in the plugin registry" do
				Strelka::App.loaded_plugins.tsort.
					should order( @plugin.plugin_name ).after( @before_mod.plugin_name )
			end

		end

		context "that declares that it should run after another" do

			before( :each ) do
				modname = @plugin.plugin_name
				@after_mod = Module.new do
					def self::name; "Strelka::App::AfterTestPlugin"; end
					extend Strelka::Plugin
					run_after( modname )
				end
			end


			it "sorts after it in the plugin registry" do
				Strelka::App.loaded_plugins.tsort.
					should order( @plugin.plugin_name ).before( @after_mod.plugin_name )
			end

		end

	end


	context "loading" do
		it "appends class methods if the plugin has them" do
			plugin = Module.new do
				def self::name; "Strelka::App::ClassMethodsTestPlugin"; end
				include Strelka::Plugin
				module ClassMethods
					def a_class_method; return "yep."; end
				end
			end

			app = Class.new( Strelka::App )
			app.register_plugin( plugin )

			app.a_class_method.should == "yep."
		end

		it "adds class-instance variables to the class if the plugin has them" do
			plugin = Module.new do
				def self::name; "Strelka::App::ClassInstanceMethodsTestPlugin"; end
				include Strelka::Plugin
				module ClassMethods
					@testing_value = :default
					attr_accessor :testing_value
				end
			end

			app = Class.new( Strelka::App )
			app.register_plugin( plugin )

			app.testing_value.should == :default
			app.testing_value = :not_the_default
			app.testing_value.should == :not_the_default
		end
	end


	context "plugin/plugins declarative" do

		before( :each ) do
			@pluggable_class = Strelka::Pluggable
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
				run_before :routing
			end
		end


		it "can declare a single plugin to load" do
			klass = Class.new( @pluggable_class ) do
				plugin :routing
			end
			klass.install_plugins

			klass.ancestors.should include( @routing_plugin )
		end

		it "can declare a list of plugins to load" do
			klass = Class.new( @pluggable_class ) do
				plugins :templating, :routing
			end
			klass.install_plugins
			klass.ancestors.should include( @routing_plugin, @templating_plugin )
		end

		it "installs the plugins in the right order even if they're loaded at separate times" do
			superclass = Class.new( @pluggable_class ) do
				plugin :routing
			end
			subclass = Class.new( superclass ) do
				plugin :templating
			end
			subclass.install_plugins

			subclass.ancestors.should order( @templating_plugin ).before( @routing_plugin )
		end

		it "adds information about where plugins were installed" do
			klass = Class.new( @pluggable_class ) do
				plugin :routing
			end
			klass.plugins_installed_from.should be_nil()
			klass.install_plugins
			klass.plugins_installed_from.should =~ /#{__FILE__}:#{__LINE__ - 1}/
		end

	end


	context "Plugins loaded in a superclass" do

		before( :each ) do
			@superclass = Class.new( Strelka::Pluggable ) do
				plugin :routing
			end
		end


		it "are inherited by subclasses" do
			subclass = Class.new( @superclass ) do
				route_some_stuff
			end

			subclass.routed.should be_true()
		end

	end

end

