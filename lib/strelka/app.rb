#!/usr/bin/env ruby

require 'mongrel2/handler'
require 'strelka' unless defined?( Strelka )


# The application base class.
class Strelka::App < Mongrel2::Handler
	include Strelka::Loggable,
	        Strelka::Constants

	# Load the plugin system
	require 'strelka/app/plugins'
	include Strelka::App::Plugins


	@default_type = nil

	### Get/set the Content-type of requests that don't set one. Leaving this unset will
	### leave the Content-type unset.
	def self::default_type( newtype=nil )
		@default_type = newtype if newtype
		return @default_type
	end


	### Overridden from Mongrel2::Handler -- default the appid to the value of the ID constant
	### of the class being run if it has one, or the class name with non-alphanumeric
	### characters collapsed into hyphens if not. Also 
	def self::run( appid=nil )
		if appid.nil?
			Strelka.log.info "Looking up appid for %p" % [ self.class ]
			if self.const_defined?( :ID )
				appid = self.const_get( :ID )
				Strelka.log.info "  app has an ID: %p" % [ appid ]
			else
				appid = ( self.name || "anonymous#{self.object_id}" ).downcase
				appid.gsub!( /[^[:alnum:]]+/, '-' )
				Strelka.log.info "  deriving one from the class name: %p" % [ appid ]
			end
		end

		# Configure the Mongrel2 config database classes if they haven't been already
		Mongrel2::Config.configure( :configdb => Strelka::Constants::DEFAULT_CONFIG_URI ) unless
			Mongrel2::Config.database_initialized?

		Strelka.logger.level = $VERBOSE ? Logger::DEBUG : Logger::INFO
		super( appid )

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

		super
	end


	### The main Mongrel2 entrypoint -- accept Strelka::Requests and return
	### Strelka::Responses.
	def handle( request )
		response = nil

		# Run fixup hooks on the request
		request = self.fixup_request( request )

		# Dispatch the request after allowing plugins to to their thing
		status_info = catch( :finish ) do
			response = self.handle_request( request )
			nil # rvalue for the catch
		end

		# Status response
		if status_info
			self.log.debug "Preparing a status response: %p" % [ status_info ]
			return self.prepare_status_response( request, status_info )

		# Normal response
		else
			self.log.debug "Preparing a regular response: %p" % [ response ]
			response ||= request.response
			return self.fixup_response( request, response )
		end

	rescue => err
		# Propagate Spec failures
		raise if err.class.name =~ /^RSpec::/

		msg = "%s: %s %s" % [ err.class.name, err.message, err.backtrace.first ]
		self.log.error( msg )
		err.backtrace[ 1..-1 ].each {|frame| self.log.debug('  ' + frame) }

		status_info = { :status => HTTP::SERVER_ERROR, :message => msg }
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
		self.log.debug "Strelka::App#handle_request"
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
	def fixup_response( request, response )
		self.log.debug "Fixing up response: %p" % [ response ]
		self.fixup_response_content_type( response )
		self.fixup_head_response( response ) if request.verb == :HEAD
		self.log.debug "  after fixup: %p" % [ response ]

		super
	end


	### If the +response+ doesn't yet have a Content-type header, and the app has
	### defined a default (via App.default_type), set it to the default.
	def fixup_response_content_type( response )
		restype = response.content_type

		if !restype
			if (( default = self.class.default_type ))
				self.log.debug "Setting default content type"
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
	### response. The +otherstuff+ hash can be used to pass headers, etc.
	def finish_with( http_status, message, otherstuff={} )
		status_info = otherstuff.merge( :status => http_status, :message => message )
		throw :finish, status_info
	end


	### Create a response to specified +request+ based on the specified +status_code+ 
	### and +message+.
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

		return response
	end

end # class Strelka::App

