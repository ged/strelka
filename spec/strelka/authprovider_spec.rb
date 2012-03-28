# -*- rspec -*-
# vim: set nosta noet ts=4 sw=4:

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent
	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
}

require 'rspec'

require 'spec/lib/helpers'

require 'strelka'
require 'strelka/authprovider'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::AuthProvider do

	before( :all ) do
		@request_factory = Mongrel2::RequestFactory.new( route: '/admin' )
		setup_logging( :fatal )
	end

	after( :all ) do
		reset_logging()
	end


	it "looks for plugins under strelka/authprovider" do
		described_class.derivative_dirs.should include( 'strelka/authprovider' )
	end


	it "is abstract" do
		expect {
			described_class.new
		}.to raise_error( /private method/i )
	end


	describe "a subclass" do

		before( :each ) do
			@subclass = Class.new( described_class )
			@app = mock( "Application" )
			@provider = @subclass.new( @app )
		end


		context "Authentication" do

			it "returns 'anonymous' as credentials if asked to authenticate" do
				req = @request_factory.get( '/admin/console' )
				@provider.authenticate( req ).should == 'anonymous'
			end

		end


		context "Authorization" do

			it "doesn't fail if the application doesn't provide an authz callback" do
				req = @request_factory.get( '/admin/console' )
				expect {
					@provider.authorize( 'anonymous', req )
				}.to_not throw_symbol()
			end

			it "doesn't fail if the application's authz callback returns true" do
				req = @request_factory.get( '/admin/console' )
				expect {
					@provider.authorize( 'anonymous', req ) { true }
				}.to_not throw_symbol()
			end

			it "fails with a 403 (Forbidden) if the app's authz callback returns false" do
				expected_info = {
					status:  403,
					message: "You are not authorized to access this resource.",
					headers: {}
				}
				req = @request_factory.get( '/admin/console' )

				expect {
					@provider.authorize( 'anonymous', req ) { false }
				}.to throw_symbol( :finish, expected_info )
			end

		end

	end

end

