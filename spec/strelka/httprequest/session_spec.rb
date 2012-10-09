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
require 'strelka/app/sessions'
require 'strelka/httprequest/session'
require 'strelka/session/default'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::HTTPRequest::Session, "-extended request" do

	before( :all ) do
		setup_logging( :fatal )
		@request_factory = Mongrel2::RequestFactory.new( route: '/service/user' )
		Strelka::App::Sessions.configure( session_class: 'default' )
	end

	before( :each ) do
		@req = @request_factory.get( '/service/user/estark' )
		@req.extend( described_class )
	end

	after( :each ) do
		Strelka::Session::Default.sessions.clear
	end

	after( :all ) do
		reset_logging()
	end


	it "has a session_namespace attribute" do
		@req.should respond_to( :session_namespace )
	end


	context "with no session ID" do

		it "knows that it doesn't have a session" do
			@req.should_not have_session()
		end

		it "doesn't load the session when the session namespace is set" do
			@req.session_namespace = 'an_appid'
			@req.should_not have_session()
		end

		it "creates a new session as soon as it's accessed" do
			@req.session.should be_a( Strelka::Session::Default )
		end

		it "sets its session's namespace when it loads if the session_namespace is set" do
			@req.session_namespace = 'an_appid'
			@req.session.namespace.should == :an_appid
		end


		context "but with a loaded session object" do

			before( :each ) do
				@session = Strelka::Session.create( :default )
				@req.session = @session
			end

			it "knows that it has a session" do
				@req.should have_session()
			end

			it "sets the session's namespace when its session_namespace is set" do
				@req.session_namespace = 'the_appid'
				@session.namespace.should == :the_appid
			end
		end

	end


	context "with a session ID" do

		before( :each ) do
			@sess_id = Strelka::Session::Default.get_session_id
		end

		it "knows that it doesn't have a session unless the ID exists" do
			@req.should_not have_session()
		end


		context "and a corresponding entry in the database" do

			before( :each ) do
				Strelka::Session::Default.sessions[ @sess_id ] = {}
			end

			it "knows that it has a session" do
				cookie_name = Strelka::Session::Default.cookie_name
				@req.header.cookie = "#{cookie_name}=#{@sess_id}"
				@req.should have_session()
			end

			it "knows when its session hasn't been loaded" do
				@req.session_loaded?.should be_false()
			end

			it "knows when its session has been loaded" do
				@req.session # Load it
				@req.session_loaded?.should be_true()
			end

		end

	end

end
