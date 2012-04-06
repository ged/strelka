# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent

	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
}

require 'uri'
require 'rspec'
require 'spec/lib/helpers'
require 'strelka/cookie'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::Cookie do

	before( :all ) do
		setup_logging( :fatal )
	end

	after( :all ) do
		reset_logging()
	end

	it "parses a 'nil' Cookie header field as an empty Hash" do
		Strelka::Cookie.parse( nil ).should == {}
	end

	it "parses an empty string Cookie header field as an empty Hash" do
		Strelka::Cookie.parse( '' ).should == {}
	end

	it "parses a cookie header field with a single value as a cookie with a single value" do
		result = Strelka::Cookie.parse( 'a=b' )

		result.should be_a( Hash )
		result.should have(1).member
		result['a'].should be_a( Strelka::Cookie )
		result['a'].name.should == 'a'
		result['a'].value.should == 'b'
		result['a'].values.should == ['b']
	end

	it "parses a cookie header field with a cookie with multiple values as a cookie with multiple values" do
		result = Strelka::Cookie.parse( 'a=b&c' )

		result.should be_a( Hash )
		result.should have(1).member
		result['a'].should be_a( Strelka::Cookie )
		result['a'].name.should == 'a'
		result['a'].value.should == 'b'
		result['a'].values.should == ['b', 'c']
	end

	it "parses a cookie header field with multiple cookies and multiple values correctly" do
		result = Strelka::Cookie.parse( 'a=b&c; f=o&o' )

		result.should be_a( Hash )
		result.should have(2).members

		result['a'].should be_a( Strelka::Cookie )
		result['a'].name.should == 'a'
		result['a'].value.should == 'b'
		result['a'].values.should == ['b', 'c']

		result['f'].should be_a( Strelka::Cookie )
		result['f'].name.should == 'f'
		result['f'].value.should == 'o'
		result['f'].values.should == ['o', 'o']
	end

	it "parses a cookie header field with an empty value as a cookie with a nil value" do
		result = Strelka::Cookie.parse( 'a=' )

		result.should have( 1 ).member
		result['a'].should be_a( Strelka::Cookie )
		result['a'].name.should == 'a'
		result['a'].value.should be_nil()
		result['a'].values.should == []
	end

	it "parses a cookie header field with a version as a cookie with a version" do
		result = Strelka::Cookie.parse( %{$Version=1; a="b"} )

		result.should be_a( Hash )
		result.should have( 1 ).member

		result['a'].should be_a( Strelka::Cookie )
		result['a'].name.should == 'a'
		result['a'].value.should == 'b'
		result['a'].values.should == ['b']
		result['a'].version.should == 1
	end

	it "parses a cookie header field with a path as a cookie with a path" do
		result = Strelka::Cookie.parse( %{a=b; $Path=/Strelka} )

		result.should be_a( Hash )
		result.should have( 1 ).member

		result['a'].should be_a( Strelka::Cookie )
		result['a'].name.should == 'a'
		result['a'].value.should == 'b'
		result['a'].values.should == ['b']

		result['a'].path.should == "/Strelka"
	end

	it "parses a cookie header field with a domain as a cookie with a domain" do
		result = Strelka::Cookie.parse( %{a=b; $domain=rubycrafters.com} )

		result.should be_a( Hash )
		result.should have( 1 ).member

		result['a'].should be_a( Strelka::Cookie )
		result['a'].name.should == 'a'
		result['a'].value.should == 'b'
		result['a'].values.should == ['b']

		result['a'].domain.should == '.rubycrafters.com'
	end

	it "doesn't raise an error if asked to parse an invalid cookie header" do
		result = Strelka::Cookie.parse( "{a}=foo" )
		result.should == {}
	end


	context "instance" do

		before( :each ) do
			@cookie = Strelka::Cookie.new( :by_rickirac, '9917eb' )
		end

		it "stringifies as a valid header value" do
			@cookie.to_s.should == 'by_rickirac=9917eb'
		end

		it "still stringifies correctly with two values" do
			@cookie.values += ['brer lapin']
			@cookie.to_s.should == "by_rickirac=9917eb&brer+lapin"
		end

		it "stringifies with a version number if its version is set to something other than 0" do
			@cookie.version = 1
			@cookie.to_s.should == %{by_rickirac=9917eb; Version=1}
		end

		it "stringifies with a domain if one is set" do
			@cookie.domain = '.example.com'
			@cookie.to_s.should == %{by_rickirac=9917eb; Domain=.example.com}
		end

		it "stringifies with a dot prepended to the domain if the set doesn't have one" do
			@cookie.domain = 'example.com'
			@cookie.to_s.should == %{by_rickirac=9917eb; Domain=.example.com}
		end

		it "stringifies correctly even if one of its values contains a semicolon" do
			@cookie.values += [%{"modern technology"; ain't it a paradox?}]
			@cookie.to_s.should ==
				"by_rickirac=9917eb&%22modern+technology%22%3B+ain%27t+it+a+paradox%3F"
		end

		it "stringifies with an expires date if one is set" do
			@cookie.expires = Time.at( 1331761184 )
			@cookie.to_s.should == 'by_rickirac=9917eb; Expires=Wed, 14 Mar 2012 21:39:44 GMT'
		end

		it "hashes the same as another cookie with the same name, regardless of value" do
			@cookie.hash.should == Strelka::Cookie.new('by_rickirac', 'something_else').hash
		end


		it "sets its expiration time to a time in the past if it's told to expire" do
			@cookie.expire!
			@cookie.expires.should < Time.now
		end

		it "uses the hash of its name as its hash value" do
			@cookie.hash.should == @cookie.name.to_s.hash
		end
	end


end

