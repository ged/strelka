#!/usr/bin/env ruby

require 'strelka' unless defined?( Strelka )
require 'strelka/app' unless defined?( Strelka::App )

require 'strelka/app/defaultrouter'
require 'strelka/exceptions'
require 'strelka/app/plugins'

# Sinatra-ish routing logic for Strelka::Apps
#
# This plugin adds the ability to declare hooks for requests based on their
# attributes. The default router (Strelka::App::DefaultRouter) uses only the
# HTTP verb and the path, but you can also define your own router class if
# you want to include other attributes. 
#
# You declare a hook using the HTTP verb, followed by the path, followed by
# a Hash of options and a block that will be called when a matching request
# is handled.
#
# When two or more hooks match the same request, the most-specific match
# wins. The mongrel2 route part of the path is stripped before comparing.
#
# The hooks are given a Strelka::Request object, and are expected to
# return either a Strelka::Response or something that can be made
# into one.
#
# == Examples
# 
# 	class HelloWorld < Strelka::App
#
#       # match any GET request
# 		get do |req|
# 			return req.response << 'Hello, World!'
# 		end
#
#       # match any GET request whose path starts with '/goodbye' 		
# 		get '/goodbye' do |req|
# 			return req.response << "Goodbye, cruel World!"
# 		end
#
#
# 	end # class HelloWorld
# 
# 
module Strelka::App::Routing
	extend Strelka::App::Plugin
	include Strelka::Loggable,
	        Strelka::Constants

	run_after :templating, :filters, :parameters


	# Class methods to add to classes with routing.
	module ClassMethods

		# The list of routes to pass to the Router when the application is created
		attr_reader :routes
		@routes = []

		# The class of object to instantiate for routing
		attr_accessor :routerclass
		@routerclass = Strelka::App::DefaultRouter


		### Return a Hash of the methods defined by routes.
		def route_methods
			return self.instance_methods.grep( /^#{HTTP::RFC2616_VERB_REGEX}(_|$)/ )
		end


		# OPTIONS GET HEAD POST PUT DELETE TRACE CONNECT

		### Define a route for the OPTIONS verb and the given +pattern+.
		def options( pattern='', options={}, &block )
			self.add_route( :OPTIONS, pattern, options, &block )
		end


		### Define a route for the GET verb and the given +pattern+.
		def get( pattern='', options={}, &block )
			self.add_route( :GET, pattern, options, &block )
		end


		### Define a route for the POST verb and the given +pattern+.
		def post( pattern='', options={}, &block )
			self.add_route( :POST, pattern, options, &block )
		end


		### Define a route for the PUT verb and the given +pattern+.
		def put( pattern='', options={}, &block )
			self.add_route( :PUT, pattern, options, &block )
		end


		### Define a route for the DELETE verb and the given +pattern+.
		def delete( pattern='', options={}, &block )
			self.add_route( :DELETE, pattern, options, &block )
		end


		### Define a route for the TRACE verb and the given +pattern+.
		def trace( pattern='', options={}, &block )
			self.add_route( :TRACE, pattern, options, &block )
		end


		### Define a route for the CONNECT verb.
		def connect( options={}, &block )
			self.add_route( :CONNECT, '', options, &block )
		end


		### Get/set the router class to use for mapping requests to handlers to +newclass.
		def router( newclass=nil )
			if newclass
				Strelka.log.info "%p will use the %p router" % [ self, newclass ]
				self.routerclass = newclass
			end

			return self.routerclass
		end


		### Define a route method for the specified +verb+ and +pattern+ with the
		### specified +options+, and the +block+ as its body.
		def add_route( verb, pattern, options={}, &block )

			# Start the name of the route method with the HTTP verb, then split the
			# route pattern into its components
			methodparts = [ verb.upcase ]
			patternparts = self.split_route_pattern( pattern )
			Strelka.log.debug "Split pattern %p into parts: %p" % [ pattern, patternparts ]

			# Make a method name from the directories and the named captures of the patterns 
			# in the route
			patternparts.each do |part|
				if part.is_a?( Regexp )
					methodparts << '_' + part.names.join( '_' )
				else
					methodparts << part
				end
			end
			Strelka.log.debug "  route methodname parts are: %p" % [ methodparts ]
			methodname = methodparts.join( '_' )

			# Define the method using the block from the route as its body
			Strelka.log.debug "  adding route method %p for %p route: %p" % [ methodname, verb, block ]
			define_method( methodname, &block )

			# Remove any existing route for the same verb, patternparts, and options
			# (support for overriding inherited routes)
			self.routes.delete_if do |r|
				r[0] == verb && r[1] == patternparts && r[3] == options
			end

			# Now add all the parts to the routes array for the router created by 
			# instances 
			self.routes << [ verb, patternparts, self.instance_method(methodname), options ]
		end


		### Split the given +pattern+ into its path components and 
		def split_route_pattern( pattern )
			pattern.slice!( 0, 1 ) if pattern.start_with?( '/' )

			return pattern.split( '/' ).collect do |component|

				if component.start_with?( ':' )
					raise ScriptError,
						"parameter-based routing not supported without a 'parameters' plugin" unless
						self.respond_to?( :extract_route_from_constraint )
					self.extract_route_from_constraint( component )
				else
					component
				end
			end
		end


		### Inheritance hook -- inheriting classes inherit their parents' routes table.
		def inherited( subclass )
			super
			subclass.instance_variable_set( :@routes, self.routes.dup )
		end

	end # module ClassMethods


	### Create a new router object for each class with Routing.
	def initialize( * )
		super
		@router ||= self.class.routerclass.new( self.class.routes )
	end


	# The App's router object
	attr_reader :router


	### Dispatch the request using the Router.
	def handle_request( request, &block )
		if handler = self.router.route_request( request )
			return handler.bind( self ).call( request, &block )
		else
			finish_with HTTP::NOT_FOUND, "The requested resource was not found on this server."
		end
	end

end # module Strelka::App::Routing


