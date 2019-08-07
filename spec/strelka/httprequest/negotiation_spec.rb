# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# frozen-string-literal: true

require_relative '../../helpers'

require 'rspec'

require 'strelka'
require 'strelka/httprequest/negotiation'
require 'strelka/httpresponse/negotiation'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::HTTPRequest::Negotiation do

	before( :all ) do
		@request_factory = Mongrel2::RequestFactory.new( route: '/service/user' )
	end


	before( :each ) do
		@req = @request_factory.get( '/service/user/estark' )
		@req.extend( described_class )
	end


	describe "mediatype negotiation" do

		it "know what content-types are accepted by the client" do
			@req.headers.accept = 'application/x-yaml, application/json; q=0.2, text/xml; q=0.75'

			expect( @req.accepted_types.size ).to eq( 3 )
			expect( @req.accepted_types[0].mediatype ).to eq( 'application/x-yaml' )
			expect( @req.accepted_types[0].qvalue ).to eq( 1.0 )
			expect( @req.accepted_types[1].mediatype ).to eq( 'application/json' )
			expect( @req.accepted_types[1].qvalue ).to eq( 0.2 )
			expect( @req.accepted_types[2].mediatype ).to eq( 'text/xml' )
			expect( @req.accepted_types[2].qvalue ).to eq( 0.75 )
		end

		it "knows what mimetypes are acceptable responses" do
			@req.headers.accept = 'text/html, text/plain; q=0.5, image/*;q=0.1'

			expect( @req.accepts?( 'text/html' ) ).to be_truthy()
			expect( @req.accepts?( 'text/plain' ) ).to be_truthy()
			expect( @req.accepts?( 'text/ascii' ) ).to be_falsey()
			expect( @req.accepts?( 'image/png' ) ).to be_truthy()
			expect( @req.accepts?( 'application/x-yaml' ) ).to be_falsey()
		end

		it "knows what mimetypes are explicitly acceptable responses" do
			@req.headers.accept = 'text/html, text/plain; q=0.5, image/*;q=0.1, */*'

			expect( @req.explicitly_accepts?( 'text/html' ) ).to be_truthy()
			expect( @req.explicitly_accepts?( 'text/plain' ) ).to be_truthy()
			expect( @req.explicitly_accepts?( 'text/ascii' ) ).to be_falsey()
			expect( @req.explicitly_accepts?( 'image/png' ) ).to be_falsey()
			expect( @req.explicitly_accepts?( 'application/x-yaml' ) ).to be_falsey()
		end

		it "accepts anything if the client doesn't provide an Accept header" do
			@req.headers.delete( :accept )

			expect( @req.accepts?( 'text/html' ) ).to be_truthy()
			expect( @req.accepts?( 'text/plain' ) ).to be_truthy()
			expect( @req.accepts?( 'text/ascii' ) ).to be_truthy()
			expect( @req.accepts?( 'image/png' ) ).to be_truthy()
			expect( @req.accepts?( 'application/x-yaml' ) ).to be_truthy()
		end

		it "doesn't explicitly accept anything if the client doesn't provide an Accept header" do
			@req.headers.delete( :accept )

			expect( @req.explicitly_accepts?( 'text/html' ) ).to be_falsey()
			expect( @req.explicitly_accepts?( 'text/plain' ) ).to be_falsey()
			expect( @req.explicitly_accepts?( 'text/ascii' ) ).to be_falsey()
			expect( @req.explicitly_accepts?( 'image/png' ) ).to be_falsey()
			expect( @req.explicitly_accepts?( 'application/x-yaml' ) ).to be_falsey()
		end

		it "finishes with a BAD REQUEST response if the Accept header is malformed" do
			@req.headers.accept = 'text/html, image/gif, image/jpeg, *; q=.2, */*; q=.2'

			expect { @req.accepted_types }.to finish_with( HTTP::BAD_REQUEST, /malformed/i )
		end

	end


	describe "character-set negotiation" do

		it "knows what character sets are accepted by the client" do
			@req.headers.accept_charset = 'iso-8859-5, utf-8;q=0.8'

			expect( @req.accepted_charsets.size ).to eq( 2 )
			expect( @req.accepted_charsets[0].name ).to eq( 'iso-8859-5' )
			expect( @req.accepted_charsets[0].qvalue ).to eq( 1.0 )
			expect( @req.accepted_charsets[1].name ).to eq( 'utf-8' )
			expect( @req.accepted_charsets[1].qvalue ).to eq( 0.8 )
		end

		it "knows what charsets are acceptable responses" do
			@req.headers.accept_charset = 'iso-8859-5, utf-8;q=0.8'

			expect( @req.accepts_charset?( 'iso8859-5' ) ).to be_truthy()
			expect( @req.accepts_charset?( 'iso-8859-5' ) ).to be_truthy()
			expect( @req.accepts_charset?( 'utf-8' ) ).to be_truthy()
			expect( @req.accepts_charset?( Encoding::CP65001 ) ).to be_truthy()
			expect( @req.accepts_charset?( 'mac' ) ).to be_falsey()
			expect( @req.accepts_charset?( Encoding::SJIS ) ).to be_falsey()
		end

		it "accepts any charset if the client doesn't provide an Accept-Charset header" do
			@req.headers.delete( :accept_charset )

			expect( @req.accepts_charset?( 'iso8859-5' ) ).to be_truthy()
			expect( @req.accepts_charset?( 'iso-8859-5' ) ).to be_truthy()
			expect( @req.accepts_charset?( 'utf-8' ) ).to be_truthy()
			expect( @req.accepts_charset?( Encoding::CP65001 ) ).to be_truthy()
			expect( @req.accepts_charset?( 'mac' ) ).to be_truthy()
			expect( @req.accepts_charset?( Encoding::SJIS ) ).to be_truthy()
		end

	end


	describe "content encoding negotiation" do

		it "knows what encodings are accepted by the client" do
			@req.headers.accept_encoding = 'gzip;q=1.0, identity; q=0.5, *;q=0'

			expect( @req.accepted_encodings.size ).to eq( 3 )
			expect( @req.accepted_encodings[0].content_coding ).to eq( 'gzip' )
			expect( @req.accepted_encodings[0].qvalue ).to eq( 1.0 )
			expect( @req.accepted_encodings[1].content_coding ).to eq( 'identity' )
			expect( @req.accepted_encodings[1].qvalue ).to eq( 0.5 )
			expect( @req.accepted_encodings[2].content_coding ).to be_nil()
			expect( @req.accepted_encodings[2].qvalue ).to eq( 0.0 )
		end

		it "knows what encodings are acceptable" do
			@req.headers.accept_encoding = 'gzip;q=1.0, identity; q=0.5, *;q=0'

			expect( @req.accepts_encoding?( 'gzip' ) ).to be_truthy()
			expect( @req.accepts_encoding?( 'identity' ) ).to be_truthy()
			expect( @req.accepts_encoding?( 'compress' ) ).to be_falsey()
		end

		it "knows that the identity encoding is acceptable if it isn't disabled" do
			@req.headers.accept_encoding = 'gzip;q=1.0, compress; q=0.5'

			expect( @req.accepts_encoding?( 'gzip' ) ).to be_truthy()
			expect( @req.accepts_encoding?( 'identity' ) ).to be_truthy()
			expect( @req.accepts_encoding?( 'compress' ) ).to be_truthy()
			expect( @req.accepts_encoding?( 'clowns' ) ).to be_falsey()
		end

		it "accepts only the 'identity' encoding if the Accept-Encoding field is empty" do
			@req.headers.accept_encoding = ''

			expect( @req.accepts_encoding?( 'identity' ) ).to be_truthy()
			expect( @req.accepts_encoding?( 'gzip' ) ).to be_falsey()
			expect( @req.accepts_encoding?( 'compress' ) ).to be_falsey()
		end

		it "doesn't accept the 'identity' encoding if the Accept-Encoding field explicitly disables it" do
			@req.headers.accept_encoding = 'gzip;q=0.5, identity;q=0'

			expect( @req.accepts_encoding?( 'identity' ) ).to be_falsey()
			expect( @req.accepts_encoding?( 'gzip' ) ).to be_truthy()
			expect( @req.accepts_encoding?( 'compress' ) ).to be_falsey()
		end

		it "doesn't accept the 'identity' encoding if the Accept-Encoding field has a wildcard " +
		   "with q-value of 0 and doesn't explicitly include 'identity'" do
			@req.headers.accept_encoding = 'gzip;q=0.5, *;q=0'

			expect( @req.accepts_encoding?( 'identity' ) ).to be_falsey()
			expect( @req.accepts_encoding?( 'gzip' ) ).to be_truthy()
			expect( @req.accepts_encoding?( 'compress' ) ).to be_falsey()
		end

		it "accepts every encoding if the request doesn't have an Accept-Encoding header" do
			@req.headers.delete( :accept_encoding )

			expect( @req.accepts_encoding?( 'identity' ) ).to be_truthy()
			expect( @req.accepts_encoding?( 'gzip' ) ).to be_truthy()
			expect( @req.accepts_encoding?( 'compress' ) ).to be_truthy()
		end

	end


	describe "natural language negotiation" do

		it "knows what languages are accepted by the client" do
			@req.headers.accept_language = 'da, en-gb;q=0.8, en;q=0.7'

			expect( @req.accepted_languages.size ).to eq( 3 )
			expect( @req.accepted_languages[0].primary_tag ).to eq( 'da' )
			expect( @req.accepted_languages[0].subtag ).to eq( nil )
			expect( @req.accepted_languages[0].qvalue ).to eq( 1.0 )
			expect( @req.accepted_languages[1].primary_tag ).to eq( 'en' )
			expect( @req.accepted_languages[1].subtag ).to eq( 'gb' )
			expect( @req.accepted_languages[1].qvalue ).to eq( 0.8 )
			expect( @req.accepted_languages[2].primary_tag ).to eq( 'en' )
			expect( @req.accepted_languages[2].subtag ).to eq( nil )
			expect( @req.accepted_languages[2].qvalue ).to eq( 0.7 )
		end

		it "knows what languages may be used in acceptable responses" do
			@req.headers.accept_language = 'da, en-gb;q=0.8, en;q=0.7'

			expect( @req.accepts_language?( 'da' ) ).to be_truthy()
			expect( @req.accepts_language?( 'en' ) ).to be_truthy()
			expect( @req.accepts_language?( 'en-gb' ) ).to be_truthy()
			expect( @req.accepts_language?( 'en-cockney' ) ).to be_truthy()
			expect( @req.accepts_language?( 'de' ) ).to be_falsey()
			expect( @req.accepts_language?( 'tlh' ) ).to be_falsey()
		end

		it "accepts any language if the client doesn't provide an Accept-Language header" do
			@req.headers.delete( :accept_language )

			expect( @req.accepts_language?( 'da' ) ).to be_truthy()
			expect( @req.accepts_language?( 'en' ) ).to be_truthy()
			expect( @req.accepts_language?( 'en-gb' ) ).to be_truthy()
			expect( @req.accepts_language?( 'en-cockney' ) ).to be_truthy()
			expect( @req.accepts_language?( 'de' ) ).to be_truthy()
			expect( @req.accepts_language?( 'tlh' ) ).to be_truthy()
		end

	end

end