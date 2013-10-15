# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require_relative '../helpers'

require 'uri'
require 'rspec'
require 'strelka/cookie'
require 'strelka/cookieset'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::CookieSet do

	before( :each ) do
		@cookieset = Strelka::CookieSet.new
	end


	it "delegates some methods to its underlying Set" do
		cookie = Strelka::Cookie.new( 'pants', 'baggy' )

		expect( @cookieset ).to be_empty()
		expect( @cookieset.length ).to eq( 0 )
		expect( @cookieset.member?( cookie ) ).to be_false()
	end

	it "is able to enummerate over each cookie in the set" do
		pants_cookie = Strelka::Cookie.new( 'pants', 'baggy' )
		shirt_cookie = Strelka::Cookie.new( 'shirt', 'pirate' )
		@cookieset << shirt_cookie << pants_cookie

		cookies = []
		@cookieset.each do |cookie|
			cookies << cookie
		end

		expect( cookies.length ).to eq( 2 )
		expect( cookies ).to include( pants_cookie )
		expect( cookies ).to include( shirt_cookie )
	end

	it "is able to add a cookie referenced symbolically" do
		pants_cookie = Strelka::Cookie.new( 'pants', 'denim' )
		@cookieset[:pants] = pants_cookie
		expect( @cookieset['pants'] ).to eq( pants_cookie )
	end


	it "autos-create a cookie for a non-cookie passed to the index setter" do
		@cookieset['bar'] = 'badgerbadgerbadgerbadger'

		expect( @cookieset['bar'] ).to be_an_instance_of( Strelka::Cookie )
		expect( @cookieset['bar'].value ).to eq( 'badgerbadgerbadgerbadger' )
	end

	it "raises an exception if the name of a cookie being set doesn't agree with the key it being set with" do
		pants_cookie = Strelka::Cookie.new( 'pants', 'corduroy' )
		expect { @cookieset['shirt'] = pants_cookie }.to raise_error( ArgumentError )
	end

	it "implements Enumerable" do
		Enumerable.instance_methods( false ).each do |meth|
			expect( @cookieset ).to respond_to( meth )
		end
	end

	it "is able to set a cookie's value symbolically to something other than a String" do
		@cookieset[:wof] = Digest::MD5.hexdigest( Time.now.to_s )
	end

	it "is able to set a cookie with a Symbol key" do
		@cookieset[:wof] = Strelka::Cookie.new( :wof, "something" )
	end


	describe "created with an Array of cookies" do
		it "should flatten the array" do
			cookie_array = []
			cookie_array << Strelka::Cookie.new( 'foo', 'bar' )
			cookie_array << [Strelka::Cookie.new( 'shmoop', 'torgo!' )]

			cookieset = Strelka::CookieSet.new( cookie_array )

			expect( cookieset.length ).to eq( 2 )
		end
	end


	describe "with a 'foo' cookie" do
		before(:each) do
			@cookie = Strelka::Cookie.new( 'foo', 'bar' )
			@cookieset = Strelka::CookieSet.new( @cookie )
		end

		it "contains only one cookie" do
			expect( @cookieset.length ).to eq( 1 )
		end

		it "is able to return the 'foo' Strelka::Cookie via its index operator" do
			expect( @cookieset[ 'foo' ] ).to eq( @cookie )
		end


		it "is able to return the 'foo' Strelka::Cookie via its symbolic name" do
			expect( @cookieset[ :foo ] ).to eq( @cookie )
		end

		it "knows if it includes a cookie named 'foo'" do
			expect( @cookieset ).to include( 'foo' )
		end

		it "knows if it includes a cookie referenced by :foo" do
			expect( @cookieset ).to include( :foo )
		end

		it "knows that it doesn't contain a cookie named 'lollypop'" do
			expect( @cookieset ).to_not include( 'lollypop' )
		end

		it "knows that it includes the 'foo' cookie object" do
			expect( @cookieset ).to include( @cookie )
		end


		it "adds a cookie to the set if it has a different name" do
			new_cookie = Strelka::Cookie.new( 'bar', 'foo' )
			@cookieset << new_cookie

			expect( @cookieset.length ).to eq( 2 )
			expect( @cookieset ).to include( new_cookie )
		end


		it "replaces any existing same-named cookie added via appending" do
			new_cookie = Strelka::Cookie.new( 'foo', 'giant scallops of doom' )
			@cookieset << new_cookie

			expect( @cookieset.length ).to eq( 1 )
			expect( @cookieset ).to include( new_cookie )
			expect( @cookieset['foo'] ).to equal( new_cookie )
		end

		it "replaces any existing same-named cookie set via the index operator" do
			new_cookie = Strelka::Cookie.new( 'foo', 'giant scallops of doom' )
			@cookieset[:foo] = new_cookie

			expect( @cookieset.length ).to eq( 1 )
			expect( @cookieset ).to include( new_cookie )
			expect( @cookieset['foo'] ).to equal( new_cookie )
		end

	end

end

# vim: set nosta noet ts=4 sw=4:
