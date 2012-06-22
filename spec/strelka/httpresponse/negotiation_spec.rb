#!/usr/bin/env ruby
#encoding: utf-8

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

describe Strelka::HTTPResponse::Negotiation do

	before( :all ) do
		setup_logging( :fatal )
		@request_factory = Mongrel2::RequestFactory.new( route: '/service/user' )
	end

	after( :all ) do
		reset_logging()
	end


	before( :each ) do
		@app = Class.new( Strelka::App ) { plugins :negotiation }
		@app.install_plugins
		@req = @request_factory.get( '/service/user/estark' )
		@res = @req.response
	end


	describe "content-alternative callback methods" do

		it "can provide blocks for bodies of several different mediatypes" do
			@req.headers.accept = 'application/x-yaml, application/json; q=0.7, text/xml; q=0.2'

			@res.for( 'application/json' ) { %{["a JSON dump"]} }
			@res.for( 'application/x-yaml' ) { "---\na: YAML dump\n\n" }

			@res.negotiated_body.rewind
			@res.negotiated_body.read.should == "---\na: YAML dump\n\n"
			@res.content_type.should == "application/x-yaml"
			@res.header_data.should =~ /accept(?!-)/i
		end

		it "can provide a single block for bodies of several different mediatypes" do
			@req.headers.accept = 'application/x-yaml; q=0.7, application/json; q=0.9'

			@res.for( 'application/json', 'application/x-yaml' ) do
				{ uuid: 'fc85e35b-c9c3-4675-a882-25bf98d11e1b', name: "Harlot's Garden" }
			end

			@res.negotiated_body.rewind
			@res.negotiated_body.read.should == "{\"uuid\":\"fc85e35b-c9c3-4675-a882-25bf98d11e1b\"," +
				"\"name\":\"Harlot's Garden\"}"
			@res.content_type.should == "application/json"
			@res.header_data.should =~ /accept(?!-)/i
		end

		it "can provide a block for bodies of several different symbolic mediatypes" do
			@req.headers.accept = 'application/x-yaml; q=0.7, application/json; q=0.9'

			@res.for( :json, :yaml ) do
				{ uuid: 'fc85e35b-c9c3-4675-a882-25bf98d11e1b', name: "Harlot's Garden" }
			end

			@res.negotiated_body.rewind
			@res.negotiated_body.read.should == "{\"uuid\":\"fc85e35b-c9c3-4675-a882-25bf98d11e1b\"," +
				"\"name\":\"Harlot's Garden\"}"
			@res.content_type.should == "application/json"
			@res.header_data.should =~ /accept(?!-)/i
		end

	end


	describe "automatic content transcoding" do

		it "transcodes String entity bodies if the charset is not acceptable" do
			@req.headers.accept_charset = 'koi8-r, koi8-u;q=0.9, utf-8;q=0.8'

			@res.body = File.read( __FILE__, encoding: 'iso-8859-5' )
			@res.content_type = 'text/plain'

			@res.negotiated_body.external_encoding.should == Encoding::KOI8_R
			@res.header_data.should =~ /accept-charset(?!-)/i
		end

		it "transcodes String entity bodies if the charset is not acceptable" do
			@req.headers.accept_charset = 'utf-8'

			@res.body = File.read( __FILE__, encoding: 'iso-8859-5' )
			@res.content_type = 'application/json'

			@res.negotiated_body.external_encoding.should == Encoding::UTF_8
			@res.header_data.should =~ /accept-charset(?!-)/i
		end

		it "transcodes File entity bodies if the charset is not acceptable" do
			pending "implementation of IO transcoding" do
				@req.headers.accept_charset = 'koi8-r, koi8-u;q=0.9, utf-8;q=0.8'

				@res.body = File.open( __FILE__, 'r:iso-8859-5' )
				@res.content_type = 'text/plain'

				@res.negotiated_body.encoding.should == Encoding::KOI8_R
				@res.header_data.should =~ /accept-charset(?!-)/i
			end
		end

	end


	describe "language alternative callback methods" do

		it "can provide blocks for alternative bodies of several different languages" do
			@req.headers.accept = 'text/plain'
			@req.headers.accept_language = 'de'

			@res.puts( "the English body" )
			@res.languages << :en
			@res.content_type = 'text/plain'
			@res.for_language( :de ) { "German translation" }
			@res.for_language( :sl ) { "Slovenian translation" }

			@res.negotiated_body.rewind
			@res.negotiated_body.read.should == "German translation"
			@res.languages.should == ["de"]
			@res.header_data.should =~ /accept-language/i
		end

		it "can provide blocks for bodies of several different languages without setting a " +
		   "default entity body" do
			@req.headers.accept = 'text/plain'
			@req.headers.accept_language = 'de, en-gb;q=0.9, en;q=0.7'

			@res.content_type = 'text/plain'
			@res.for_language( :en ) { "English translation" }
			@res.for_language( :de ) { "German translation" }
			@res.for_language( :sl ) { "Slovenian translation" }

			@res.negotiated_body.rewind
			@res.negotiated_body.read.should == "German translation"
			@res.languages.should == ["de"]
			@res.header_data.should =~ /accept-language/i
		end

		it "can provide a single block for bodies of several different languages" do
			@req.headers.accept_language = 'fr;q=0.9, de;q=0.7, en;q=0.7, pt'
			translations = {
				:pt => "Portuguese translation",
				:fr => "French translation",
				:de => "German translation",
				:en => "English translation",
			}

			@res.content_type = 'text/plain'
			@res.for_language( translations.keys ) do |lang|
				translations[ lang.to_sym ]
			end

			@res.negotiated_body.rewind
			@res.negotiated_body.read.should == "Portuguese translation"
			@res.languages.should == ["pt"]
			@res.header_data.should =~ /accept-language/i
		end

		it "calls the first block for requests with no accept-language header" do
			@req.headers.delete( :accept_language )
			@req.headers.accept = 'text/plain'

			@res.content_type = 'text/plain'
			@res.for_language( :en ) { "English translation" }
			@res.for_language( :de ) { "German translation" }
			@res.for_language( :sl ) { "Slovenian translation" }

			@res.negotiated_body.rewind
			@res.negotiated_body.read.should == "English translation"
			@res.languages.should == ["en"]
			@res.header_data.should =~ /accept-language/i
		end
	end


	describe "content coding alternative callback methods" do

		it "can provide blocks for content coding" do
			@req.headers.accept = 'text/plain'
			@req.headers.accept_encoding = 'gzip'

			@res << "the text body"
			@res.content_type = 'text/plain'
			@res.for_encoding( :deflate ) { @res.body << " (deflated)" }
			@res.for_encoding( :gzip ) { @res.body << " (gzipped)" }

			@res.negotiated_body.rewind
			@res.negotiated_body.read.should == "the text body (gzipped)"
			@res.encodings.should include( "gzip" )
			@res.header_data.should =~ /accept-encoding/i
			@res.header_data.should_not =~ /identity/i
		end

		it "chooses the content coding with the highest qvalue" do
			@req.headers.accept = 'text/plain'
			@req.headers.accept_encoding = 'gzip;q=0.7, deflate'

			@res << "the text body"
			@res.content_type = 'text/plain'
			@res.for_encoding( :deflate ) { @res.body << " (deflated)" }
			@res.for_encoding( :gzip ) { @res.body << " (gzipped)" }

			@res.negotiated_body.rewind
			@res.negotiated_body.read.should == "the text body (deflated)"
			@res.encodings.should include( "deflate" )
			@res.header_data.should =~ /accept-encoding/i
			@res.header_data.should_not =~ /identity/i
		end

	end


	describe "content-type acceptance predicates" do

		it "knows that it is acceptable if its content_type is in the list of accepted types " +
		   "in its request" do
			@req.headers.accept = 'application/x-yaml, application/json; q=0.7'
			@res.content_type = 'application/json'

			@res.should have_acceptable_content_type()
		end

		it "knows that it is acceptable if its request doesn't have accepted types" do
			@req.headers.delete( :accept )
			@res.content_type = 'application/x-ruby-marshalled'

			@res.should have_acceptable_content_type()
		end

		it "knows that it is acceptable if it doesn't have an originating request" do
			res = Strelka::HTTPResponse.new( 'appid', 88 )
			res.extend( Strelka::HTTPResponse::Negotiation )
			res.content_type = 'application/x-ruby-marshalled'

			res.should have_acceptable_content_type()
		end

		it "knows that it is not acceptable if its content_type isn't in the list of " +
		   "accepted types in its request" do
			@req.headers.accept = 'application/x-yaml, application/json; q=0.7'
			@res.content_type = 'application/x-ruby-marshalled'

			@res.should_not have_acceptable_content_type()
		end

	end


	describe "charset acceptance predicates" do

		it "knows that it is acceptable if its explicit charset is in the list of accepted " +
		   "charsets in its request" do
			@req.headers.accept_charset = 'iso-8859-5, utf-8;q=0.8'
			@res.charset = 'iso-8859-5'

			@res.should have_acceptable_charset()
		end

		it "knows that it is acceptable if its request doesn't have accepted types" do
			@req.headers.delete( :accept_charset )
			@res.charset = 'koi8-u'
			@res.should have_acceptable_charset()
		end

		it "knows that it is acceptable if it doesn't have an originating request" do
			res = Strelka::HTTPResponse.new( 'appid', 88 )
			res.charset = 'iso8859-15'

			res.should have_acceptable_charset()
		end

		it "knows that it is acceptable if its explicit charset is set to ascii-8bit" do
			@req.headers.accept_charset = 'iso-8859-1, utf-8;q=0.8'
			@res.content_type = 'image/jpeg'
			@res.charset = Encoding::ASCII_8BIT

			@res.should have_acceptable_charset()
		end

		it "knows that it is acceptable if no charset can be derived, but the list of " +
		   "acceptable charsets includes ISO8859-1" do
			@req.headers.accept_charset = 'iso-8859-1, utf-8;q=0.8'
			@res.content_type = 'text/plain'
			@res.body = "some stuff".force_encoding( Encoding::ASCII_8BIT )

			@res.should have_acceptable_charset()
		end

		it "knows that it is not acceptable if no charset can be derived, the content is a " +
		   "text subtype, and the list of acceptable charsets doesn't include ISO8859-1" do
			@req.headers.accept_charset = 'iso-8859-15, utf-8;q=0.8'
			@res.content_type = 'text/plain'
			@res.body = "some stuff".force_encoding( Encoding::ASCII_8BIT )

			@res.should_not have_acceptable_charset()
		end

		it "knows that it is not acceptable if its explicit charset isn't in the list of " +
		   "accepted charsets in its request" do
			@req.headers.accept_charset = 'iso-8859-5, utf-8;q=0.8'
			@res.charset = 'sjis'

			@res.should_not have_acceptable_charset()
		end

		it "knows that it is not acceptable if the charset in its content-type header isn't in " +
		   "the list of accepted charsets in its request" do
			@req.headers.accept_charset = 'iso-8859-5, utf-8;q=0.8'
			@res.content_type = 'text/plain; charset=sjis'

			@res.should_not have_acceptable_charset()
		end

		it "knows that it is not acceptable if the charset derived from its entity body isn't in " +
		   "the list of accepted charsets in its request" do
			@req.headers.accept_charset = 'iso-8859-1, utf-8;q=0.8'
			@res.content_type = 'text/plain'
			@res.body = File.open( __FILE__, 'r:iso8859-5' )

			@res.should_not have_acceptable_charset()
		end

	end


	describe "language acceptance predicates" do

		it "knows that it is acceptable if it has a single language that's in the list of " +
		   "languages accepted by its originating request" do
			@req.headers.accept_language = 'en-gb, en; q=0.7, ja;q=0.2'
			@res.languages << 'ja'

			@res.should have_acceptable_language()
		end

		it "knows that it is acceptable if all of its multiple languages are in the list of " +
		   "languages accepted by its originating request" do
			@req.headers.accept_language = 'en-gb, en; q=0.7, ja;q=0.2'
			@res.languages << 'ja' << 'en-us'

			@res.should have_acceptable_language()
		end

		# I'm not sure if this is what RFC1616 means. It might be that *all* of its languages
		# have to be in the accept-language: list.
		it "knows that it is acceptable if one of its multiple languages is in the " +
		   "list of languages accepted by its originating request" do
			@req.headers.accept_language = 'en-gb, en; q=0.7, ja;q=0.2'
			@res.languages << 'pt' << 'en'

			@res.should have_acceptable_language()
		end

		it "knows that it is acceptable if it has a body but doesn't have a language set" do
			@req.headers.accept_language = 'en-gb, en; q=0.7, ja;q=0.2'
			@res.languages.clear
			@res.puts( "Some content in an unspecified language." )

			@res.should have_acceptable_language()
		end

		it "knows that it is acceptable if it has no body yet" do
			@req.headers.accept_language = 'en-gb, en; q=0.7, ja;q=0.2'
			@res.languages.clear

			@res.should have_acceptable_language()
		end

		it "knows that it is acceptable if it doesn't have an originating request" do
			res = Strelka::HTTPResponse.new( 'appid', 88 )
			res.extend( Strelka::HTTPResponse::Negotiation )
			res.languages << 'kh'

			res.should have_acceptable_language()
		end

		it "knows that it is not acceptable if it has a single language that isn't in the " +
		   "list of languages accepted by its originating request" do
			@req.headers.accept_language = 'en-gb, en; q=0.7, ja;q=0.2'
			@res.languages << 'pt'

			@res.should_not have_acceptable_language()
		end

		it "knows that it is not acceptable if it has multiple languages, none of which are " +
		   "in the list of languages accepted by its originating request" do
			@req.headers.accept_language = 'en-gb, en; q=0.7, ja;q=0.2'
			@res.languages << 'pt-br' << 'fr-ca'

			@res.should_not have_acceptable_language()
		end

	end


	describe "encoding acceptance predicates" do

		it "knows that it is acceptable if its content coding is in the list of accepted " +
		   "codings in its originating request" do
			@req.headers.accept_encoding = 'gzip;q=1.0, identity; q=0.5, *;q=0'
			@res.encodings << 'gzip'

			@res.should have_acceptable_encoding()
		end

		it "knows that it is acceptable if all of its content codings are in the list of accepted " +
		   "codings in its originating request" do
			@req.headers.accept_encoding = 'gzip;q=1.0, frobnify;q=0.9, identity; q=0.5, *;q=0'
			@res.encodings << 'gzip' << 'frobnify'

			@res.should have_acceptable_encoding()
		end

		it "knows that it is not acceptable if one of its content codings is not in the list " +
		   "of accepted codings in its originating request" do
			@req.headers.accept_encoding = 'gzip;q=1.0, identity; q=0.5, *;q=0'
			@res.encodings << 'gzip' << 'frobnify'

			@res.should_not have_acceptable_encoding()
		end

		it "knows that it is not acceptable if it doesn't have any explicit content codings " +
		   "and 'identity' is explicitly not accepted in its originating request" do
			@req.headers.accept_encoding = 'gzip;q=1.0, identity; q=0'
			@res.encodings.clear

			@res.should_not have_acceptable_encoding()
		end

		it "knows that it is not acceptable if it doesn't have any explicit content codings " +
		   "and 'identity' is explicitly not accepted in its originating request" do
			@req.headers.accept_encoding = 'gzip;q=1.0, identity; q=0'
			@res.encodings.clear

			@res.should_not have_acceptable_encoding()
		end

		it "knows that it is not acceptable if it doesn't have any explicit content codings, " +
		   "the wildcard content-coding is disallowed, and 'identity' is not explicitly accepted" do
			@req.headers.accept_encoding = 'gzip;q=1.0, *;q=0'
			@res.encodings.clear

			@res.should_not have_acceptable_encoding()
		end

	end


end

