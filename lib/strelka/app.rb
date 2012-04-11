# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require 'rubygems' # For the Rubygems API

require 'mongrel2/handler'
require 'strelka' unless defined?( Strelka )
require 'strelka/mixins'


# The application base class.
class Strelka::App < Mongrel2::Handler
	extend Strelka::MethodUtilities
	include Strelka::Loggable,
	        Strelka::Constants

	# Load the plugin system
	require 'strelka/app/plugins'
	include Strelka::App::Plugins


	# Glob for matching Strelka apps relative to a gem's data directory
	APP_GLOB_PATTERN = '{apps,handlers}/**/*'


	# Class instance variables
	@default_type = nil
	@loading_file = nil
	@subclasses   = Hash.new {|h,k| h[k] = [] }


	##
	# The Hash of Strelka::App subclasses, keyed by the Pathname of the file they were
	# loaded from, or +nil+ if they weren't loaded via ::load.
	singleton_attr_reader :subclasses


	### Inheritance callback -- add subclasses to @subclasses so .load can figure out which
	### classes correspond to which files.
	def self::inherited( subclass )
		super
		@subclasses[ @loading_file ] << subclass if self == Strelka::App
	end


	### Overridden from Mongrel2::Handler -- use the value returned from .default_appid if
	### one is not specified, and automatically install the config DB if it hasn't been
	### already.
	def self::run( appid=nil )
		appid ||= self.default_appid

		Strelka.logger.level = Logger::DEBUG if $VERBOSE
		Strelka.logger.formatter = Strelka::Logging::ColorFormatter.new( Strelka.logger ) if $stderr.tty?

		super( appid )

	end


	### Calculate a default application ID for the class based on either its ID
	### constant or its name and return it.
	def self::default_appid
		Strelka.log.info "Looking up appid for %p" % [ self.class ]
		appid = nil

		if self.const_defined?( :ID )
			appid = self.const_get( :ID )
			Strelka.log.info "  app has an ID: %p" % [ appid ]
		else
			appid = ( self.name || "anonymous#{self.object_id}" ).downcase
			appid.gsub!( /[^[:alnum:]]+/, '-' )
			Strelka.log.info "  deriving one from the class name: %p" % [ appid ]
		end

		return appid
	end


	### Return a Hash of Strelka app files as Pathname objects from installed gems,
	### keyed by gemspec name .
	def self::discover_paths
		appfiles = {
			'strelka' => Pathname.glob( DATADIR + APP_GLOB_PATTERN )
		}

		# Find all the gems that depend on Strelka
		gems = Gem::Specification.find_all do |gemspec|
			gemspec.dependencies.find {|dep| dep.name == 'strelka'}
		end

		Strelka.log.debug "Found %d gems with a Strelka dependency" % [ gems.length ]

		# Find all the files under those gems' data directories that match the application
		# pattern
		gems.sort.reverse.each do |gemspec|
			# Only look at the latest version of the gem
			next if appfiles.key?( gemspec.name )
			appfiles[ gemspec.name ] = []

			Strelka.log.debug "  checking %s for apps in its datadir" % [ gemspec.name ]
			pattern = File.join( gemspec.full_gem_path, "data", gemspec.name, APP_GLOB_PATTERN )
			Strelka.log.debug "    glob pattern is: %p" % [ pattern ]
			gemapps = Pathname.glob( pattern )
			Strelka.log.debug "    found %d app files" % [ gemapps.length ]
			appfiles[ gemspec.name ] += gemapps
		end

		return appfiles
	end


	### Return an Array of Strelka::App classes loaded from the installed Strelka gems.
	def self::discover
		discovered_apps = []
		app_paths = self.discover_paths

		Strelka.log.debug "Loading apps from %d discovered paths" % [ app_paths.length ]
		app_paths.each do |gemname, paths|
			Strelka.log.debug "  loading gem %s" % [ gemname ]
			gem( gemname ) unless gemname == 'strelka'

			Strelka.log.debug "  loading apps from %s: %d handlers" % [ gemname, paths.length ]
			paths.each do |path|
				classes = begin
					Strelka::App.load( path )
				rescue StandardError, ScriptError => err
					Strelka.log.error "%p while loading Strelka apps from %s: %s" %
						[ err.class, path, err.message ]
					Strelka.log.debug "Backtrace: %s" % [ err.backtrace.join("\n\t") ]
					[]
				end
				Strelka.log.debug "  loaded app classes: %p" % [ classes ]

				discovered_apps += classes
			end
		end

		return discovered_apps
	end


	### Load the specified +file+, and return any Strelka::App subclasses that are loaded
	### as a result.
	def self::load( file )
		Strelka.log.debug "Loading application/s from %p" % [ file ]
		@loading_file = Pathname( file ).expand_path
		self.subclasses.delete( @loading_file )
		Kernel.load( @loading_file.to_s )
		new_subclasses = self.subclasses[ @loading_file ]
		Strelka.log.debug "  loaded %d new app class/es" % [ new_subclasses.size ]

		return new_subclasses
	ensure
		@loading_file = nil
	end


	#
	# :section: Application declarative methods
	#

	### Get/set the Content-type of requests that don't set one. Leaving this unset will
	### leave the Content-type unset.
	def self::default_type( newtype=nil )
		@default_type = newtype if newtype
		return @default_type
	end


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	######
	public
	######

	### Run the app -- overriden to set the process name to something interesting.
	def run
		procname = "%p %s" % [ self.class, self.conn ]
		$0 = procname

		self.dump_application_stack

		super
	end


	### The main Mongrel2 entrypoint -- accept Strelka::Requests and return
	### Strelka::Responses.
	def handle( request )
		response = nil

		# Dispatch the request after allowing plugins to to their thing
		status_info = catch( :finish ) do

			# Run fixup hooks on the request
			request = self.fixup_request( request )
			response = self.handle_request( request )
			response = self.fixup_response( response )

			nil # rvalue for the catch
		end

		# Status response
		if status_info
			self.log.debug "Preparing a status response: %p" % [ status_info ]
			return self.prepare_status_response( request, status_info )
		end

		return response
	rescue => err
		msg = "%s: %s %s" % [ err.class.name, err.message, err.backtrace.first ]
		self.log.error( msg )
		err.backtrace[ 1..-1 ].each {|frame| self.log.debug('  ' + frame) }

		status_info = { :status => HTTP::SERVER_ERROR, :message => 'internal server error' }
		return self.prepare_status_response( request, status_info )
	end


	#########
	protected
	#########

	### Make any changes to the +request+ that are necessary before handling it and
	### return it. This is an alternate extension-point for plugins that
	### wish to modify or replace the request before the request cycle is
	### started.
	def fixup_request( request )
		self.log.debug "Fixing up request: %p" % [ request ]
		request = super
		self.log.debug "  after fixup: %p" % [ request ]

		return request
	end


	### Handle the request and return a +response+. This is the main extension-point
	### for the plugin system. Without being overridden or extended by plugins, this
	### method just returns the default Mongrel2::HTTPRequest#response.
	def handle_request( request, &block )
		if block
			return super( request, &block )
		else
			return super( request ) {|r| r.response }
		end
	end


	### Make any changes to the +response+ that are necessary before handing it to
	### Mongrel and return it. This is an alternate extension-point for plugins that
	### wish to modify or replace the response after the whole request cycle is
	### completed.
	def fixup_response( response )
		self.log.debug "Fixing up response: %p" % [ response ]
		self.fixup_response_content_type( response )
		self.fixup_head_response( response ) if
			response.request && response.request.verb == :HEAD
		self.log.debug "  after fixup: %p" % [ response ]

		return super
	end


	### If the +response+ doesn't yet have a Content-type header, and the app has
	### defined a default (via App.default_type), set it to the default.
	def fixup_response_content_type( response )

		# Make the error for returning something other than a Response object a little
		# nicer.
		unless response.respond_to?( :content_type )
			self.log.error "expected response (%p, a %p) to respond to #content_type" %
				[ response, response.class ]
			finish_with( HTTP::SERVER_ERROR, "malformed response" )
		end

		restype = response.content_type

		if !restype
			if (( default = self.class.default_type ))
				self.log.debug "Setting content type of the response to the default: %p" %
					[ default ]
				response.content_type = default
			else
				self.log.debug "No default content type"
			end
		else
			self.log.debug "Content type already set: %p" % [ restype ]
		end
	end


	### Remove the entity body of responses to HEAD requests.
	def fixup_head_response( response )
		self.log.debug "Truncating entity body of HEAD response."
		response.headers.content_length = response.get_content_length
		response.body = ''
	end


	### Abort the current execution and return a response with the specified
	### http_status code immediately. The specified +message+ will be logged,
	### and will be included in any message that is returned as part of the
	### response. The +headers+ hash will be used to set response headers.
	def finish_with( http_status, message, headers={} )
		status_info = { :status => http_status, :message => message, :headers => headers }
		throw :finish, status_info
	end


	### Create a response to specified +request+ based on the specified +status_code+
	### and +message+.
	### :TODO: Document and test the :content_type status_info field.
	### :TODO: Implement a way to set headers from the status_info.
	def prepare_status_response( request, status_info )
		status_code, message = status_info.values_at( :status, :message )
		self.log.info "Non-OK response: %d (%s)" % [ status_code, message ]

		response = request.response
		response.reset
		response.status = status_code

		# Some status codes allow explanatory text to be returned; some forbid it. Append the
		# message for those that allow one.
		unless request.verb == :HEAD || HTTP::BODILESS_HTTP_RESPONSE_CODES.include?( status_code )
			response.content_type = 'text/plain'
			response.puts( message )
		end

		# Now assign any headers to the response that are part of the status
		if status_info.key?( :headers )
			status_info[:headers].each do |hdr, value|
				response.headers[ hdr ] = value
			end
		end

		return response
	end


	### Output the application stack into the logfile.
	def dump_application_stack
		stack = self.class.ancestors.
			reverse.
			drop_while {|mod| mod != Strelka::App }.
			select {|mod| mod.respond_to?(:plugin_name) }.
			reverse.
			collect {|mod| mod.plugin_name }

		self.log.info "Application stack: request -> %s" % [ stack.join(" -> ") ]
	end

end # class Strelka::App

