# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# frozen-string-literal: true

require_relative '../../helpers'

require 'rspec'

require 'strelka'
require 'strelka/httprequest/acceptparams'


#####################################################################
###	C O N T E X T S
#####################################################################

RSpec.describe Strelka::HTTPRequest, "accept params" do


	describe Strelka::HTTPRequest::MediaType do

		VALID_HEADERS = {
			'*/*' =>
				{:type => nil, :subtype => nil, :qval => 1.0},
			'*/*; q=0.1' =>
				{:type => nil, :subtype => nil, :qval => 0.1},
			'*/*;q=0.1' =>
				{:type => nil, :subtype => nil, :qval => 0.1},
			'image/*' =>
				{:type => 'image', :subtype => nil, :qval => 1.0},
			'image/*; q=0.18' =>
				{:type => 'image', :subtype => nil, :qval => 0.18},
			'image/*;q=0.4' =>
				{:type => 'image', :subtype => nil, :qval => 0.4},
			'image/*;q=0.9; porn=0; anseladams=1' =>
				{:type => 'image', :subtype => nil, :qval => 0.9,
					:extensions => %w[anseladams=1 porn=0]},
			'image/png' =>
				{:type => 'image', :subtype => 'png', :qval => 1.0},
			'IMAGE/pNg' =>
				{:type => 'image', :subtype => 'png', :qval => 1.0},
			'application/x-porno' =>
				{:type => 'application', :subtype => 'x-porno', :qval => 1.0},
			'image/png; q=0.2' =>
				{:type => 'image', :subtype => 'png', :qval => 0.2},
			'image/x-giraffes;q=0.2' =>
				{:type => 'image', :subtype => 'x-giraffes', :qval => 0.2},
			'example/pork;    headcheese=0;withfennel=1' =>
				{:type => 'example', :subtype => 'pork', :qval => 1.0,
					:extensions => %w[headcheese=0 withfennel=1]},
			'model/vnd.moml+xml' =>
				{:type => 'model', :subtype => 'vnd.moml+xml', :qval => 1.0},
			'model/parasolid.transmit.binary; q=0.2' =>
				{:type => 'model', :subtype => 'parasolid.transmit.binary',
					:qval => 0.2},
			'image/png; q=0.2; compression=1' =>
				{:type => 'image', :subtype => 'png', :qval => 0.2,
					:extensions => %w[compression=1]},
		}


		it "parses valid Accept header values" do
			VALID_HEADERS.each do |hdr, expectations|
				rval = Strelka::HTTPRequest::MediaType.parse( hdr )

				expect( rval ).to be_an_instance_of( Strelka::HTTPRequest::MediaType )
				expect( rval.type ).to eq( expectations[:type] )
				expect( rval.subtype ).to eq( expectations[:subtype] )
				expect( rval.qvalue ).to eq( expectations[:qval] )

				if expectations[:extensions]
					expectations[:extensions].each do |ext|
						expect( rval.extensions ).to include( ext )
					end
				end
			end
		end


		it "is lenient (but warns) about invalid qvalues" do
			rval = Strelka::HTTPRequest::MediaType.parse( '*/*; q=18' )
			expect( rval ).to be_an_instance_of( Strelka::HTTPRequest::MediaType )
			expect( rval.qvalue ).to eq( 1.0 )
		end


		it "rejects invalid Accept header values" do
			expect {
				Strelka::HTTPRequest::MediaType.parse( 'porksausage' )
			}.to raise_error( ArgumentError, /no media-range/i )
		end


		it "can represent itself in a human-readable object format" do
			header = "text/html; q=0.9; level=2"
			acceptparam = Strelka::HTTPRequest::MediaType.parse( header )
			expect( acceptparam.inspect ).to match( %r{MediaType.*text/html.*q=0.9} )
		end


		it "can represent itself as an Accept header" do
			header = "text/html;q=0.9;level=2"
			acceptparam = Strelka::HTTPRequest::MediaType.parse( header )
			expect( acceptparam.to_s ).to eq( header )
		end


		it "can compare and sort on specificity" do
			header = "text/xml,application/xml,application/xhtml+xml,text/html;q=0.9," +
				     "text/html;q=0.9;level=1,text/plain;q=0.8,image/png,*/*;q=0.5"
			params = header.
				split( /\s*,\s*/ ).
				collect {|par| Strelka::HTTPRequest::MediaType.parse( par ) }.
				sort

			expect( params[0].to_s ).to eq( 'application/xhtml+xml;q=1.0' )
			expect( params[1].to_s ).to eq( 'application/xml;q=1.0' )
			expect( params[2].to_s ).to eq( 'image/png;q=1.0' )
			expect( params[3].to_s ).to eq( 'text/xml;q=1.0' )
			expect( params[4].to_s ).to eq( 'text/html;q=0.9' )
			expect( params[5].to_s ).to eq( 'text/html;q=0.9;level=1' )
			expect( params[6].to_s ).to eq( 'text/plain;q=0.8' )
			expect( params[7].to_s ).to eq( '*/*;q=0.5' )
		end


		it "can be compared against strings" do
			specific_param = Strelka::HTTPRequest::MediaType.parse( 'text/html' )
			subtype_wildcard_param = Strelka::HTTPRequest::MediaType.parse( 'image/*' )

			expect( ( specific_param =~ 'text/html' ) ).to be_truthy()
			expect( ( specific_param =~ 'image/png' ) ).to be_falsey()

			expect( ( subtype_wildcard_param =~ 'image/png' ) ).to be_truthy()
			expect( ( subtype_wildcard_param =~ 'image/jpeg' ) ).to be_truthy()
			expect( ( subtype_wildcard_param =~ 'text/plain' ) ).to be_falsey()
		end
	end


	describe Strelka::HTTPRequest::Language do

		it "can parse a simple language code" do
			hdr = 'en'
			param = Strelka::HTTPRequest::Language.parse( hdr )

			expect( param ).to be_an_instance_of( Strelka::HTTPRequest::Language )
			expect( param.primary_tag ).to eq( 'en' )
			expect( param.subtag ).to be_nil()
			expect( param.qvalue ).to eq( 1.0 )
			expect( param.extensions ).to be_empty()
		end

		it "can parse a language range with a dialect" do
			hdr = 'en-gb'
			param = Strelka::HTTPRequest::Language.parse( hdr )

			expect( param ).to be_an_instance_of( Strelka::HTTPRequest::Language )
			expect( param.primary_tag ).to eq( 'en' )
			expect( param.subtag ).to eq( 'gb' )
			expect( param.qvalue ).to eq( 1.0 )
			expect( param.extensions ).to be_empty()
		end

		it "can parse a language tag with a q-value" do
			hdr = 'en-US; q=0.8'
			param = Strelka::HTTPRequest::Language.parse( hdr )

			expect( param ).to be_an_instance_of( Strelka::HTTPRequest::Language )
			expect( param.primary_tag ).to eq( 'en' )
			expect( param.subtag ).to eq( 'us' )
			expect( param.qvalue ).to eq( 0.8 )
			expect( param.extensions ).to be_empty()
		end

	end


	describe Strelka::HTTPRequest::Charset do

		it "can parse a simple charset" do
			hdr = 'iso-8859-1'
			param = Strelka::HTTPRequest::Charset.parse( hdr )

			expect( param ).to be_an_instance_of( Strelka::HTTPRequest::Charset )
			expect( param.name ).to eq( 'iso-8859-1' )
			expect( param.subtype ).to be_nil()
			expect( param.qvalue ).to eq( 1.0 )
			expect( param.extensions ).to be_empty()
		end

		it "can parse a charset with a q-value" do
			hdr = 'iso-8859-15; q=0.5'
			param = Strelka::HTTPRequest::Charset.parse( hdr )

			expect( param ).to be_an_instance_of( Strelka::HTTPRequest::Charset )
			expect( param.name ).to eq( 'iso-8859-15' )
			expect( param.subtype ).to be_nil()
			expect( param.qvalue ).to eq( 0.5 )
			expect( param.extensions ).to be_empty()
		end

		it "can return the Ruby Encoding object associated with its character set" do
			param = Strelka::HTTPRequest::Charset.parse( 'koi8-r' )
			expect( param.name ).to eq( 'koi8-r' )
			expect( param.encoding_object ).to eq( Encoding::KOI8_R )
		end

		it "can be compared against strings" do
			specific_param = Strelka::HTTPRequest::Charset.parse( 'us-ascii' )

			expect( ( specific_param =~ 'us-ascii' ) ).to be_truthy()
			expect( ( specific_param =~ 'ansi_x3.4-1968' ) ).to be_truthy()
			expect( ( specific_param =~ 'utf-8' ) ).to be_falsey()
		end

		it "can be compared against Encoding objects" do
			specific_param = Strelka::HTTPRequest::Charset.parse( 'utf-8' )

			expect( ( specific_param =~ Encoding::UTF_8 ) ).to be_truthy()
			expect( ( specific_param =~ Encoding::CP65001 ) ).to be_truthy()
			expect( ( specific_param =~ Encoding::MacThai ) ).to be_falsey()
		end
	end


	describe Strelka::HTTPRequest::Encoding do

		it "can parse a simple encoding" do
			hdr = 'identity'
			param = Strelka::HTTPRequest::Encoding.parse( hdr )

			expect( param ).to be_an_instance_of( Strelka::HTTPRequest::Encoding )
			expect( param.content_coding ).to eq( 'identity' )
			expect( param.subtype ).to be_nil()
			expect( param.qvalue ).to eq( 1.0 )
			expect( param.extensions ).to be_empty()
		end

		it "can parse an encoding with a q-value" do
			hdr = 'gzip; q=0.55'
			param = Strelka::HTTPRequest::Encoding.parse( hdr )

			expect( param ).to be_an_instance_of( Strelka::HTTPRequest::Encoding )
			expect( param.content_coding ).to eq( 'gzip' )
			expect( param.subtype ).to be_nil()
			expect( param.qvalue ).to eq( 0.55 )
			expect( param.extensions ).to be_empty()
		end

		it "can be compared against strings" do
			specific_param = Strelka::HTTPRequest::MediaType.parse( 'text/html' )
			subtype_wildcard_param = Strelka::HTTPRequest::MediaType.parse( 'image/*' )

			expect( ( specific_param =~ 'text/html' ) ).to be_truthy()
			expect( ( specific_param =~ 'image/png' ) ).to be_falsey()

			expect( ( subtype_wildcard_param =~ 'image/png' ) ).to be_truthy()
			expect( ( subtype_wildcard_param =~ 'image/jpeg' ) ).to be_truthy()
			expect( ( subtype_wildcard_param =~ 'text/plain' ) ).to be_falsey()
		end
	end


end

# vim: set nosta noet ts=4 sw=4:
