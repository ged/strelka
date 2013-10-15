# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require_relative '../../helpers'

require 'rspec'

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


	it_should_behave_like( "A Strelka Plugin" )


	describe "an including App" do

		before( :each ) do
			@app = Class.new( Strelka::App ) do
				plugin :negotiation
				def initialize( appid='conneg-test', sspec=TEST_SEND_SPEC, rspec=TEST_RECV_SPEC )
					super
				end

				add_content_type :tnetstring, 'text/x-tnetstring', TNetstring.method(:dump)

				def handle_request( req )
					super do
						res = req.response
						res.for( :tnetstring ) {[ 'an', {'array' => 'of stuff'} ]}
						res.for( :html ) do
							"<html><head><title>Yep</title></head><body>Yeah!</body></html>"
						end
						res
					end
				end
			end
		end

		after( :each ) do
			@app = nil
		end


		it "gets requests that have been extended with content-negotiation" do
			req = @request_factory.get( '/service/user/estark' )
			@app.new.handle( req )
			expect( req.singleton_class.included_modules ).
				to include( Strelka::HTTPRequest::Negotiation )
		end

		it "gets responses that have been extended with content-negotiation" do
			req = @request_factory.get( '/service/user/estark' )
			res = @app.new.handle( req )
			expect( res.singleton_class.included_modules ).
				to include( Strelka::HTTPResponse::Negotiation )
		end

		it "adds custom content-type transforms to outgoing responses" do
			req = @request_factory.get( '/service/user/astark', :accept => 'text/x-tnetstring' )
			res = @app.new.handle( req )
			expect( res.content_type ).to eq( 'text/x-tnetstring' )
			expect( res.body.read ).to eq( '28:2:an,19:5:array,8:of stuff,}]' )
		end

	end


end

