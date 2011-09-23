#!/usr/bin/env ruby

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

			it "knows that it isn't after the other plugin" do
				@before_mod.should_not be_after( @other_mod )
			end

			it "knows that it is before the other plugin" do
				@before_mod.should be_before( @other_mod )
			end

			it "sorts before the other plugin" do
				[ @other_mod, @before_mod].sort.should == [ @before_mod, @other_mod ]
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

			it "knows that it is after the other plugin" do
				@after_mod.should be_after( @other_mod )
			end

			it "knows that is isn't before the other plugin" do
				@after_mod.should_not be_before( @other_mod )
			end

			it "sorts after the other plugin" do
				[ @after_mod, @other_mod ].sort.should == [ @other_mod, @after_mod ]
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
			app.install_plugin( plugin )

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
			app.install_plugin( plugin )

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

			klass.ancestors.should include( Strelka::App::Routing )
		end

		it "can declare a list of plugins to load" do
			klass = Class.new( @including_class ) do
				plugins :templating, :routing
			end

			klass.ancestors.should include( Strelka::App::Routing, Strelka::App::Templating )
		end

	end

end

