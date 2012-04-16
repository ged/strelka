# -*- rspec -*-
# vim: set nosta noet ts=4 sw=4:

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent.parent
	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
}

require 'rspec'

require 'spec/lib/helpers'

require 'strelka'
require 'strelka/session/db'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::Session::Db do

	before( :all ) do
		@request_factory = Mongrel2::RequestFactory.new( route: '/frothy' )
		setup_logging( :fatal )

		@session_id   = 'f9df9436f02f9b6d099a3dc95614fdb4'
		@session_data = {
			:namespace => {
				:hurrrg => true
			}
		}
	end

	before( :each ) do
		@cookie_name = described_class.cookie_options[:name]
		described_class.configure
	end

	after( :each ) do
		described_class.db.drop_table( :sessions ) if
			described_class.db.table_exists?( :sessions )
	end

	after( :all ) do
		reset_logging()
	end


	it "creates the database if needed" do
		described_class.db.table_exists?( :sessions ).should be_true()
	end


	it "can change the default table name" do
		described_class.configure( :table_name => :brothy )
		described_class.db.table_exists?( :brothy ).should be_true()
		described_class.db.drop_table( :brothy )
	end


	it "can load an existing session from the sessions table" do
		described_class.dataset.insert(
			:session_id => @session_id,
			:session    => @session_data.to_yaml )

		session = described_class.load( @session_id )
		session.namespaced_hash.should == @session_data
	end


	it "knows that a request has a session if it has a cookie with an existing session id" do
		described_class.dataset.insert(
			:session_id => @session_id,
			:session    => @session_data.to_yaml )

		session_cookie = "%s=%s" % [ @cookie_name, @session_id ]
		req = @request_factory.get( '/frothy/gymkata', :cookie => session_cookie )
		described_class.should have_session_for( req )
	end


	it "can save session data to the database" do
		req = @request_factory.get( '/frothy/broth' )
		response = req.response
		session = described_class.new( @session_id, @session_data )
		session.save( response )

		row = session.class.dataset.filter( :session_id => @session_id ).first
		row[ :session_id ].should   == @session_id
		row[ :session ].should      =~ /hurrrg: true/
		row[ :created ].to_s.should =~ /\d{4}-\d{2}-\d{2}/
		response.header_data.should =~ /Set-Cookie: #{@cookie_name}=#{@session_id}/i
	end
end
