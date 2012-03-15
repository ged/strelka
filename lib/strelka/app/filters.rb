# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require 'strelka' unless defined?( Strelka )
require 'strelka/app' unless defined?( Strelka::App )


# Request/response filters plugin for Strelka::App.
module Strelka::App::Filters
	extend Strelka::App::Plugin

	run_before :routing, :templating


	# Class methods to add to classes with routing.
	module ClassMethods # :nodoc:

		# Default filters hash
		@filters = { :request => [], :response => [], :both => [] }

		# The list of filters
		attr_reader :filters


		### Get/set the router class to use for mapping requests to handlers to +newclass.
		def filter( which=:both, &block )
			which = which.to_sym
			raise ArgumentError, "invalid filter stage %p; expected one of: %p" %
				[ which, self.filters.keys ] if !self.filters.key?( which )
			self.filters[ which ] << block
		end


		### Return filters which should be applied to requests, i.e., those with a +which+ of
		### :request or :both.
		def request_filters
			return self.filters[ :request ] + self.filters[ :both ]
		end


		### Return filters which should be applied to responses, i.e., those with a +which+ of
		### :response or :both.
		def response_filters
			return self.filters[ :both ] + self.filters[ :response ]
		end

	end # module ClassMethods


	### Apply filters to the given +request+ before yielding back to the App, then apply
	### filters to the response that comes back.
	def handle_request( request )
		self.apply_request_filters( request )
		response = super
		self.apply_response_filters( response )

		return response
	end


	### Apply :request and :both filters to +request+.
	def apply_request_filters( request )
		self.log.debug "Applying request filters:"
		self.class.request_filters.each do |filter|
			self.log.debug "  filter: %p" % [ filter ]
			filter.call( request )
		end
	end


	### Apply :both and :response filters to +response+.
	def apply_response_filters( response )
		self.log.debug "Applying response filters:"
		self.class.response_filters.each do |filter|
			self.log.debug "  filter: %p" % [ filter ]
			filter.call( response )
		end
	end

end # module Strelka::App::Filters


