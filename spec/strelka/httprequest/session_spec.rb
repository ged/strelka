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

describe Strelka::HTTPRequest::Session do

	before( :all ) do
		setup_logging( :fatal )
		@request_factory = Mongrel2::RequestFactory.new( route: '/service/user' )
		Strelka::App::Sessions.configure( session_class: 'default' )
	end

	before( :each ) do
		@req = @request_factory.get( '/service/user/estark' )
		Strelka.log.debug "Extending request %p" % [ @req ]
		@req.extend( described_class )
	end

	after( :each ) do
		Strelka::Session::Default.sessions.clear
	end

	after( :all ) do
		reset_logging()
	end


	describe "an HTTPRequest with no session loaded" do

		it "has a session_namespace attribute" do
			@req.should respond_to( :session_namespace )
		end

		it "knows whether or not it has loaded a session" do
			@req.session?.should be_false()
		end

		it "doesn't load the session when the session namespace is set" do
			@req.session_namespace = 'an_appid'
			@req.session?.should be_false()
		end

		it "loads the session as soon as it's accessed" do
			@req.session.should be_a( Strelka::Session::Default )
		end

		it "sets the session's namespace when it's loaded" do
			@req.session_namespace = 'an_appid'
			@req.session.namespace.should == :an_appid
		end

		it "sets a session's namespace when it's set directly" do
			@req.should respond_to( :session_namespace= )
			@req.session_namespace = 'the_appid'

			session = mock( "session object" )
			session.should_receive( :namespace= ).with( 'the_appid' )

			@req.session = session
		end

	end


	describe "an HTTPRequest with a session loaded" do

		before( :each ) do
			@req.session_namespace = 'other_appid'
			@req.session
		end

		it "sets its session's namespace when its session_namespace attribute is set" do
			@req.session.namespace.should == :other_appid
			@req.session_namespace = 'an_appid'
			@req.session.namespace.should == :an_appid
		end

	end

end
