# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent
	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
}

require 'set'
require 'rspec'
require 'spec/lib/helpers'
require 'strelka/mixins'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka, "mixins" do


	describe Strelka::AbstractClass do

		context "mixed into a class" do
			it "will cause the including class to hide its ::new method" do
				testclass = Class.new { include Strelka::AbstractClass }

				expect {
					testclass.new
				}.to raise_error( NoMethodError, /private/ )
			end

		end


		context "mixed into a superclass" do

			before(:each) do
				testclass = Class.new {
					include Strelka::AbstractClass
					pure_virtual :test_method
				}
				subclass = Class.new( testclass )
				@instance = subclass.new
			end


			it "raises a NotImplementedError when unimplemented API methods are called" do
				expect {
					@instance.test_method
				}.to raise_error( NotImplementedError, /does not provide an implementation of/ )
			end

			it "declares the virtual methods so that they can be used with arguments under Ruby 1.9" do
				expect {
					@instance.test_method( :some, :arguments )
				}.to raise_error( NotImplementedError, /does not provide an implementation of/ )
			end

		end

	end


	describe Strelka::Delegation do

		before( :all ) do
			setup_logging( :fatal )
		end
		after( :all ) do
			reset_logging()
		end

		describe "method delegation" do
			before( :all ) do
				@testclass = Class.new do
					extend Strelka::Delegation

					def initialize( obj )
						@obj = obj
					end

					def_method_delegators :demand_loaded_object, :delegated_method
					def_method_delegators :nonexistant_method, :erroring_delegated_method

					def demand_loaded_object
						return @obj
					end
				end
			end

			before( :each ) do
				@subobj = mock( "delegate" )
				@obj = @testclass.new( @subobj )
			end


			it "can be used to set up delegation through a method" do
				@subobj.should_receive( :delegated_method )
				@obj.delegated_method
			end

			it "passes any arguments through to the delegate object's method" do
				@subobj.should_receive( :delegated_method ).with( :arg1, :arg2 )
				@obj.delegated_method( :arg1, :arg2 )
			end

			it "allows delegation to the delegate object's method with a block" do
				@subobj.should_receive( :delegated_method ).with( :arg1 ).
					and_yield( :the_block_argument )
				blockarg = nil
				@obj.delegated_method( :arg1 ) {|arg| blockarg = arg }
				blockarg.should == :the_block_argument
			end

			it "reports errors from its caller's perspective", :ruby_1_8_only => true do
				begin
					@obj.erroring_delegated_method
				rescue NoMethodError => err
					err.message.should =~ /nonexistant_method/
					err.backtrace.first.should =~ /#{__FILE__}/
				rescue ::Exception => err
					fail "Expected a NoMethodError, but got a %p (%s)" % [ err.class, err.message ]
				else
					fail "Expected a NoMethodError, but no exception was raised."
				end
			end

		end

		describe "instance variable delegation (ala Forwardable)" do
			before( :all ) do
				@testclass = Class.new do
					extend Strelka::Delegation

					def initialize( obj )
						@obj = obj
					end

					def_ivar_delegators :@obj, :delegated_method
					def_ivar_delegators :@glong, :erroring_delegated_method

				end
			end

			before( :each ) do
				@subobj = mock( "delegate" )
				@obj = @testclass.new( @subobj )
			end


			it "can be used to set up delegation through a method" do
				@subobj.should_receive( :delegated_method )
				@obj.delegated_method
			end

			it "passes any arguments through to the delegate's method" do
				@subobj.should_receive( :delegated_method ).with( :arg1, :arg2 )
				@obj.delegated_method( :arg1, :arg2 )
			end

			it "allows delegation to the delegate's method with a block" do
				@subobj.should_receive( :delegated_method ).with( :arg1 ).
					and_yield( :the_block_argument )
				blockarg = nil
				@obj.delegated_method( :arg1 ) {|arg| blockarg = arg }
				blockarg.should == :the_block_argument
			end

			it "reports errors from its caller's perspective", :ruby_1_8_only => true do
				begin
					@obj.erroring_delegated_method
				rescue NoMethodError => err
					err.message.should =~ /`erroring_delegated_method' for nil/
					err.backtrace.first.should =~ /#{__FILE__}/
				rescue ::Exception => err
					fail "Expected a NoMethodError, but got a %p (%s)" % [ err.class, err.message ]
				else
					fail "Expected a NoMethodError, but no exception was raised."
				end
			end

		end

	end


	describe Strelka::DataUtilities do

		it "doesn't try to dup immediate objects" do
			Strelka::DataUtilities.deep_copy( nil ).should be( nil )
			Strelka::DataUtilities.deep_copy( 112 ).should be( 112 )
			Strelka::DataUtilities.deep_copy( true ).should be( true )
			Strelka::DataUtilities.deep_copy( false ).should be( false )
			Strelka::DataUtilities.deep_copy( :a_symbol ).should be( :a_symbol )
		end

		it "makes distinct copies of arrays and their members" do
			original = [ 'foom', Set.new([ 1,2 ]), :a_symbol ]

			copy = Strelka::DataUtilities.deep_copy( original )

			copy.should == original
			copy.should_not be( original )
			copy[0].should == original[0]
			copy[0].should_not be( original[0] )
			copy[1].should == original[1]
			copy[1].should_not be( original[1] )
			copy[2].should == original[2]
			copy[2].should be( original[2] ) # Immediate
		end

		it "makes recursive copies of deeply-nested Arrays" do
			original = [ 1, [ 2, 3, [4], 5], 6, [7, [8, 9], 0] ]

			copy = Strelka::DataUtilities.deep_copy( original )

			copy.should == original
			copy.should_not be( original )
			copy[1].should_not be( original[1] )
			copy[1][2].should_not be( original[1][2] )
			copy[3].should_not be( original[3] )
			copy[3][1].should_not be( original[3][1] )
		end

		it "makes distinct copies of Hashes and their members" do
			original = {
				:a => 1,
				'b' => 2,
				3 => 'c',
			}

			copy = Strelka::DataUtilities.deep_copy( original )

			copy.should == original
			copy.should_not be( original )
			copy[:a].should == 1
			copy.key( 2 ).should == 'b'
			copy.key( 2 ).should_not be( original.key(2) )
			copy[3].should == 'c'
			copy[3].should_not be( original[3] )
		end

		it "makes distinct copies of deeply-nested Hashes" do
			original = {
				:a => {
					:b => {
						:c => 'd',
						:e => 'f',
					},
					:g => 'h',
				},
				:i => 'j',
			}

			copy = Strelka::DataUtilities.deep_copy( original )

			copy.should == original
			copy[:a][:b][:c].should == 'd'
			copy[:a][:b][:c].should_not be( original[:a][:b][:c] )
			copy[:a][:b][:e].should == 'f'
			copy[:a][:b][:e].should_not be( original[:a][:b][:e] )
			copy[:a][:g].should == 'h'
			copy[:a][:g].should_not be( original[:a][:g] )
			copy[:i].should == 'j'
			copy[:i].should_not be( original[:i] )
		end

		it "copies the default proc of copied Hashes" do
			original = Hash.new {|h,k| h[ k ] = Set.new }

			copy = Strelka::DataUtilities.deep_copy( original )

			copy.default_proc.should == original.default_proc
		end

		it "preserves taintedness of copied objects" do
			original = Object.new
			original.taint

			copy = Strelka::DataUtilities.deep_copy( original )

			copy.should_not be( original )
			copy.should be_tainted()
		end

		it "preserves frozen-ness of copied objects" do
			original = Object.new
			original.freeze

			copy = Strelka::DataUtilities.deep_copy( original )

			copy.should_not be( original )
			copy.should be_frozen()
		end

	end

end

