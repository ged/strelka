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
		result[:a].should be_a( Strelka::Cookie )
		result[:a].name.should == 'a'
		result[:a].value.should == 'b'
	end

	it "parses a cookie header field with an empty value as a cookie with a nil value" do
		result = Strelka::Cookie.parse( 'a=' )

		result.should have( 1 ).member
		result[:a].should be_a( Strelka::Cookie )
		result[:a].name.should == 'a'
		result[:a].value.should be_nil()
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

		it "stringifies with a version number if its version is set to something other than 0" do
			@cookie.version = 1
			@cookie.to_s.should =~ /; Version=1/i
		end

		it "stringifies with a domain if one is set" do
			@cookie.domain = 'example.com'
			@cookie.to_s.should =~ /; Domain=example.com/
		end

		it "stringifies with the leading '.' in the domain" do
			@cookie.domain = '.example.com'
			@cookie.to_s.should =~ /; Domain=example.com/
		end

		it "doesn't stringify with a domain if it is reset" do
			@cookie.domain = 'example.com'
			@cookie.domain = nil
			@cookie.to_s.should_not =~ /; Domain=/
		end

		it "raises an exception if the cookie value would be invalid when serialized" do
			expect {
				@cookie.value = %{"modern technology"; ain't it a paradox?}
			}.to raise_error( Strelka::CookieError, /invalid cookie value/i )
		end

		it "provides a convenience mechanism for setting the value to binary data" do
			@cookie.binary_value = %{"modern technology"; ain't it a paradox?}
			@cookie.to_s.should == 'by_rickirac=Im1vZGVybiB0ZWNobm9sb2d5IjsgYWluJ3Qg' +
				'aXQgYSBwYXJhZG94Pw=='
		end

		it "stringifies with an expires date if one is set" do
			@cookie.expires = Time.at( 1331761184 )
			@cookie.to_s.should == 'by_rickirac=9917eb; Expires=Wed, 14 Mar 2012 21:39:44 GMT'
		end

		it "stringifies with a max age if the 'max age' is set" do
			@cookie.max_age = 3600
			@cookie.to_s.should == 'by_rickirac=9917eb; Max-age=3600'
		end

		it "stringifies with a Secure flag if secure is set" do
			@cookie.secure = true
			@cookie.to_s.should =~ /; Secure/i
		end

		it "stringifies with an HttpOnly flag if httponly is set" do
			@cookie.httponly = true
			@cookie.to_s.should =~ /; HttpOnly/i
		end

		it "stringifies with both Secure and HttpOnly flags if they're both set" do
			@cookie.httponly = true
			@cookie.secure = true
			@cookie.to_s.should =~ /; HttpOnly/i
			@cookie.to_s.should =~ /; Secure/i
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

		it "can return its options as a Hash" do
			@cookie.domain = '.example.com'
			@cookie.secure = true

			@cookie.options.should == {
				domain:   'example.com',
				path:     nil,
				secure:   true,
				httponly: false,
				expires:  nil,
				max_age:  nil,
				version:  0,
			}
		end

	end


end

