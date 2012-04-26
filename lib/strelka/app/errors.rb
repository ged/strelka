# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require 'strelka' unless defined?( Strelka )
require 'strelka/app' unless defined?( Strelka::App )


# Custom error-handling plugin for Strelka::App.
#
#   plugin :errors
#
#   # Handle only status 400 errors
#   on_status HTTP::BAD_REQUEST do |res, status_info|
#       # Do something on 400 errors
#   end
#
#   # Handle any other error in the 4xx range
#   on_status 400..499 do |res, status_info|
#       # Do something on 4xx errors
#   end
#
# If you have the <tt>:templating</tt> plugin loaded, you can substitute a
# Symbol that corresponds with one of the declared templates instead:
#
#   class MyApp < Strelka::App
#       plugins :errors, :templating
#
#       layout 'layout.tmpl'
#       templates :missing => 'errors/missing.tmpl'
#
#       # Load the 'missing' template, wrap it up in the layout
#       # template and render that as the body of the 404
#       # response
#       on_status HTTP::NOT_FOUND, :missing
#
#   end # class MyApp
#
# The template can access the status info hash via the +:status_info+ note
# on the request or response object:
#
#   <!-- error.tmpl -->
#   Sorry, there was a <?call request.notes[:status_info][:status] ?> error:
#   <?escape request.notes[:status_info][:message] ?>.
#
# If you want to do something application-specific for an error, but still use
# the default error-handling, just call finish_with again with the status info
# from your status handler:
#
#    class MyApp < Strelka::App
#        plugins :errors
#
#        # Send an email when an app is going to return a 500 error
#        on_status HTTP::SERVER_ERROR do |res, info|
#            require 'mail'
#            Mail.deliver do
#                from    'app@example.com'
#                to      'team@example.com'
#                subject "SERVER_ERROR: %p [%s]" %
#                        [ self.class, self.class.version_string ]
#                body    "Server error while running %p [%s]: %s" %
#                        [ self.class, self.conn, status.message ]
#            end
#
#            # Finish the transaction
#            finish_with( info )
#        end
#
#        def handle( req )
#            finish_with( HTTP::SERVER_ERROR, "Ack! Something bad happened." )
#        end
#
#    end # class MyApp
#
# See the documentation for ClassMethods.on_status for more details on the
# status-handler block.
#
module Strelka::App::Errors
	extend Strelka::Plugin
	include Strelka::Constants


	# The range of status codes to delegate to an on_status handler that doesn't
	# specify one
	DEFAULT_HANDLER_STATUS_RANGE = 400..599


	# Plugin load order
	run_before :routing


	# Class-level functionality
	module ClassMethods

		@status_handlers = {}

		# The registered status handler callbacks, keyed by Integer Ranges of
		# status codes to which they apply
		attr_reader :status_handlers


		### Extension callback -- add instance variables to extending objects.
		def inherited( subclass )
			super
			subclass.instance_variable_set( :@status_handlers, @status_handlers.dup )
		end


		### Register a callback for responses whose status code is within the specified
		### +range+. Range can either be a single integer HTTP status code, or a Range
		### of the same (e.g., 400..499) for all statuses with that range.
		###
		### If no +range+ is specified, any of the HTTP error statuses will invoke
		### the callback.
		###
		### The block will be called with the response object (a subclass of
		### Mongrel2::Response appropriate for the request type), and a hash of
		### status info that will at least contain the following keys:
		###
		### [+:status+]   the HTTP status code that was passed to Strelka::App#finish_with
		### [+:message+]  the message string that was passed to Strelka::App#finish_with
		###
		def on_status( range=DEFAULT_HANDLER_STATUS_RANGE, template=nil, &block )
			range = Range.new( range, range ) unless range.is_a?( Range )
			methodname = "for_status_%s" % [ range.begin, range.end ].uniq.join('_to_')

			if template
				raise ArgumentError, "template-style callbacks don't take a block" if block
				raise ScriptError, "template-style callbacks require the :templating plugin" unless
					self.respond_to?( :templates )

				block = Proc.new {|*| template }
			end

			define_method( methodname, &block )

			self.status_handlers[ range ] = instance_method( methodname )
		end

	end # module ClassMethods


	### Check for a status response that is hooked, and run the hook if one is found.
	def handle_request( request )
		self.log.debug "[:errors] Wrapping request in custom error-handling."
		response = nil

		# Catch a finish_with; the status_response will only be non-nil
		status_response = catch( :finish ) do

			# Provide our own exception-handling and translate them into server errors
			begin
				response = super
			rescue => err
				self.log.error "%s: %s %s" % [ err.class.name, err.message, err.backtrace.first ]
				err.backtrace[ 1..-1 ].each {|frame| self.log.debug('  ' + frame) }

				finish_with(
					status:    HTTP::SERVER_ERROR,
					message:   err.message,
					headers:   {},
					backtrace: err.backtrace,
					exception: err
				)
			end
			nil
		end

		# If the app or any plugins threw a finish, look for a handler for the status code
		# and call it if one is found.
		if status_response
			request.notes[:status_info] = status_response
			response = request.response
			status = status_response[:status]
			self.log.info "[:errors] Handling a status response: %d" % [ status ]

			# If we can't find a custom handler for this status, re-throw
			# to the default handler instead
			handler = self.status_handler_for( status ) or
				throw( :finish, status_response )

			# The handler is an UnboundMethod, so bind it to the app instance
			# and call it
			response.status = status
			response = handler.bind( self ).call( response, status_response )
		end

		return response
	end


	### Find a status handler for the given +status_code+ and return it as an UnboundMethod.
	def status_handler_for( status_code )
		self.log.debug "[:errors] Looking for a status handler for %d responses" % [ status_code ]
		handlers = self.class.status_handlers
		ranges = handlers.keys

		ranges.each do |range|
			return handlers[ range ] if range.include?( status_code )
		end

		return nil
	end


end # module Strelka::App::Errors



