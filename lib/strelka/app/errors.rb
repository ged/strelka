#!/usr/bin/env ruby

require 'strelka' unless defined?( Strelka )
require 'strelka/app' unless defined?( Strelka::App )


# Custom error-handling plugin for Strelka::App.
#
# == Examples
#
# Handle statuses via a callback:
#
#    class MyApp < Strelka::App
#        plugins :errors
#
#        on_status HTTP::NOT_FOUND do |res|
#        end
#
#    end # class MyApp
#
# With the templating plugin, you can also handle it via a custom template.
#
#    class MyApp < Strelka::App
#        plugins :errors, :templating
#
#        layout 'layout.tmpl'
#        templates :missing => 'errors/missing.tmpl'
#
#        on_status HTTP::NOT_FOUND, :missing
#
#    end # class MyApp
#
module Strelka::App::Errors
	extend Strelka::App::Plugin

	DEFAULT_HANDLER_STATUS_RANGE = 400..599

	run_before :routing


	# Class-level functionality
	module ClassMethods # :nodoc:

		@status_handlers = {}

		# The registered status handler callbacks, keyed by numeric HTTP status code
		attr_reader :status_handlers


		### Register a callback for responses that have the specified +status_code+.
		### :TODO: Document all the stuff.
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
		response = nil

		# Catch a finish_with; the status_response will only be non-nil
		status_response = catch( :finish ) do
			response = super
			nil
		end

		# If the app or any plugins threw a finish, look for a handler for the status code
		# and call it if one is found.
		if status_response
			response = request.response
			status = status_response[:status]
			self.log.info "Handling a status response: %d" % [ status ]

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
		self.log.debug "Looking for a status handler for %d responses" % [ status_code ]
		handlers = self.class.status_handlers
		ranges = handlers.keys

		ranges.each do |range|
			return handlers[ range ] if range.include?( status_code )
		end

		return nil
	end


end # module Strelka::App::Errors



