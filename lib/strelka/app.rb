# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require 'rubygems' # For the Rubygems API

require 'loggability'
require 'configurability'
require 'mongrel2/handler'
require 'strelka' unless defined?( Strelka )
require 'strelka/mixins'
require 'strelka/plugins'


# The Strelka HTTP application base class.
class Strelka::App < Mongrel2::Handler
	extend Loggability,
	       Configurability,
	       Strelka::MethodUtilities,
	       Strelka::PluginLoader
	include Strelka::Constants,
	        Strelka::ResponseHelpers

	# Loggability API -- set up logging
	log_to :strelka

	# Configurability API -- use the 'app' section of the config file.
	config_key :app


	# Glob for matching Strelka apps relative to a gem's data directory
	APP_GLOB_PATTERN = '{apps,handlers}/**/*'

	# Default config
	CONFIG_DEFAULTS = { devmode: false }


	# Class instance variables
	@devmode      = false
	@default_type = nil
	@loading_file = nil
	@subclasses   = Hash.new {|h,k| h[k] = [] }


	##
	# The Hash of Strelka::App subclasses, keyed by the Pathname of the file they were
	# loaded from, or +nil+ if they weren't loaded via ::load.
	singleton_attr_reader :subclasses

	##
	# 'Developer mode' flag.
	singleton_attr_writer :devmode


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

		Loggability.level = :debug if self.devmode?
		Loggability.format_with( :color ) if $stderr.tty?

		self.log.info "Starting up with appid %p." % [ appid ]
		super( appid )
	end


	### Calculate a default application ID for the class based on either its ID
	### constant or its name and return it.
	def self::default_appid
		self.log.info "Looking up appid for %p" % [ self.class ]
		appid = nil

		if self.const_defined?( :ID )
			appid = self.const_get( :ID )
			self.log.info "  app has an ID: %p" % [ appid ]
		else
			appid = ( self.name || "anonymous#{self.object_id}" ).downcase
			appid.gsub!( /[^[:alnum:]]+/, '-' )
			self.log.info "  deriving one from the class name: %p" % [ appid ]
		end

		return appid
	end


	### Return a Hash of Strelka app files as Pathname objects from installed gems,
	### keyed by gemspec name .
	def self::discover_paths
		self.log.debug "Local paths: %s" % [ Strelka.datadir + APP_GLOB_PATTERN ]

		appfiles = {
			'' => Pathname.glob( Strelka.datadir + APP_GLOB_PATTERN )
		}

		# Find all the gems that depend on Strelka
		gems = Gem::Specification.find_all do |gemspec|
			gemspec.dependencies.find {|dep| dep.name == 'strelka'}
		end

		self.log.debug "Found %d gems with a Strelka dependency" % [ gems.length ]

		# Find all the files under those gems' data directories that match the application
		# pattern
		gems.sort.reverse.each do |gemspec|
			# Only look at the latest version of the gem
			next if appfiles.key?( gemspec.name )
			appfiles[ gemspec.name ] = []

			self.log.debug "  checking %s for apps in its datadir" % [ gemspec.name ]
			pattern = File.join( gemspec.full_gem_path, "data", gemspec.name, APP_GLOB_PATTERN )
			self.log.debug "    glob pattern is: %p" % [ pattern ]
			gemapps = Pathname.glob( pattern )
			self.log.debug "    found %d app files" % [ gemapps.length ]
			appfiles[ gemspec.name ] += gemapps
		end

		return appfiles
	end


	### Return an Array of Strelka::App classes loaded from the installed Strelka gems.
	def self::discover
		discovered_apps = []
		app_paths = self.discover_paths

		self.log.debug "Loading apps from %d discovered paths" % [ app_paths.length ]
		app_paths.each do |gemname, paths|
			self.log.debug "  loading gem %s" % [ gemname ]
			gem( gemname ) unless gemname == ''

			self.log.debug "  loading apps from %s: %d handlers" % [ gemname, paths.length ]
			paths.each do |path|
				classes = begin
					Strelka::App.load( path )
				rescue StandardError, ScriptError => err
					self.log.error "%p while loading Strelka apps from %s: %s" %
						[ err.class, path, err.message ]
					self.log.debug "Backtrace: %s" % [ err.backtrace.join("\n\t") ]
					[]
				end
				self.log.debug "  loaded app classes: %p" % [ classes ]

				discovered_apps += classes
			end
		end

		return discovered_apps
	end


	### Load the specified +file+, and return any Strelka::App subclasses that are loaded
	### as a result.
	def self::load( file )
		self.log.debug "Loading application/s from %p" % [ file ]
		@loading_file = Pathname( file ).expand_path
		self.subclasses.delete( @loading_file )
		Kernel.load( @loading_file.to_s )
		new_subclasses = self.subclasses[ @loading_file ]
		self.log.debug "  loaded %d new app class/es" % [ new_subclasses.size ]

		return new_subclasses
	ensure
		@loading_file = nil
	end


	### Returns +true+ if the application has been configured to run in 'developer mode'.
	### Developer mode is mostly informational by default (it just makes logging more
	### verbose), but plugins and such might alter their behavior based on this setting.
	def self::devmode?
		return @devmode
	end
	singleton_method_alias :in_devmode?, :devmode?


	### Configure the App. Override this if you wish to add additional configuration
	### to the 'app' section of the config that will be passed to you when the config
	### is loaded.
	def self::configure( config=nil )
		if config
			self.devmode = true if config[:devmode]
		else
			self.devmode = $DEBUG ? true : false
		end

		self.log.info "Enabled developer mode." if self.devmode?
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

	### Dump the application stack when a new instance is created.
	def initialize( * )
		self.class.dump_application_stack
		super
	end


	######
	public
	######

	### Run the app -- overriden to set the process name to something interesting.
	def run
		procname = "%p %s" % [ self.class, self.conn ]
		$0 = procname

		super
	end


	### The main Mongrel2 entrypoint -- accept Strelka::Requests and return
	### Strelka::Responses.
	def handle( request )
		response = nil

		# Dispatch the request after allowing plugins to to their thing
		status_info = catch( :finish ) do
			self.log.debug "Starting dispatch of request %p" % [ request ]

			# Run fixup hooks on the request
			request = self.fixup_request( request )
			self.log.debug "  done with request fixup"
			response = self.handle_request( request )
			self.log.debug "  done with handler"
			response = self.fixup_response( response )
			self.log.debug "  done with response fixup"

			nil # rvalue for the catch
		end

		# Status response
		if status_info
			self.log.debug "Preparing a status response: %p" % [ status_info ]
			return self.prepare_status_response( request, status_info )
		end

		return response
	rescue => err
		self.log.error "%s: %s %s" % [ err.class.name, err.message, err.backtrace.first ]
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
		return request
	end


	### Handle the request and return a +response+. This is the main extension-point
	### for the plugin system. Without being overridden or extended by plugins, this
	### method just returns the default Mongrel2::HTTPRequest#response. If you override
	### this directly in your App subclass, you'll need to +super+ with a block if you
	### wish the plugins to run on the request, then do whatever it is you want in the
	### block and return the response, which the plugins will again have an opportunity
	### to modify.
	###
	### Example:
	###
	###     class MyApp < Strelka::App
	###         def handle_request( request )
	###             super do |req|
	###                 res = req.response
	###                 res.content_type = 'text/plain'
	###                 res.puts "Hello!"
	###                 return res
	###             end
	###         end
	###     end
	def handle_request( request, &block )
		if block
			return block.call( request )
		else
			return request.response
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

		return response
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


	### Create a response to specified +request+ based on the specified +status_code+
	### and +message+.
	def prepare_status_response( request, status_info )
		status_code, message = status_info.values_at( :status, :message )
		self.log.info "Non-OK response: %d (%s)" % [ status_code, message ]

		request.notes[:status_info] = status_info
		response = request.response
		response.reset
		response.status = status_code

		# Some status codes allow explanatory text to be returned; some forbid it. Append the
		# message for those that allow one.
		unless request.verb == :HEAD || response.bodiless?
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

end # class Strelka::App

