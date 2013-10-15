# -*- rspec -*-
# vim: set nosta noet ts=4 sw=4:

require_relative '../../helpers'

require 'rspec'

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
		expect( @res ).to respond_to( :session_namespace )
	end

	it "sets its request's session when its session is set" do
		@res.session = Strelka::Session.create( :default )
		pending "not sure if it should do this or not" do
			expect( @req.session ).to be( @res.session )
		end
	end

	context "for a request with no session ID" do

		it "knows that it doesn't have a session" do
			expect( @res ).to_not have_session()
		end

		it "doesn't load the session when the session namespace is set" do
			@res.session_namespace = 'an_appid'
			expect( @res ).to_not have_session()
		end

		it "creates a new session as soon as it's accessed" do
			expect( @res.session ).to be_a( Strelka::Session::Default )
		end

		it "sets its session's namespace when it loads if the session_namespace is set" do
			@res.session_namespace = 'an_appid'
			expect( @res.session.namespace ).to eq( :an_appid )
		end


		context "but with a loaded session object" do

			before( :each ) do
				@session = Strelka::Session.create( :default )
				@res.request.session = @session
			end

			it "knows that it has a session" do
				expect( @res ).to have_session()
			end

			it "copies the session from its request when accessed" do
				expect( @res.session ).to be( @session )
			end

			it "sets the session's namespace when its session_namespace is set" do
				@res.session_namespace = 'the_appid'
				expect( @res.session.namespace ).to eq( :the_appid )
			end

		end

	end


	context "for a request with a session ID" do

		before( :each ) do
			@cookie_name = Strelka::Session::Default.cookie_name
			@sess_id = Strelka::Session::Default.get_session_id
			@req.header.cookie = "#{@cookie_name}=#{@sess_id}"
		end

		it "knows that it doesn't have a session unless the ID exists" do
			expect( @res ).to_not have_session()
		end


		context "and a corresponding entry in the database" do

			before( :each ) do
				Strelka::Session::Default.sessions[ @sess_id ] = {}
			end

			it "knows that it has a session" do
				expect( @res ).to have_session()
			end

			it "knows that its session has been loaded if it has one" do
				@res.session
				expect( @res.session_loaded? ).to be_true()
			end

			it "knows that its session has been loaded if its request has one" do
				@res.request.session
				expect( @res.session_loaded? ).to be_true()
			end

			it "knows that its session hasn't been loaded if neither its request not itself has one" do
				expect( @res.session_loaded? ).to be_false()
			end

			it "saves the session via itself if it was loaded" do
				expect( @res.cookies ).to_not include( @cookie_name )
				@res.session
				@res.save_session
				expect( @res.cookies[ @cookie_name ].value ).to eq( @sess_id )
			end

			it "doesn't save the session via itself if it wasn't loaded" do
				expect( @res.cookies ).to_not include( @cookie_name )
				@res.save_session
				expect( @res.cookies ).to be_empty()
			end

			it "destroys the session via itself if it was loaded" do
				expect( @res.cookies ).to_not include( @cookie_name )
				@res.session
				@res.destroy_session
				expect( @res.cookies[ @cookie_name ].value ).to eq( @sess_id )
				expect( @res.cookies[ @cookie_name ].expires ).to be < Time.now
			end

			it "destroys the session via itself even if it wasn't loaded" do
				expect( @res.cookies ).to_not include( @cookie_name )
				@res.destroy_session
				expect( @res.cookies[ @cookie_name ].value ).to eq( @sess_id )
				expect( @res.cookies[ @cookie_name ].expires ).to be < Time.now
			end

		end

	end

end
