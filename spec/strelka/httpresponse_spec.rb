#!/usr/bin/env ruby
#encoding: utf-8

require_relative '../helpers'

require 'rspec'
require 'strelka/httpresponse'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::HTTPResponse do

	before( :all ) do
		@request_factory = Mongrel2::RequestFactory.new( route: '/glossary' )
	end

	before( :each ) do
		@req = @request_factory.get( '/glossary/reduct' )
		@res = @req.response
	end


	it "adds a charset to the response's content-type header if it's text/* and one is explicitly set" do
		@res.content_type = 'text/html'
		@res.charset = Encoding::UTF_8

		expect( @res.header_data ).to match( %r{Content-type: text/html; charset=UTF-8}i )
	end

	it "replaces the existing content-type header charset if it's text/* and one is explicitly set" do
		@res.content_type = 'text/html; charset=iso-8859-1'
		@res.charset = Encoding::UTF_8

		expect( @res.header_data ).to match( /charset=UTF-8/i )
		expect( @res.header_data ).to_not match( /charset=iso-8859-1/ )
	end

	it "adds a charset to the response's content-type header based on the entity body's encoding " +
	   "if it's text/* and there isn't already one set on the request or the header" do
		@res.body = "Стрелке".encode( 'koi8-r' )
		@res.content_type = 'text/plain'

		expect( @res.header_data ).to match( /charset=koi8-r/i )
	end

	it "adds a charset to the response's content-type header based on the entity body's " +
	   "external encoding if it's text/* and there isn't already one set on the request or the header" do
		@res.body = File.open( __FILE__, 'r:iso-8859-5' )
		@res.content_type = 'text/plain'

		expect( @res.header_data ).to match( /charset=iso-8859-5/i )
	end

	it "doesn't replace a charset in a text/* content-type header with one based on the entity body" do
		@res.body = "Стрелке".encode( 'iso-8859-5' )
		@res.content_type = 'text/plain; charset=utf-8'

		expect( @res.header_data ).to_not match( /charset=iso-8859-5/i )
		expect( @res.header_data ).to match( /charset=utf-8/i )
	end

	it "doesn't add a charset to the response's content-type header if it's explicitly set " +
	   "to ASCII-8BIT" do
		@res.content_type = 'text/plain'
		@res.charset = Encoding::ASCII_8BIT

		expect( @res.header_data ).to_not match( /charset/i )
	end

	it "doesn't add a charset to the response's content-type header if it's not text/*" do
		@res.content_type = 'application/octet-stream'
		expect( @res.header_data ).to_not match( /charset/i )
	end

	it "strips an existing charset from the response's content-type header if it's explicitly " +
	   "set to ASCII-8BIT" do
		@res.content_type = 'text/plain; charset=ISO-8859-15'
		@res.charset = Encoding::ASCII_8BIT

		expect( @res.header_data ).to_not match( /charset/i )
	end

	it "doesn't try to add an encoding to a response that doesn't have a content type" do
		@res.content_type = nil
		expect( @res.header_data ).to_not match( /charset/ )
	end

	it "adds a Content-encoding header if there is one encoding" do
		@res.encodings << 'gzip'
		expect( @res.header_data ).to match( /content-encoding: gzip\s*$/i )
	end

	it "adds a Content-encoding header if there is more than one encoding" do
		@res.encodings << 'gzip' << 'compress'
		expect( @res.header_data ).to match( /content-encoding: gzip, compress\s*$/i )
	end


	it "adds a Content-language header if there is one language" do
		@res.languages << 'de'
		expect( @res.header_data ).to match( /content-language: de\s*$/i )
	end

	it "adds a Content-language header if there is more than one language" do
		@res.languages << 'en' << 'sv-chef'
		expect( @res.header_data ).to match( /content-language: en, sv-chef\s*$/i )
	end


	it "allows cookies to be set via a Hash-like interface" do
		@res.cookies[:foom] = 'chuckUfarly'
		expect( @res.header_data ).to match( /set-cookie: foom=chuckufarly/i )
	end

	it "allows cookies to be appended" do
		@res.cookies << Strelka::Cookie.new( 'session', '64a3a92eb7403a8199301e03e8b83810' )
		@res.cookies << Strelka::Cookie.new( 'cn', '18', :expires => '+1d' )
		expect( @res.header_data ).to match( /set-cookie: session=64a3a92eb7403a8199301e03e8b83810/i )
		expect( @res.header_data ).to match( /set-cookie: cn=18; expires=/i )
	end


	it "shares a 'notes' Hash with its associated request" do
		expect( @res.notes ).to be( @req.notes )
	end

end

