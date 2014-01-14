# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require_relative '../helpers'

require 'set'
require 'rspec'
require 'strelka/mixins'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka, "mixins" do


	describe Strelka::AbstractClass do

		context "mixed into a class" do
			it "will cause the extended class to hide its ::new method" do
				testclass = Class.new { extend Strelka::AbstractClass }

				expect {
					testclass.new
				}.to raise_error( NoMethodError, /private/ )
			end

		end


		context "mixed into a superclass" do

			before(:each) do
				testclass = Class.new {
					extend Strelka::AbstractClass
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
				@subobj = double( "delegate" )
				@obj = @testclass.new( @subobj )
			end


			it "can be used to set up delegation through a method" do
				expect( @subobj ).to receive( :delegated_method )
				@obj.delegated_method
			end

			it "passes any arguments through to the delegate object's method" do
				expect( @subobj ).to receive( :delegated_method ).with( :arg1, :arg2 )
				@obj.delegated_method( :arg1, :arg2 )
			end

			it "allows delegation to the delegate object's method with a block" do
				expect( @subobj ).to receive( :delegated_method ).with( :arg1 ).
					and_yield( :the_block_argument )
				blockarg = nil
				@obj.delegated_method( :arg1 ) {|arg| blockarg = arg }
				expect( blockarg ).to eq( :the_block_argument )
			end

			it "reports errors from its caller's perspective", :ruby_1_8_only => true do
				begin
					@obj.erroring_delegated_method
				rescue NoMethodError => err
					expect( err.message ).to match( /nonexistant_method/ )
					expect( err.backtrace.first ).to match( /#{__FILE__}/ )
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
				@subobj = double( "delegate" )
				@obj = @testclass.new( @subobj )
			end


			it "can be used to set up delegation through a method" do
				expect( @subobj ).to receive( :delegated_method )
				@obj.delegated_method
			end

			it "passes any arguments through to the delegate's method" do
				expect( @subobj ).to receive( :delegated_method ).with( :arg1, :arg2 )
				@obj.delegated_method( :arg1, :arg2 )
			end

			it "allows delegation to the delegate's method with a block" do
				expect( @subobj ).to receive( :delegated_method ).with( :arg1 ).
					and_yield( :the_block_argument )
				blockarg = nil
				@obj.delegated_method( :arg1 ) {|arg| blockarg = arg }
				expect( blockarg ).to eq( :the_block_argument )
			end

			it "reports errors from its caller's perspective", :ruby_1_8_only => true do
				begin
					@obj.erroring_delegated_method
				rescue NoMethodError => err
					expect( err.message ).to match( /`erroring_delegated_method' for nil/ )
					expect( err.backtrace.first ).to match( /#{__FILE__}/ )
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
			expect( Strelka::DataUtilities.deep_copy( nil ) ).to be( nil )
			expect( Strelka::DataUtilities.deep_copy( 112 ) ).to be( 112 )
			expect( Strelka::DataUtilities.deep_copy( true ) ).to be( true )
			expect( Strelka::DataUtilities.deep_copy( false ) ).to be( false )
			expect( Strelka::DataUtilities.deep_copy( :a_symbol ) ).to be( :a_symbol )
		end

		it "doesn't try to dup modules/classes" do
			klass = Class.new
			expect( Strelka::DataUtilities.deep_copy( klass ) ).to be( klass )
		end

		it "doesn't try to dup IOs" do
			data = [ $stdin ]
			expect( Strelka::DataUtilities.deep_copy( data[0] ) ).to be( $stdin )
		end

		it "doesn't try to dup Tempfiles" do
			data = Tempfile.new( 'strelka_deepcopy.XXXXX' )
			expect( Strelka::DataUtilities.deep_copy( data ) ).to be( data )
		end

		it "makes distinct copies of arrays and their members" do
			original = [ 'foom', Set.new([ 1,2 ]), :a_symbol ]

			copy = Strelka::DataUtilities.deep_copy( original )

			expect( copy ).to eq( original )
			expect( copy ).to_not be( original )
			expect( copy[0] ).to eq( original[0] )
			expect( copy[0] ).to_not be( original[0] )
			expect( copy[1] ).to eq( original[1] )
			expect( copy[1] ).to_not be( original[1] )
			expect( copy[2] ).to eq( original[2] )
			expect( copy[2] ).to be( original[2] ) # Immediate
		end

		it "makes recursive copies of deeply-nested Arrays" do
			original = [ 1, [ 2, 3, [4], 5], 6, [7, [8, 9], 0] ]

			copy = Strelka::DataUtilities.deep_copy( original )

			expect( copy ).to eq( original )
			expect( copy ).to_not be( original )
			expect( copy[1] ).to_not be( original[1] )
			expect( copy[1][2] ).to_not be( original[1][2] )
			expect( copy[3] ).to_not be( original[3] )
			expect( copy[3][1] ).to_not be( original[3][1] )
		end

		it "makes distinct copies of Hashes and their members" do
			original = {
				:a => 1,
				'b' => 2,
				3 => 'c',
			}

			copy = Strelka::DataUtilities.deep_copy( original )

			expect( copy ).to eq( original )
			expect( copy ).to_not be( original )
			expect( copy[:a] ).to eq( 1 )
			expect( copy.key( 2 ) ).to eq( 'b' )
			expect( copy.key( 2 ) ).to_not be( original.key(2) )
			expect( copy[3] ).to eq( 'c' )
			expect( copy[3] ).to_not be( original[3] )
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

			expect( copy ).to eq( original )
			expect( copy[:a][:b][:c] ).to eq( 'd' )
			expect( copy[:a][:b][:c] ).to_not be( original[:a][:b][:c] )
			expect( copy[:a][:b][:e] ).to eq( 'f' )
			expect( copy[:a][:b][:e] ).to_not be( original[:a][:b][:e] )
			expect( copy[:a][:g] ).to eq( 'h' )
			expect( copy[:a][:g] ).to_not be( original[:a][:g] )
			expect( copy[:i] ).to eq( 'j' )
			expect( copy[:i] ).to_not be( original[:i] )
		end

		it "copies the default proc of copied Hashes" do
			original = Hash.new {|h,k| h[ k ] = Set.new }

			copy = Strelka::DataUtilities.deep_copy( original )

			expect( copy.default_proc ).to eq( original.default_proc )
		end

		it "preserves taintedness of copied objects" do
			original = Object.new
			original.taint

			copy = Strelka::DataUtilities.deep_copy( original )

			expect( copy ).to_not be( original )
			expect( copy ).to be_tainted()
		end

		it "preserves frozen-ness of copied objects" do
			original = Object.new
			original.freeze

			copy = Strelka::DataUtilities.deep_copy( original )

			expect( copy ).to_not be( original )
			expect( copy ).to be_frozen()
		end

	end

end

