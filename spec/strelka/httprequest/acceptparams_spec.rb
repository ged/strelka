#!/usr/bin/env ruby

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
require 'strelka/httprequest/acceptparams'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::HTTPRequest, "accept params" do
	before( :all ) do
		setup_logging( :fatal )
	end

	after( :all ) do
		reset_logging()
	end


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

				rval.should be_an_instance_of( Strelka::HTTPRequest::MediaType )
				rval.type.should    == expectations[:type]
				rval.subtype.should == expectations[:subtype]
				rval.qvalue.should  == expectations[:qval]

				if expectations[:extensions]
					expectations[:extensions].each do |ext|
						rval.extensions.should include( ext )
					end
				end
			end
		end


		it "is lenient (but warns) about invalid qvalues" do
			rval = Strelka::HTTPRequest::MediaType.parse( '*/*; q=18' )
			rval.should be_an_instance_of( Strelka::HTTPRequest::MediaType )
			rval.qvalue.should == 1.0
		end


		it "rejects invalid Accept header values" do
			lambda {
				Strelka::HTTPRequest::MediaType.parse( 'porksausage' )
			}.should raise_error()
		end


		it "can represent itself in a human-readable object format" do
			header = "text/html; q=0.9; level=2"
			acceptparam = Strelka::HTTPRequest::MediaType.parse( header )
			acceptparam.inspect.should =~ %r{MediaType.*text/html.*q=0.9}
		end


		it "can represent itself as an Accept header" do
			header = "text/html;q=0.9;level=2"
			acceptparam = Strelka::HTTPRequest::MediaType.parse( header )
			acceptparam.to_s.should == header
		end


		it "can compare and sort on specificity" do
			header = "text/xml,application/xml,application/xhtml+xml,text/html;q=0.9," +
				     "text/html;q=0.9;level=1,text/plain;q=0.8,image/png,*/*;q=0.5"
			params = header.
				split( /\s*,\s*/ ).
				collect {|par| Strelka::HTTPRequest::MediaType.parse( par ) }.
				sort

			params[0].to_s.should == 'application/xhtml+xml;q=1.0'
			params[1].to_s.should == 'application/xml;q=1.0'
			params[2].to_s.should == 'image/png;q=1.0'
			params[3].to_s.should == 'text/xml;q=1.0'
			params[4].to_s.should == 'text/html;q=0.9'
			params[5].to_s.should == 'text/html;q=0.9;level=1'
			params[6].to_s.should == 'text/plain;q=0.8'
			params[7].to_s.should == '*/*;q=0.5'
		end


		it "can be compared against strings" do
			specific_param = Strelka::HTTPRequest::MediaType.parse( 'text/html' )
			subtype_wildcard_param = Strelka::HTTPRequest::MediaType.parse( 'image/*' )

			( specific_param =~ 'text/html' ).should be_true()
			( specific_param =~ 'image/png' ).should be_false()

			( subtype_wildcard_param =~ 'image/png' ).should be_true()
			( subtype_wildcard_param =~ 'image/jpeg' ).should be_true()
			( subtype_wildcard_param =~ 'text/plain' ).should be_false()
		end
	end


	describe Strelka::HTTPRequest::Language do

		it "can parse a simple language code" do
			hdr = 'en'
			param = Strelka::HTTPRequest::Language.parse( hdr )

			param.should be_an_instance_of( Strelka::HTTPRequest::Language )
			param.primary_tag.should == 'en'
			param.subtag.should be_nil()
			param.qvalue.should == 1.0
			param.extensions.should be_empty()
		end

		it "can parse a language range with a dialect" do
			hdr = 'en-gb'
			param = Strelka::HTTPRequest::Language.parse( hdr )

			param.should be_an_instance_of( Strelka::HTTPRequest::Language )
			param.primary_tag.should == 'en'
			param.subtag.should == 'gb'
			param.qvalue.should == 1.0
			param.extensions.should be_empty()
		end

		it "can parse a language tag with a q-value" do
			hdr = 'en-US; q=0.8'
			param = Strelka::HTTPRequest::Language.parse( hdr )

			param.should be_an_instance_of( Strelka::HTTPRequest::Language )
			param.primary_tag.should == 'en'
			param.subtag.should == 'us'
			param.qvalue.should == 0.8
			param.extensions.should be_empty()
		end

	end


	describe Strelka::HTTPRequest::Charset do

		it "can parse a simple charset" do
			hdr = 'iso-8859-1'
			param = Strelka::HTTPRequest::Charset.parse( hdr )

			param.should be_an_instance_of( Strelka::HTTPRequest::Charset )
			param.charset.should == 'iso-8859-1'
			param.subtype.should be_nil()
			param.qvalue.should == 1.0
			param.extensions.should be_empty()
		end

		it "can parse a charset with a q-value" do
			hdr = 'iso-8859-15; q=0.5'
			param = Strelka::HTTPRequest::Charset.parse( hdr )

			param.should be_an_instance_of( Strelka::HTTPRequest::Charset )
			param.charset.should == 'iso-8859-15'
			param.subtype.should be_nil()
			param.qvalue.should == 0.5
			param.extensions.should be_empty()
		end

		it "can return the Ruby Encoding object associated with its character set" do
			param = Strelka::HTTPRequest::Charset.parse( 'koi8-r' )
			param.charset.should == 'koi8-r'
			param.encoding_object.should == Encoding::KOI8_R
		end

		it "can be compared against strings" do
			specific_param = Strelka::HTTPRequest::Charset.parse( 'us-ascii' )

			( specific_param =~ 'us-ascii' ).should be_true()
			( specific_param =~ 'ansi_x3.4-1968' ).should be_true()
			( specific_param =~ 'utf-8' ).should be_false()
		end

		it "can be compared against Encoding objects" do
			specific_param = Strelka::HTTPRequest::Charset.parse( 'utf-8' )

			( specific_param =~ Encoding::UTF_8 ).should be_true()
			( specific_param =~ Encoding::CP65001 ).should be_true()
			( specific_param =~ Encoding::MacThai ).should be_false()
		end
	end


	describe Strelka::HTTPRequest::Encoding do

		it "can parse a simple encoding" do
			hdr = 'identity'
			param = Strelka::HTTPRequest::Encoding.parse( hdr )

			param.should be_an_instance_of( Strelka::HTTPRequest::Encoding )
			param.content_coding.should == 'identity'
			param.subtype.should be_nil()
			param.qvalue.should == 1.0
			param.extensions.should be_empty()
		end

		it "can parse an encoding with a q-value" do
			hdr = 'gzip; q=0.55'
			param = Strelka::HTTPRequest::Encoding.parse( hdr )

			param.should be_an_instance_of( Strelka::HTTPRequest::Encoding )
			param.content_coding.should == 'gzip'
			param.subtype.should be_nil()
			param.qvalue.should == 0.55
			param.extensions.should be_empty()
		end

		it "can be compared against strings" do
			specific_param = Strelka::HTTPRequest::MediaType.parse( 'text/html' )
			subtype_wildcard_param = Strelka::HTTPRequest::MediaType.parse( 'image/*' )

			( specific_param =~ 'text/html' ).should be_true()
			( specific_param =~ 'image/png' ).should be_false()

			( subtype_wildcard_param =~ 'image/png' ).should be_true()
			( subtype_wildcard_param =~ 'image/jpeg' ).should be_true()
			( subtype_wildcard_param =~ 'text/plain' ).should be_false()
		end
	end


end

# vim: set nosta noet ts=4 sw=4:
