#!/usr/bin/env ruby
#encoding: utf-8

require_relative '../helpers'

require 'date'
require 'rspec'

require 'strelka'
require 'strelka/multipartparser'


#####################################################################
###	C O N T E X T S
#####################################################################
describe Strelka::MultipartParser do

	BOUNDARY = 'sillyBoundary'
	MIMEPARSER_SPECDIR = Pathname.new( __FILE__ ).dirname.parent
	MIMEPARSER_DATADIR = MIMEPARSER_SPECDIR + 'data/forms'


	### Create a stub request prepopulated with HTTP headers and form data
	def load_form( filename )
		datafile = MIMEPARSER_DATADIR + filename
		return datafile.open( 'r', encoding: 'ascii-8bit' )
	end


	before( :all ) do
		setup_logging( :fatal )
		@tmpdir = make_tempdir()
	end

	after( :all ) do
		reset_logging()
		FileUtils.rm_rf( @tmpdir )
	end


	before( :each ) do
		described_class.configure( spooldir: @tmpdir, bufsize: 4096 )
	end


	it "should error if the initial boundary can't be found" do
		socket = load_form( "testform_bad.form" )
		parser = described_class.new( socket, BOUNDARY )

		expect {
			parser.parse
		}.to raise_error( Strelka::ParseError, /^No initial boundary/ )
	end

	it "should error if headers can't be found" do
		socket = load_form( "testform_badheaders.form" )
		parser = described_class.new( socket, BOUNDARY )

		expect {
			parser.parse
		}.to raise_error( Strelka::ParseError, /^EOF while searching for headers/ )
	end

	it "raises an error when the document is truncated inside a form field" do
		socket = load_form( "testform_truncated_metadata.form" )
		parser = described_class.new( socket, BOUNDARY )

		expect {
			parser.parse
		}.to raise_error( Strelka::ParseError, /EOF while scanning/i )
	end


	it "parses form fields" do
		socket = load_form( "testform_metadataonly.form" )
		parser = described_class.new( socket, BOUNDARY )

		params = parser.parse

		expect( params ).to have( 5 ).keys
		expect( params.keys ).to include( 'x-livejournal-entry' )
		expect( params['velour-fog'] ).to match( /Sweet, sweet canday/i )
	end


	it "parses the file from a simple upload" do
		socket = load_form( "singleupload.form" )
		parser = described_class.new( socket, BOUNDARY )
		params = parser.parse

		file = params['upload']

		expect( file ).to be_a( Tempfile )
		expect( file.filename ).to eq( 'testfile.rtf' )
		expect( file.content_length ).to eq( 480 )
		expect( file.content_type ).to eq( 'application/rtf' )

		file.open
		expect( file.read ).to match( /screaming.+anguish.+sirens/ )
	end

	it "strips full paths from upload filenames (e.g., from MSIE)" do
		socket = load_form( "testform_msie.form" )
		parser = described_class.new( socket, BOUNDARY )
		params = parser.parse

		file = params['upload']

		expect( file ).to be_a( Tempfile )
		expect( file.filename ).to eq( 'testfile.rtf' )
		expect( file.content_length ).to eq( 480 )
		expect( file.content_type ).to eq( 'application/rtf' )

		file.open
		expect( file.read ).to match( /screaming.+anguish.+sirens/ )
	end

	it "parses a mix of uploaded files and form data" do
		socket = load_form( "testform_multivalue.form" )
		parser = described_class.new( socket, BOUNDARY )
		params = parser.parse

		expect( params['pork'] ).to be_an_instance_of( Array )
		expect( params['pork'] ).to have( 2 ).members
		expect( params['pork'] ).to include( 'zoot' )
		expect( params['pork'] ).to include( 'fornk' )

		expect( params['namespace'] ).to eq( 'testing' )
		expect( params['rating'] ).to eq( '5' )

		file = params['upload']

		expect( file ).to be_an_instance_of( Tempfile )
		expect( file.filename ).to eq( 'testfile.rtf' )
		expect( file.content_length ).to eq( 480 )
		expect( file.content_type ).to eq( 'application/rtf' )

		file.open
		expect( file.read ).to match( /screaming.+anguish.+sirens/ )
	end


	JPEG_MAGIC = "\xff\xd8".force_encoding( 'ascii-8bit' )

	it "parses the files from multiple uploads" do
		socket = load_form( "2_images.form" )
		parser = described_class.new( socket, BOUNDARY )
		params = parser.parse

		file1, file2 = params['thingfish-upload']

		expect( file1.filename ).to eq( 'Photo 3.jpg' )
		expect( file2.filename ).to eq( 'grass2.jpg' )

		expect( file1.content_type ).to eq( 'image/jpeg' )
		expect( file2.content_type ).to eq( 'image/jpeg' )

		expect( file1.content_length ).to eq( 82143 )
		expect( file2.content_length ).to eq( 439257 )
	end

end

