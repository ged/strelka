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
require 'strelka/mixins'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka, "mixins" do


	describe Strelka::Loggable do
		before(:each) do
			@logfile = StringIO.new('')
			Strelka.logger = Logger.new( @logfile )

			@test_class = Class.new do
				include Strelka::Loggable

				def log_test_message( level, msg )
					self.log.send( level, msg )
				end

				def logdebug_test_message( msg )
					self.log_debug.debug( msg )
				end
			end
			@obj = @test_class.new
		end


		it "is able to output to the log via its #log method" do
			@obj.log_test_message( :debug, "debugging message" )
			@logfile.rewind
			@logfile.read.should =~ /debugging message/
		end

		it "is able to output to the log via its #log_debug method" do
			@obj.logdebug_test_message( "sexydrownwatch" )
			@logfile.rewind
			@logfile.read.should =~ /sexydrownwatch/
		end
	end


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

end

