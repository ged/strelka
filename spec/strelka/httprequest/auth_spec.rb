# -*- rspec -*-
# vim: set nosta noet ts=4 sw=4:

require_relative '../../helpers'

require 'rspec'

require 'strelka'
require 'strelka/httprequest/auth'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::HTTPRequest::Auth do

	before( :all ) do
		setup_logging( :fatal )
		@request_factory = Mongrel2::RequestFactory.new( route: '/service/user' )
	end

	after( :all ) do
		reset_logging()
	end

	before( :each ) do
		@req = @request_factory.get( '/service/user/estark' )
		@req.extend( described_class )
	end


	it "adds an authenticated? predicate" do
		expect( @req ).to_not be_authenticated()
		@req.authenticated_user = 'anonymous'
		expect( @req ).to be_authenticated()
	end

	it "adds an authenticated_user attribute" do
		expect( @req.authenticated_user ).to be_nil()
		@req.authenticated_user = 'someone'
		expect( @req.authenticated_user ).to eq( 'someone' )
	end

end
