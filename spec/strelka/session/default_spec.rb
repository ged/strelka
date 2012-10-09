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
		original[:foom].should == {}
	end


	it "can be configured to store its session ID in a different cookie" do
		described_class.configure( :cookie_name => 'buh-mahlon' )
		described_class.cookie_name.should == 'buh-mahlon'
	end

	it "can load sessions from and save sessions to its in-memory store" do
		session_data = { :namespace => {'the' => 'stuff'} }
		described_class.save_session_data( 'the_key', session_data )

		loaded = described_class.load_session_data( 'the_key' )
		loaded.should_not equal( session_data )
		loaded.should == session_data
	end

	it "generates a session-id if one isn't available in the request" do
		req = @request_factory.get( '/hungry/what-is-in-a-fruit-bowl?' )
		described_class.get_session_id( req ).should =~ /^[[:xdigit:]]+$/
	end

	it "rejects invalid session-ids" do
		session_cookie = "%s=gibberish" % [ @cookie_name ]
		req = @request_factory.get( '/hungry/what-is-in-a-fruit-bowl?', :cookie => session_cookie )
		described_class.get_session_id( req ).should =~ /^[[:xdigit:]]+$/
	end

	it "accepts and reuses an existing valid session-id" do
		session_id = '3422067061a5790be374c81118d9ed3f'
		session_cookie = "%s=%s" % [ @cookie_name, session_id ]
		req = @request_factory.get( '/hungry/what-is-in-a-fruit-bowl?', :cookie => session_cookie )
		described_class.get_session_id( req ).should == session_id
	end

	it "knows that a request has a session if it has a cookie with an existing session id" do
		session_id = '3422067061a5790be374c81118d9ed3f'
		described_class.sessions[ session_id ] = {}
		session_cookie = "%s=%s" % [ @cookie_name, session_id ]
		req = @request_factory.get( '/hungry/what-is-in-a-fruit-bowl?', :cookie => session_cookie )
		described_class.should have_session_for( req )
	end

	it "can save itself to the store and set the response's session ID" do
		req          = @request_factory.get( '/hungry/hungry/hippos' )
		response     = req.response
		session_id   = '3422067061a5790be374c81118d9ed3f'
		session_data = { :namespace => {'fruit' => 'bowl'} }
		session      = described_class.new( session_id, session_data )

		session.save( response )

		described_class.sessions.should == { session_id => session_data }
		response.header_data.should =~ /Set-Cookie: #{@cookie_name}=#{session_id}/i
	end

	it "can remove itself from the store and expire the response's session ID" do
		req          = @request_factory.get( '/hungry/hungry/hippos' )
		response     = req.response
		session_id   = '3422067061a5790be374c81118d9ed3f'
		session_data = { :namespace => {'fruit' => 'bowl'} }
		session      = described_class.new( session_id, session_data )

		session.destroy( response )

		described_class.sessions.should_not include({ session_id => session_data })
		response.header_data.should =~ /Set-Cookie: #{@cookie_name}=#{session_id}/i
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

			subject[:foo][:number].should == 18
			subject[:bar][:number].should == 28
		end

		it "accesses namespaces via a struct-like interface" do
			subject.namespace = :meat
			subject.testkey = true
			subject.namespace = :greet
			subject.testkey = true
			subject.namespace = nil

			subject.meat[ :testkey ].should be_true
			subject.greet[ :testkey ].should be_true
			subject.pork[ :testkey ].should be_nil
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

			subject[:number].should == 18
			subject[:not_a_number].should == 'woo'
		end

		it "accesses values via a struct-like interface" do
			subject.testkey = true

			subject.testkey.should be_true
			subject.i_do_not_exist.should be_nil
		end
	end

end

