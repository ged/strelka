#!/usr/bin/env ruby
#encoding: utf-8

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent

	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
}

require 'rspec'
require 'spec/lib/helpers'
require 'strelka/httpresponse'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::HTTPResponse do

	before( :all ) do
		setup_logging( :fatal )
		@request_factory = Mongrel2::RequestFactory.new( route: '/glossary' )
	end

	before( :each ) do
		@res = @request_factory.get( '/glossary/reduct' ).response
	end

	after( :all ) do
		reset_logging()
	end


	it "adds a charset to the response's content-type header if one is explicitly set" do
		@res.content_type = 'text/html'
		@res.charset = Encoding::UTF_8

		@res.header_data.should =~ %r{Content-type: text/html; charset=UTF-8}i
	end

	it "replaces the existing content-type header charset if one is explicitly set" do
		@res.content_type = 'text/html; charset=iso-8859-1'
		@res.charset = Encoding::UTF_8

		@res.header_data.should =~ /charset=UTF-8/i
		@res.header_data.should_not =~ /charset=iso-8859-1/
	end

	it "adds a charset to the response's content-type header based on the entity body's encoding " +
	   "if there isn't already one set on the request or the header" do
		@res.body = "Стрелке".encode( 'koi8-r' )
		@res.content_type = 'text/plain'

		@res.header_data.should =~ /charset=koi8-r/i
	end

	it "adds a charset to the response's content-type header based on the entity body's " +
	   "external encoding if there isn't already one set on the request or the header" do
		@res.body = File.open( __FILE__, 'r:iso-8859-5' )
		@res.content_type = 'text/plain'

		@res.header_data.should =~ /charset=iso-8859-5/i
	end

	it "doesn't replace a charset in the content-type header with one based on the entity body" do
		@res.body = "Стрелке".encode( 'iso-8859-5' )
		@res.content_type = 'text/plain; charset=utf-8'

		@res.header_data.should_not =~ /charset=iso-8859-5/i
		@res.header_data.should =~ /charset=utf-8/i
	end

	it "doesn't add a charset to the response's content-type header if it's explicitly set " +
	   "to ASCII-8BIT" do
		@res.content_type = 'text/plain'
		@res.charset = Encoding::ASCII_8BIT

		@res.header_data.should_not =~ /charset/i
	end

	it "strips an existing charset from the response's content-type header if it's explicitly " +
	   "set to ASCII-8BIT" do
		@res.content_type = 'text/plain; charset=ISO-8859-15'
		@res.charset = Encoding::ASCII_8BIT

		@res.header_data.should_not =~ /charset/i
	end


	it "adds a Content-encoding header if there is one encoding" do
		@res.encodings << 'gzip'
		@res.header_data.should =~ /content-encoding: gzip\s*$/i
	end

	it "adds a Content-encoding header if there is more than one encoding" do
		@res.encodings << 'gzip' << 'compress'
		@res.header_data.should =~ /content-encoding: gzip, compress\s*$/i
	end


	it "adds a Content-language header if there is one language" do
		@res.languages << 'de'
		@res.header_data.should =~ /content-language: de\s*$/i
	end

	it "adds a Content-language header if there is more than one language" do
		@res.languages << 'en' << 'sv-chef'
		@res.header_data.should =~ /content-language: en, sv-chef\s*$/i
	end


	it "allows cookies to be set via a Hash-like interface" do
		@res.cookies[:foom] = 'chuckUfarly'
		@res.header_data.should =~ /set-cookie: foom=chuckufarly/i
	end

	it "allows cookies to appended" do
		@res.cookies << Strelka::Cookie.new( 'session', '64a3a92eb7403a8199301e03e8b83810' )
		@res.cookies << Strelka::Cookie.new( 'cn', '18', :expires => '+1d' )
		@res.header_data.should =~ /set-cookie: session=64a3a92eb7403a8199301e03e8b83810/i
		@res.header_data.should =~ /set-cookie: cn=18; expires=/i
	end

end

