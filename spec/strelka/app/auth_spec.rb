#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent.parent
	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
}

require 'rspec'

require 'spec/lib/helpers'

require 'strelka'
require 'strelka/app/plugins'
require 'strelka/app/auth'
require 'strelka/authprovider'

require 'strelka/behavior/plugin'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::App::Auth do

	before( :all ) do
		setup_logging( :fatal )
		@request_factory = Mongrel2::RequestFactory.new( route: '/api/v1' )
	end

	after( :all ) do
		reset_logging()
	end


	it_should_behave_like( "A Strelka::App Plugin" )


	it "has an associated authentication system plugin" do
		Strelka::App::Auth.auth_type.should be_a( Strelka::AuthProvider )
	end

end

