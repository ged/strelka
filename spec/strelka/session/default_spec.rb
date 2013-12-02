# -*- rspec -*-
# vim: set nosta noet ts=4 sw=4:

require_relative '../../helpers'

require 'rspec'

require 'strelka'
require 'strelka/session/default'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::Session::Default do

	before( :all ) do
		@request_factory = Mongrel2::RequestFactory.new( route: '/hungry' )
		setup_logging( :fatal )
	end

	before( :each ) do
		described_class.configure
		@cookie_name = described_class.cookie_name
	end

	after( :each ) do
		described_class.sessions.clear
	end

	after( :all ) do
		reset_logging()
	end

	it "has distinct duplicates" do
		original = Strelka::Session.create( 'default', 'the_session_id' )
		copy = original.dup
		copy[:foom] = 1
		expect( original[:foom] ).to eq( {} )
	end


	it "can be configured to store its session ID in a different cookie" do
		described_class.configure( :cookie_name => 'buh-mahlon' )
		expect( described_class.cookie_name ).to eq( 'buh-mahlon' )
	end

	it "can load sessions from and save sessions to its in-memory store" do
		session_data = { :namespace => {'the' => 'stuff'} }
		described_class.save_session_data( 'the_key', session_data )

		loaded = described_class.load_session_data( 'the_key' )
		expect( loaded ).to_not equal( session_data )
		expect( loaded ).to eq( session_data )
	end

	it "generates a session-id if one isn't available in the request" do
		req = @request_factory.get( '/hungry/what-is-in-a-fruit-bowl?' )
		expect( described_class.get_session_id(req) ).to match( /^[[:xdigit:]]+$/ )
	end

	it "rejects invalid session-ids" do
		session_cookie = "%s=gibberish" % [ @cookie_name ]
		req = @request_factory.get( '/hungry/what-is-in-a-fruit-bowl?', :cookie => session_cookie )
		expect( described_class.get_session_id(req) ).to match( /^[[:xdigit:]]+$/ )
	end

	it "accepts and reuses an existing valid session-id" do
		session_id = '3422067061a5790be374c81118d9ed3f'
		session_cookie = "%s=%s" % [ @cookie_name, session_id ]
		req = @request_factory.get( '/hungry/what-is-in-a-fruit-bowl?', :cookie => session_cookie )
		expect( described_class.get_session_id(req) ).to eq( session_id )
	end

	it "knows that a request has a session if it has a cookie with an existing session id" do
		session_id = '3422067061a5790be374c81118d9ed3f'
		described_class.sessions[ session_id ] = {}
		session_cookie = "%s=%s" % [ @cookie_name, session_id ]
		req = @request_factory.get( '/hungry/what-is-in-a-fruit-bowl?', :cookie => session_cookie )
		expect( described_class ).to have_session_for( req )
	end

	it "can save itself to the store and set the response's session ID" do
		req          = @request_factory.get( '/hungry/hungry/hippos' )
		response     = req.response
		session_id   = '3422067061a5790be374c81118d9ed3f'
		session_data = { :namespace => {'fruit' => 'bowl'} }
		session      = described_class.new( session_id, session_data )

		session.save( response )

		expect( described_class.sessions ).to include( { session_id => session_data } )
		expect( response.header_data ).to match( /Set-Cookie: #{@cookie_name}=#{session_id}/i )
	end

	it "can remove itself from the store and expire the response's session ID" do
		req          = @request_factory.get( '/hungry/hungry/hippos' )
		response     = req.response
		session_id   = '3422067061a5790be374c81118d9ed3f'
		session_data = { :namespace => {'fruit' => 'bowl'} }
		session      = described_class.new( session_id, session_data )

		session.destroy( response )

		expect( described_class.sessions ).to_not include({ session_id => session_data })
		expect( response.header_data ).to match( /Set-Cookie: #{@cookie_name}=#{session_id}/i )
	end

	describe "with no namespace set (the 'nil' namespace)" do

		subject { Strelka::Session.create('default', 'the_session_id') }

		before( :each ) do
			subject.namespace = nil
		end

		after( :each ) do
			subject.namespace = nil
			subject.clear
		end

		it "accesses the hash of namespaces" do
			subject.namespace = :foo
			subject[:number] = 18
			subject.namespace = 'bar'
			subject[:number] = 28

			subject.namespace = nil

			expect( subject[:foo][:number] ).to eq( 18 )
			expect( subject[:bar][:number] ).to eq( 28 )
		end

		it "accesses namespaces via a struct-like interface" do
			subject.namespace = :meat
			subject.testkey = true
			subject.namespace = :greet
			subject.testkey = true
			subject.namespace = nil

			expect( subject.meat[ :testkey ] ).to be_true
			expect( subject.greet[ :testkey ] ).to be_true
			expect( subject.pork[ :testkey ] ).to be_nil
		end
	end


	describe "with a namespace set" do

		subject { Strelka::Session.create('default', 'the_session_id') }

		before( :each ) do
			subject.namespace = :meat
		end

		after( :each ) do
			subject.namespace = nil
			subject.clear
		end

		it "accesses the namespaced hash" do
			subject[:number] = 18
			subject[:not_a_number] = 'woo'

			expect( subject[:number] ).to eq( 18 )
			expect( subject[:not_a_number] ).to eq( 'woo' )
		end

		it "accesses values via a struct-like interface" do
			subject.testkey = true

			expect( subject.testkey ).to be_true
			expect( subject.i_do_not_exist ).to be_nil
		end
	end

end

