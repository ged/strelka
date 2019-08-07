# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# frozen-string-literal: true

require 'tmpdir'
require 'tempfile'
require 'pathname'
require 'stringio'

require 'strelka' unless defined?( Strelka )

# A parser for extracting uploaded files and parameters from the body of a
# multipart/form-data request.
#
# == Synopsis
#
#   require 'strelka/multipartmimeparser'
#
#   parser = Strelka::MultipartMimeParser.new
#   files, params = parser.parse( io, '---boundary' )
#
# == Authors
#
# * Michael Granger <ged@FaerieMUD.org>
# * Mahlon E. Smith <mahlon@martini.nu>
#
### A class for parsing multipart mime documents from a stream.
class Strelka::MultipartParser
	extend Loggability,
		   Strelka::MethodUtilities
	include Configurability

	# Loggability API -- log to Strelka's logger
	log_to :strelka

	# Configurability API -- use the 'multipartparser' section of the config
	configurability( 'strelka.multipartparser' ) do
		##
		# The configured buffer size to use when parsing
		setting :bufsize, default: 524288 do |val|
			Integer( val ) if val
		end

		##
		# The configured spool directory for storing attachments
		setting :spooldir, default: Dir.tmpdir + '/strelka-mimeparts' do |val|
			Pathname( val ) if val
		end

	end


	# Line-ending regexp. Supports UNIX line-endings for testing.
	CRLF_REGEXP        = /\r?\n/

	# Pattern for matching a blank line
	BLANK_LINE_REGEXP  = /#{CRLF_REGEXP}{2}/

	# Line-ending for RFC5322 header fields; EOL *not* followed by a WSP char
	HEADER_FIELD_EOL = /#{CRLF_REGEXP}(?!\x32|\x09)/


	# A mixin that extends the IO objects for uploaded files.
	module FileInputField

		attr_accessor :content_type, :content_length, :filename

	end # module FileInputField



	### Create a new Strelka::MultipartMimeParser
	def initialize( io, boundary )
		io        = StringIO.new( io ) unless io.respond_to?( :read )
		boundary  = '--' + boundary # unless boundary.start_with?( '--' )

		@bufsize  = self.class.bufsize || self.class.defaults.spooldir
		@spooldir = self.class.spooldir || Pathname( self.class.defaults.spooldir )
		@io       = io
		@boundary = boundary
		@fields   = {}
		@buffer   = ''

		# Ensure that the buffer can contain at least a whole boundary,
		# otherwise we can't scan for it.
		@bufsize  = @boundary.bytesize * 1.5 if @bufsize < @boundary.bytesize * 1.5
		@spooldir.mkpath
	end


	######
	public
	######

	# Parsed form fields
	attr_reader :fields

	# The current buffer for unparsed data
	attr_reader :buffer


	### Parse the form data from the IO and return it as a Hash.
	def parse
		self.log.debug "Starting parse: %p" % [ self ]

		# Strip off the initial boundary
		self.strip_boundary or
			raise Strelka::ParseError, "No initial boundary"

		# Now scan until we see the ending boundary (the one with the trailing '--')
		self.scan_part until @buffer.start_with?( '--' )

		self.log.debug "Finished parse. %d fields" % [ self.fields.length ]
		return self.fields
	end



	#########
	protected
	#########

	### Scan a part from the buffer.
	def scan_part
		headers = self.scan_headers
		disposition = headers['content-disposition']

		raise UnimplementedError, "don't know what to do with %p parts" % [ disposition ] unless
			disposition.start_with?( 'form-data' )
		key = disposition[ /\bname="(\S+)"/i, 1 ] or
			raise Strelka::ParseError, "no field name: %p" % [ disposition ]
		val = nil

		# :TODO: Support for content-type and content-transfer-encoding headers for parts.

		# If it's a file, spool it out to a tempfile
		if disposition =~ /\bfilename=/i
			file = disposition[ /\bfilename="(?:.*\\)?(.+?)"/, 1 ] or return nil
			self.log.debug "Parsing an uploaded file %p (%p)" % [ key, file ]
			val = self.scan_file_field( file, headers )

		# otherwise just read it as a regular parameter
		else
			self.log.debug "Parsing a form parameter (%p)" % [ key ]
			val = self.scan_regular_field( key )
		end

		# Convert the value to an Array if there are more than one
		if @fields.key?( key )
			@fields[ key ] = [ @fields[key] ] unless @fields[ key ].is_a?( Array )
			@fields[ key ] << val
		else
			@fields[ key ] = val
		end

		self.strip_boundary
	end


	### Scan the buffer for MIME headers and return them as a Hash.
	def scan_headers
		headerlines = ''

		@buffer.slice!( /^#{CRLF_REGEXP}/ )

		# Find the headers
		while headerlines.empty?
			if pos = @buffer.index( BLANK_LINE_REGEXP )
				headerlines = @buffer.slice!( 0, pos )
			else
				self.log.debug "Couldn't find a blank line in the first %d bytes (%p)" %
					[ @buffer.bytesize, @buffer[0..100] ]
				self.read_at_least( @bufsize ) or
					raise Strelka::ParseError, "EOF while searching for headers"
			end
		end

		# put headers into a hash
		headers = headerlines.strip.split( HEADER_FIELD_EOL ).inject({}) {|hash, line|
			line.gsub!( CRLF_REGEXP, '' ) # Un-fold long headers
			key, val = line.split( /:\s*/, 2 )
			hash[ key.downcase ] = val
			hash
		}
		self.log.debug "Scanned headers: %p" % [headers]

		# remove headers from parse buffer
		@buffer.slice!( /^#{BLANK_LINE_REGEXP}/ )

		return headers
	end


	### Scan the value after the scan pointer for the specified metadata
	### +parameter+.
	def scan_regular_field( key )
		param = ''

		self.log.debug "Scanning form parameter: %p" % [key]
		while param.empty?
			if start = @buffer.index( @boundary )
				self.log.debug "Found the end of the parameter."
				param = @buffer.slice!( 0, start )
			else
				self.read_some_more or raise Strelka::ParseError,
					"EOF while scanning a form parameter"
			end
		end

		return param.chomp
	end


	### Scan the body of the current document part, spooling the data to a tempfile
	### on disk and returning the resulting filehandle.
	def scan_file_field( filename, headers )
		self.log.info "Parsing file '%s'" % [ filename ]

		io, size = self.spool_file_upload

		io.extend( FileInputField )
		io.filename       = filename
		io.content_type   = headers['content-type']
		io.content_length = size

		self.log.debug "Scanned file %p to: %s (%d bytes)" % [ io.filename, io.path, size ]
		return io
	end


	### Scan the file data and metadata in the given +scannner+, spooling the file
	### data into a temporary file. Returns the tempfile object and a hash of
	### metadata.
	def spool_file_upload
		self.log.debug "Spooling file from upload"
		tmpfile = Tempfile.open( 'filedata', @spooldir.to_s, encoding: 'ascii-8bit' )
		size = 0

		# :TODO: Use mmap(2) to map the resulting IOs from mongrel's spool file
		# rather than writing them all out to disk a second time.
		until tmpfile.closed?

			# look for end, store everything until boundary
			if start = @buffer.index( @boundary )
				self.log.debug "Found the end of the file"
				leavings = @buffer.slice!( 0, start )
				leavings.slice!( -2, 2 ) # trailing CRLF
				tmpfile.write( leavings )
				size += leavings.length
				tmpfile.close

			# not at the end yet, buffer this chunker to disk
			elsif @buffer.bytesize >= @bufsize
				# make sure we're never writing a portion of the boundary
				# out while we're buffering
				buf = @buffer.slice!( 0, @buffer.bytesize - @bufsize )
				# self.log.debug "  writing %d bytes" % [ buf.bytesize ]
				tmpfile.print( buf )
				size += buf.bytesize
			end

			# put some more data into the buffer
			unless tmpfile.closed?
				self.read_some_more or
					raise Strelka::ParseError, "EOF while spooling file upload"
			end
		end

		return tmpfile, size
	end


	### Strip data from the head of the buffer that matches +pat+, returning it
	### if successful, or returning +nil+ if not. The matched data should fit within
	### the parser's chunk size.
	def strip( pat )
		self.read_chunk
		return nil unless @buffer.index( pat ) == 0
		@buffer.slice!( pat )
	end


	### Strip the boundary that's at the front of the buffer, reading more
	### data into it as necessary. Returns the boundary if successful, or +nil+ if
	### there wasn't a boundary in the buffer.
	def strip_boundary
		self.log.debug "Stripping boundary:\n%p at:\n%p" % [ @boundary, @buffer[0,40] ]
		self.strip( @boundary )
	end


	### Read data from the state's IO until the buffer contains at least the number
	### of bytes in the chunksize, or the IO is at EOF.
	def read_chunk
		# self.log.debug "Reading a new chunk."
		self.read_at_least( @bufsize )
		# self.log.debug "  buffer is now: %p" % [ @buffer ]
	end


	### Read at least +bytecount+ bytes from the io, appending the data onto the
	### buffer.
	def read_at_least( bytecount )
		# self.log.debug "Reading at least %d bytes from %p." % [ bytecount, @io ]

		if @io.eof?
			# self.log.debug "  input stream at EOF. Returning."
			return false
		end

		self.read_some_more until
			@buffer.bytesize >= bytecount || @io.eof?

		return true
	end


	### Try to read another chunk of data into the buffer of the given +state+,
	### returning true unless the state's IO is at eof.
	def read_some_more
		# self.log.debug "Reading more data from %p..." % [ @io ]
		return false if @io.eof?
		startsize = @buffer.bytesize

		@buffer << @io.read( @bufsize )
		# self.log.debug "  after reading, buffer has %d bytes." % [ @buffer.bytesize ]

		until @buffer.bytesize > startsize
			return false if @io.eof?
			Thread.pass
			@buffer << @io.read( @bufsize )
		end

		return true
	end

end # class Strelka::MultipartParser

