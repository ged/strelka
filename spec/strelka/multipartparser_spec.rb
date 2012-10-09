#!/usr/bin/env ruby
#encoding: utf-8

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent
	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
}

require 'date'
require 'rspec'

require 'spec/lib/helpers'

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

		params.should have( 5 ).keys
		params.keys.should include( 'x-livejournal-entry' )
		params['velour-fog'].should =~ /Sweet, sweet canday/i
	end


	it "parses the file from a simple upload" do
		socket = load_form( "singleupload.form" )
		parser = described_class.new( socket, BOUNDARY )
		params = parser.parse

		file = params['upload']

		file.should be_a( Tempfile )
		file.filename.should == 'testfile.rtf'
		file.content_length.should == 480
		file.content_type.should == 'application/rtf'

		file.open
		file.read.should =~ /screaming.+anguish.+sirens/
	end

	it "strips full paths from upload filenames (e.g., from MSIE)" do
		socket = load_form( "testform_msie.form" )
		parser = described_class.new( socket, BOUNDARY )
		params = parser.parse

		file = params['upload']

		file.should be_a( Tempfile )
		file.filename.should == 'testfile.rtf'
		file.content_length.should == 480
		file.content_type.should == 'application/rtf'

		file.open
		file.read.should =~ /screaming.+anguish.+sirens/
	end

	it "parses a mix of uploaded files and form data" do
		socket = load_form( "testform_multivalue.form" )
		parser = described_class.new( socket, BOUNDARY )
		params = parser.parse

		params['pork'].should be_an_instance_of( Array )
		params['pork'].should have( 2 ).members
		params['pork'].should include( 'zoot' )
		params['pork'].should include( 'fornk' )

		params['namespace'].should == 'testing'
		params['rating'].should == '5'

		file = params['upload']

		file.should be_an_instance_of( Tempfile )
		file.filename.should == 'testfile.rtf'
		file.content_length.should == 480
		file.content_type.should == 'application/rtf'

		file.open
		file.read.should =~ /screaming.+anguish.+sirens/
	end


	JPEG_MAGIC = "\xff\xd8".force_encoding( 'ascii-8bit' )

	it "parses the files from multiple uploads" do
		socket = load_form( "2_images.form" )
		parser = described_class.new( socket, BOUNDARY )
		params = parser.parse

		file1, file2 = params['thingfish-upload']

		file1.filename.should == 'Photo 3.jpg'
		file2.filename.should == 'grass2.jpg'

		file1.content_type.should == 'image/jpeg'
		file2.content_type.should == 'image/jpeg'

		file1.content_length.should == 82143
		file2.content_length.should == 439257
	end

end

