#!/usr/bin/ruby
#encoding: utf-8

# Exception types used by Strelka classes.

#--
module Strelka

	# A base exception class.
	class Error < ::RuntimeError; end

	# An exception that's raised when there's a problem with a Request.
	class RequestError < Error
		### Create a new RequestError for the specified +request+ object.
		def initialize( request, message, *args )
			@request = request
			super( message, *args )
		end

		# The request that caused the exception
		attr_reader :request

	end # class RequestError

	# An exception raised when there is a problem with an application plugin.
	class PluginError < Error; end

end # module Strelka

