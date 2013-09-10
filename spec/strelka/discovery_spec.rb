# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent
	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
}

require 'rspec'
require 'zmq'
require 'mongrel2'

require 'spec/lib/helpers'

require 'strelka'
require 'strelka/discovery'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::Discovery do

	before( :all ) do
		setup_logging()
		Mongrel2::Config.db = Mongrel2::Config.in_memory_db
		Mongrel2::Config.init_database

		# Skip loading the 'strelka' gem, which probably doesn't exist in the right version
		# in the dev environment
		strelkaspec = make_gemspec( 'strelka', Strelka::VERSION, false )
		loaded_specs = Gem.instance_variable_get( :@loaded_specs )
		loaded_specs['strelka'] = strelkaspec

	end

	after( :all ) do
		reset_logging()
	end


	let( :discoverable_class ) { Class.new {extend Strelka::Discovery} }

	#
	# Examples
	#

	it "has a method for loading app class/es from a file" do

		app_file = 'an_app.rb'
		app_path = Pathname( app_file ).expand_path
		app_class = nil

		Kernel.should_receive( :load ).with( app_path.to_s ).and_return do
			app_class = Class.new( discoverable_class )
		end
		described_class.load( app_file ).should == [ app_class ]
	end

	it "has a method for discovering installed Strelka app files" do
		specs = {}
		specs[:donkey]     = make_gemspec( 'donkey',  '1.0.0' )
		specs[:rabbit_old] = make_gemspec( 'rabbit',  '1.0.0' )
		specs[:rabbit_new] = make_gemspec( 'rabbit',  '1.0.8' )
		specs[:bear]       = make_gemspec( 'bear',    '1.0.0', false )
		specs[:giraffe]    = make_gemspec( 'giraffe', '1.0.0' )

		expectation = Gem::Specification.should_receive( :each )
		specs.values.each {|spec| expectation.and_yield(spec) }

		donkey_path  = specs[:donkey].full_gem_path
		rabbit_path  = specs[:rabbit_new].full_gem_path
		giraffe_path = specs[:giraffe].full_gem_path

		Dir.should_receive( :glob ).with( 'data/*/{apps,handlers}/**/*' ).
			and_return( [] )
		Dir.should_receive( :glob ).with( "#{giraffe_path}/data/giraffe/{apps,handlers}/**/*" ).
			and_return([ "#{giraffe_path}/data/giraffe/apps/app" ])
		Dir.should_receive( :glob ).with( "#{rabbit_path}/data/rabbit/{apps,handlers}/**/*" ).
			and_return([ "#{rabbit_path}/data/rabbit/apps/subdir/app1.rb",
			             "#{rabbit_path}/data/rabbit/apps/subdir/app2.rb" ])
		Dir.should_receive( :glob ).with( "#{donkey_path}/data/donkey/{apps,handlers}/**/*" ).
			and_return([ "#{donkey_path}/data/donkey/apps/app.rb" ])

		app_paths = described_class.discover_paths

		# app_paths.should have( 4 ).members
		app_paths.should include(
			'donkey'  => [Pathname("#{donkey_path}/data/donkey/apps/app.rb")],
			'rabbit'  => [Pathname("#{rabbit_path}/data/rabbit/apps/subdir/app1.rb"),
			              Pathname("#{rabbit_path}/data/rabbit/apps/subdir/app2.rb")],
			'giraffe' => [Pathname("#{giraffe_path}/data/giraffe/apps/app")]
		)
	end

	it "has a method for loading discovered app classes from installed Strelka app files" do
		gemspec = make_gemspec( 'blood-orgy', '0.0.3' )
		Gem::Specification.should_receive( :each ).and_yield( gemspec ).at_least( :once )

		Dir.should_receive( :glob ).with( 'data/*/{apps,handlers}/**/*' ).
			and_return( [] )
		Dir.should_receive( :glob ).with( "#{gemspec.full_gem_path}/data/blood-orgy/{apps,handlers}/**/*" ).
			and_return([ "#{gemspec.full_gem_path}/data/blood-orgy/apps/kurzweil" ])

		Kernel.stub( :load ).
			with( "#{gemspec.full_gem_path}/data/blood-orgy/apps/kurzweil" ).
			and_return do
				Class.new( discoverable_class )
				true
			end

		app_classes = described_class.discover
		app_classes.should have( 1 ).member
		app_classes.first.should be_a( Class )
		app_classes.first.should < discoverable_class
	end

	it "handles exceptions while loading discovered apps" do
		gemspec = make_gemspec( 'blood-orgy', '0.0.3' )
		Gem::Specification.should_receive( :each ).and_yield( gemspec ).at_least( :once )

		Dir.should_receive( :glob ).with( 'data/*/{apps,handlers}/**/*' ).
			and_return( [] )
		Dir.should_receive( :glob ).with( "#{gemspec.full_gem_path}/data/blood-orgy/{apps,handlers}/**/*" ).
			and_return([ "#{gemspec.full_gem_path}/data/blood-orgy/apps/kurzweil" ])

		Kernel.stub( :load ).
			with( "#{gemspec.full_gem_path}/data/blood-orgy/apps/kurzweil" ).
			and_raise( SyntaxError.new("kurzweil:1: syntax error, unexpected coffeeshop philosopher") )

		app_classes = Strelka::Discovery.discover
		app_classes.should be_empty()
	end


end

