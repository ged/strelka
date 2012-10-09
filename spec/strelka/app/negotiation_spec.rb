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
require 'strelka/plugins'
require 'strelka/app/negotiation'
require 'strelka/behavior/plugin'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::App::Negotiation do


	before( :all ) do
		setup_logging( :fatal )
		@request_factory = Mongrel2::RequestFactory.new( route: '/service/user' )
	end

	after( :all ) do
		reset_logging()
	end


	it_should_behave_like( "A Strelka::App Plugin" )


	describe "an including App" do

		before( :each ) do
			@app = Class.new( Strelka::App ) do
				plugin :negotiation
				def initialize( appid='conneg-test', sspec=TEST_SEND_SPEC, rspec=TEST_RECV_SPEC )
					super
				end
			end
		end

		after( :each ) do
			@app = nil
		end


		it "has its config inherited by subclasses" do
			@app.add_content_type :text, 'text/plain' do
				"It's all text now, baby"
			end
			subclass = Class.new( @app )

			subclass.transform_names.should == @app.transform_names
			subclass.transform_names.should_not equal( @app.transform_names )
			subclass.content_type_transforms.should == @app.content_type_transforms
			subclass.content_type_transforms.should_not equal( @app.content_type_transforms )
		end

		it "gets requests that have been extended with content-negotiation" do
			req = @request_factory.get( '/service/user/estark' )
			@app.new.handle( req )
			req.singleton_class.included_modules.
				should include( Strelka::HTTPRequest::Negotiation )
		end

		it "gets responses that have been extended with content-negotiation" do
			req = @request_factory.get( '/service/user/estark' )
			res = @app.new.handle( req )
			res.singleton_class.included_modules.
				should include( Strelka::HTTPResponse::Negotiation )
		end

	end


end

