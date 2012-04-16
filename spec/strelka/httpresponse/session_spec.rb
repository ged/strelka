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
require 'strelka/httpresponse/session'
require 'strelka/session/default'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::HTTPResponse::Session, "-extended response" do

	before( :all ) do
		setup_logging( :fatal )
		@request_factory = Mongrel2::RequestFactory.new( route: '/service/user' )
		Strelka::App::Sessions.configure( session_class: 'default' )
	end

	before( :each ) do
		@req = @request_factory.get( '/service/user/estark' )
		@req.extend( Strelka::HTTPRequest::Session )
		@res = @req.response
		@res.extend( described_class )
	end

	after( :each ) do
		Strelka::Session::Default.sessions.clear
	end

	after( :all ) do
		reset_logging()
	end


	it "has a session_namespace attribute" do
		@res.should respond_to( :session_namespace )
	end

	it "sets its request's session when its session is set" do
		@res.session = Strelka::Session.create( :default )
		pending "not sure if it should do this or not" do
			@req.session.should be( @res.session )
		end
	end

	context "for a request with no session ID" do

		it "knows that it doesn't have a session" do
			@res.should_not have_session()
		end

		it "doesn't load the session when the session namespace is set" do
			@res.session_namespace = 'an_appid'
			@res.should_not have_session()
		end

		it "creates a new session as soon as it's accessed" do
			@res.session.should be_a( Strelka::Session::Default )
		end

		it "sets its session's namespace when it loads if the session_namespace is set" do
			@res.session_namespace = 'an_appid'
			@res.session.namespace.should == :an_appid
		end


		context "but with a loaded session object" do

			before( :each ) do
				@session = Strelka::Session.create( :default )
				@res.request.session = @session
			end

			it "knows that it has a session" do
				@res.should have_session()
			end

			it "copies the session from its request when accessed" do
				@res.session.should be( @session )
			end

			it "sets the session's namespace when its session_namespace is set" do
				@res.session_namespace = 'the_appid'
				@res.session.namespace.should == :the_appid
			end

		end

	end


	context "for a request with a session ID" do

		before( :each ) do
			@cookie_name = Strelka::Session::Default.cookie_options[ :name ]
			@sess_id = Strelka::Session::Default.get_session_id
			@req.header.cookie = "#{@cookie_name}=#{@sess_id}"
		end

		it "knows that it doesn't have a session unless the ID exists" do
			@res.should_not have_session()
		end


		context "and a corresponding entry in the database" do

			before( :each ) do
				Strelka::Session::Default.sessions[ @sess_id ] = {}
			end

			it "knows that it has a session" do
				@res.should have_session()
			end

			it "saves the session via itself when told to do so" do
				@res.cookies.should_not include( @cookie_name )
				@res.save_session
				@res.cookies[ @cookie_name ].value.should == @sess_id
			end

		end

	end

end
