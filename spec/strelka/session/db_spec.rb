# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# frozen-string-literal: true

require_relative '../../helpers'

require 'rspec'

require 'strelka'
require 'strelka/session/db'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::Session::Db do

	before( :all ) do
		@request_factory = Mongrel2::RequestFactory.new( route: '/frothy' )

		@session_id   = 'f9df9436f02f9b6d099a3dc95614fdb4'
		@session_data = {
			:namespace => {
				:hurrrg => true
			}
		}
		@default_config = {
			cookie_name: 'chunkers',
			connect: {
				adapter: Mongrel2::Config.sqlite_adapter
			}
		}
	end

	before( :each ) do
		described_class.configure( @default_config )
		@cookie_name = described_class.cookie_name
	end

	after( :each ) do
		described_class.db.drop_table( :sessions ) if
			described_class.db.table_exists?( :sessions )
	end


	RSpec::Matchers.define( :contain_table ) do |tablename|
		match do |db|
			db.table_exists?( tablename )
		end
	end


	it "creates the database if needed" do
		expect( described_class.db ).to contain_table( :sessions )
	end


	it "can change the default table name" do
		described_class.configure( @default_config.merge(:table_name => :brothy) )
		expect( described_class.db ).to contain_table( :brothy )
		described_class.db.drop_table( :brothy )
	end


	it "can load an existing session from the sessions table" do
		Strelka.log.debug "described_class dataset: %p" % [ described_class.dataset ]
		described_class.dataset.insert(
			:session_id => @session_id,
			:session    => @session_data.to_yaml )

		session = described_class.load( @session_id )
		expect( session.namespaced_hash ).to eq( @session_data )
	end


	it "knows that a request has a session if it has a cookie with an existing session id" do
		described_class.dataset.insert(
			:session_id => @session_id,
			:session    => @session_data.to_yaml )

		session_cookie = "%s=%s" % [ @cookie_name, @session_id ]
		req = @request_factory.get( '/frothy/gymkata', :cookie => session_cookie )
		expect( described_class ).to have_session_for( req )
	end


	it "can save session data to the database" do
		req = @request_factory.get( '/frothy/broth' )
		response = req.response
		session = described_class.new( @session_id, @session_data )
		session.save( response )

		row = session.class.dataset.filter( :session_id => @session_id ).first

		expect( row[ :session_id ] ).to eq( @session_id )
		expect( row[ :session ] ).to match( /hurrrg: true/ )
		expect( row[ :created ].to_s ).to match( /\d{4}-\d{2}-\d{2}/ )
		expect( response.header_data ).to match( /Set-Cookie: #{@cookie_name}=#{@session_id}/i )
	end
end
