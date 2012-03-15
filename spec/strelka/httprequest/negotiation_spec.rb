# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

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
require 'strelka/httprequest/negotiation'
require 'strelka/httpresponse/negotiation'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::HTTPRequest::Negotiation do

	before( :all ) do
		setup_logging( :fatal )
		@request_factory = Mongrel2::RequestFactory.new( route: '/service/user' )
	end

	after( :all ) do
		reset_logging()
	end


	before( :each ) do
		@req = @request_factory.get( '/service/user/estark' )
		@req.extend( described_class )
	end


	describe "mediatype negotiation" do

		it "know what content-types are accepted by the client" do
			@req.headers.accept = 'application/x-yaml, application/json; q=0.2, text/xml; q=0.75'

			@req.accepted_types.should have(3).members
			@req.accepted_types[0].mediatype.should == 'application/x-yaml'
			@req.accepted_types[0].qvalue.should == 1.0
			@req.accepted_types[1].mediatype.should == 'application/json'
			@req.accepted_types[1].qvalue.should == 0.2
			@req.accepted_types[2].mediatype.should == 'text/xml'
			@req.accepted_types[2].qvalue.should == 0.75
		end

		it "knows what mimetypes are acceptable responses" do
			@req.headers.accept = 'text/html, text/plain; q=0.5, image/*;q=0.1'

			@req.accepts?( 'text/html' ).should be_true()
			@req.accepts?( 'text/plain' ).should be_true()
			@req.accepts?( 'text/ascii' ).should be_false()
			@req.accepts?( 'image/png' ).should be_true()
			@req.accepts?( 'application/x-yaml' ).should be_false()
		end

		it "knows what mimetypes are explicitly acceptable responses" do
			@req.headers.accept = 'text/html, text/plain; q=0.5, image/*;q=0.1, */*'

			@req.explicitly_accepts?( 'text/html' ).should be_true()
			@req.explicitly_accepts?( 'text/plain' ).should be_true()
			@req.explicitly_accepts?( 'text/ascii' ).should be_false()
			@req.explicitly_accepts?( 'image/png' ).should be_false()
			@req.explicitly_accepts?( 'application/x-yaml' ).should be_false()
		end

		it "accepts anything if the client doesn't provide an Accept header" do
			@req.headers.delete( :accept )

			@req.accepts?( 'text/html' ).should be_true()
			@req.accepts?( 'text/plain' ).should be_true()
			@req.accepts?( 'text/ascii' ).should be_true()
			@req.accepts?( 'image/png' ).should be_true()
			@req.accepts?( 'application/x-yaml' ).should be_true()
		end

		it "doesn't explicitly accept anything if the client doesn't provide an Accept header" do
			@req.headers.delete( :accept )

			@req.explicitly_accepts?( 'text/html' ).should be_false()
			@req.explicitly_accepts?( 'text/plain' ).should be_false()
			@req.explicitly_accepts?( 'text/ascii' ).should be_false()
			@req.explicitly_accepts?( 'image/png' ).should be_false()
			@req.explicitly_accepts?( 'application/x-yaml' ).should be_false()
		end

	end


	describe "character-set negotiation" do

		it "knows what character sets are accepted by the client" do
			@req.headers.accept_charset = 'iso-8859-5, utf-8;q=0.8'

			@req.accepted_charsets.should have(2).members
			@req.accepted_charsets[0].name.should == 'iso-8859-5'
			@req.accepted_charsets[0].qvalue.should == 1.0
			@req.accepted_charsets[1].name.should == 'utf-8'
			@req.accepted_charsets[1].qvalue.should == 0.8
		end

		it "knows what charsets are acceptable responses" do
			@req.headers.accept_charset = 'iso-8859-5, utf-8;q=0.8'

			@req.accepts_charset?( 'iso8859-5' ).should be_true()
			@req.accepts_charset?( 'iso-8859-5' ).should be_true()
			@req.accepts_charset?( 'utf-8' ).should be_true()
			@req.accepts_charset?( Encoding::CP65001 ).should be_true()
			@req.accepts_charset?( 'mac' ).should be_false()
			@req.accepts_charset?( Encoding::SJIS ).should be_false()
		end

		it "accepts any charset if the client doesn't provide an Accept-Charset header" do
			@req.headers.delete( :accept_charset )

			@req.accepts_charset?( 'iso8859-5' ).should be_true()
			@req.accepts_charset?( 'iso-8859-5' ).should be_true()
			@req.accepts_charset?( 'utf-8' ).should be_true()
			@req.accepts_charset?( Encoding::CP65001 ).should be_true()
			@req.accepts_charset?( 'mac' ).should be_true()
			@req.accepts_charset?( Encoding::SJIS ).should be_true()
		end

	end


	describe "content encoding negotiation" do

		it "knows what encodings are accepted by the client" do
			@req.headers.accept_encoding = 'gzip;q=1.0, identity; q=0.5, *;q=0'

			@req.accepted_encodings.should have(3).members
			@req.accepted_encodings[0].content_coding.should == 'gzip'
			@req.accepted_encodings[0].qvalue.should == 1.0
			@req.accepted_encodings[1].content_coding.should == 'identity'
			@req.accepted_encodings[1].qvalue.should == 0.5
			@req.accepted_encodings[2].content_coding.should be_nil()
			@req.accepted_encodings[2].qvalue.should == 0.0
		end

		it "knows what encodings are acceptable" do
			@req.headers.accept_encoding = 'gzip;q=1.0, identity; q=0.5, *;q=0'

			@req.accepts_encoding?( 'gzip' ).should be_true()
			@req.accepts_encoding?( 'identity' ).should be_true()
			@req.accepts_encoding?( 'compress' ).should be_false()
		end

		it "knows that the identity encoding is acceptable if it isn't disabled" do
			@req.headers.accept_encoding = 'gzip;q=1.0, compress; q=0.5'

			@req.accepts_encoding?( 'gzip' ).should be_true()
			@req.accepts_encoding?( 'identity' ).should be_true()
			@req.accepts_encoding?( 'compress' ).should be_true()
			@req.accepts_encoding?( 'clowns' ).should be_false()
		end

		it "accepts only the 'identity' encoding if the Accept-Encoding field is empty" do
			@req.headers.accept_encoding = ''

			@req.accepts_encoding?( 'identity' ).should be_true()
			@req.accepts_encoding?( 'gzip' ).should be_false()
			@req.accepts_encoding?( 'compress' ).should be_false()
		end

		it "doesn't accept the 'identity' encoding if the Accept-Encoding field explicitly disables it" do
			@req.headers.accept_encoding = 'gzip;q=0.5, identity;q=0'

			@req.accepts_encoding?( 'identity' ).should be_false()
			@req.accepts_encoding?( 'gzip' ).should be_true()
			@req.accepts_encoding?( 'compress' ).should be_false()
		end

		it "doesn't accept the 'identity' encoding if the Accept-Encoding field has a wildcard " +
		   "with q-value of 0 and doesn't explicitly include 'identity'" do
			@req.headers.accept_encoding = 'gzip;q=0.5, *;q=0'

			@req.accepts_encoding?( 'identity' ).should be_false()
			@req.accepts_encoding?( 'gzip' ).should be_true()
			@req.accepts_encoding?( 'compress' ).should be_false()
		end

		it "accepts every encoding if the request doesn't have an Accept-Encoding header" do
			@req.headers.delete( :accept_encoding )

			@req.accepts_encoding?( 'identity' ).should be_true()
			@req.accepts_encoding?( 'gzip' ).should be_true()
			@req.accepts_encoding?( 'compress' ).should be_true()
		end

	end


	describe "natural language negotiation" do

		it "knows what languages are accepted by the client" do
			@req.headers.accept_language = 'da, en-gb;q=0.8, en;q=0.7'

			@req.accepted_languages.should have(3).members
			@req.accepted_languages[0].primary_tag.should == 'da'
			@req.accepted_languages[0].subtag.should == nil
			@req.accepted_languages[0].qvalue.should == 1.0
			@req.accepted_languages[1].primary_tag.should == 'en'
			@req.accepted_languages[1].subtag.should == 'gb'
			@req.accepted_languages[1].qvalue.should == 0.8
			@req.accepted_languages[2].primary_tag.should == 'en'
			@req.accepted_languages[2].subtag.should == nil
			@req.accepted_languages[2].qvalue.should == 0.7
		end

		it "knows what languages may be used in acceptable responses" do
			@req.headers.accept_language = 'da, en-gb;q=0.8, en;q=0.7'

			@req.accepts_language?( 'da' ).should be_true()
			@req.accepts_language?( 'en' ).should be_true()
			@req.accepts_language?( 'en-gb' ).should be_true()
			@req.accepts_language?( 'en-cockney' ).should be_true()
			@req.accepts_language?( 'de' ).should be_false()
			@req.accepts_language?( 'tlh' ).should be_false()
		end

		it "accepts any language if the client doesn't provide an Accept-Language header" do
			@req.headers.delete( :accept_language )

			@req.accepts_language?( 'da' ).should be_true()
			@req.accepts_language?( 'en' ).should be_true()
			@req.accepts_language?( 'en-gb' ).should be_true()
			@req.accepts_language?( 'en-cockney' ).should be_true()
			@req.accepts_language?( 'de' ).should be_true()
			@req.accepts_language?( 'tlh' ).should be_true()
		end

	end

end