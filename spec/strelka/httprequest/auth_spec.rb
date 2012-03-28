# -*- rspec -*-
# vim: set nosta noet ts=4 sw=4:

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

require 'rspec'

require 'spec/lib/helpers'

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
		@req.should_not be_authenticated()
		@req.authenticated_user = 'anonymous'
		@req.should be_authenticated()
	end

	it "adds an authenticated_user attribute" do
		@req.authenticated_user.should be_nil()
		@req.authenticated_user = 'someone'
		@req.authenticated_user.should == 'someone'
	end

end
