# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent.parent
	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
}

require 'rspec'

require 'spec/lib/helpers'

require 'strelka'
require 'strelka/app/plugins'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::App::Plugins do

	before( :all ) do
		setup_logging( :fatal )
		@original_plugin_registry = Strelka::App.loaded_plugins.dup
	end

	after( :all ) do
		Strelka::App.loaded_plugins.clear
		Strelka::App.loaded_plugins.replace( @original_plugin_registry )
		reset_logging()
	end

	after( :each ) do
		Strelka::App.loaded_plugins.delete_if {|mod| mod =~ /anonymous/ }
	end

	RSpec::Matchers.define( :order ) do |item|
		match do |enumerable|
			raise "%p doesn't include %p" % [ enumerable, item ] unless
				enumerable.include?( item )
			if defined?( @before )
				raise "%p doesn't include %p" % [ enumerable, @before ] unless
					enumerable.include?( @before )
				enumerable.index( @before ) < enumerable.index( item )
			elsif defined?( @after )
				raise "%p doesn't include %p" % [ enumerable, @after ] unless
					enumerable.include?( @after )
				Strelka.log.debug "Enumerable is: %p" % [ enumerable ]
				enumerable.index( @after ) > enumerable.index( item )
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

		it "registers itself with a plugin registry" do
			plugin = Module.new do
				extend Strelka::App::Plugin
			end

			Strelka::App.loaded_plugins.should include( plugin.plugin_name => plugin )
		end


		it "extends the object even if included" do
			plugin = Module.new do
				include Strelka::App::Plugin
			end

			Strelka::App.loaded_plugins.should include( plugin.plugin_name => plugin )
		end


		context "that declares that it should run before another" do

			before( :each ) do
				@other_mod = Module.new { include Strelka::App::Plugin }
				modname = @other_mod.plugin_name
				@before_mod = Module.new do
					include Strelka::App::Plugin
					run_before( modname )
				end
			end


			it "sorts before it in the plugin registry" do
				Strelka::App.loaded_plugins.tsort.
					should order( @other_mod.plugin_name ).before( @before_mod.plugin_name )
			end

		end

		context "that declares that it should run after another" do

			before( :each ) do
				@other_mod = Module.new { include Strelka::App::Plugin }
				modname = @other_mod.plugin_name
				@after_mod = Module.new do
					include Strelka::App::Plugin
					run_after( modname )
				end
			end


			it "sorts after it in the plugin registry" do
				Strelka::App.loaded_plugins.tsort.
					should order( @other_mod.plugin_name ).after( @after_mod.plugin_name )
			end

		end

	end


	context "loading" do
		it "appends class methods if the plugin has them" do
			plugin = Module.new do
				include Strelka::App::Plugin
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
				include Strelka::App::Plugin
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
			@including_class = Class.new { include Strelka::App::Plugins }
		end

		it "can declare a single plugin to load" do
			klass = Class.new( @including_class ) do
				plugin :routing
			end
			klass.install_plugins

			klass.ancestors.should include( Strelka::App::Routing )
		end

		it "can declare a list of plugins to load" do
			klass = Class.new( @including_class ) do
				plugins :templating, :routing
			end
			klass.install_plugins

			klass.ancestors.should include( Strelka::App::Routing, Strelka::App::Templating )
		end

		it "installs the plugins in the right order even if they're loaded at separate times" do
			superclass = Class.new( @including_class ) do
				plugin :routing
			end
			subclass = Class.new( superclass ) do
				plugin :templating
			end
			subclass.install_plugins

			subclass.ancestors.should order( Strelka::App::Templating ).after( Strelka::App::Routing )
		end

		it "adds information about where plugins were installed from when they're installed" do
			klass = Class.new( @including_class ) do
				plugin :routing
			end
			klass.plugins_installed_from.should be_nil()
			klass.install_plugins
			klass.plugins_installed_from.should =~ /#{__FILE__}:#{__LINE__ - 1}/
		end

	end


	context "Plugins loaded in a superclass" do

		before( :each ) do
			@base_class = Class.new { include Strelka::App::Plugins }
			@superclass = Class.new( @base_class ) do
				plugin :routing
			end
		end


		it "are inherited by subclasses" do
			subclass = Class.new( @superclass ) do
				get 'foom' do |req|
					res = req.response
					res.puts( "Yep, it worked." )
					return res
				end
			end

			subclass.routes.should == [
				[ :GET, ['foom'], {action: subclass.instance_method(:GET_foom), options: {}} ]
			]
		end

	end

end

