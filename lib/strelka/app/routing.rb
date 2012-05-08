# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require 'loggability'

require 'strelka' unless defined?( Strelka )
require 'strelka/app' unless defined?( Strelka::App )

require 'strelka/router'
require 'strelka/exceptions'
require 'strelka/plugins'

# Sinatra-ish routing logic for Strelka::Apps
#
# This plugin adds the ability to declare hooks for requests based on their
# attributes. The default router (Strelka::Router::Default) uses only the
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
#   class HelloWorld < Strelka::App
#
#       plugins :routing
#
#       # match any GET request
#       get do |req|
#           return req.response << 'Hello, World!'
#       end
#
#       # match any GET request whose path starts with '/goodbye'
#       get '/goodbye' do |req|
#           return req.response << "Goodbye, cruel World!"
#       end
#
#
#   end # class HelloWorld
#
# == Routing Strategies
#
# The algorithm used to map requests to routes are defined by an object
# that implements the Strategy pattern. These routing strategies are pluggable,
# so if Mongrel2's the "longest-match wins" routing isn't to your taste,
# you can specify a different one using the +router+ declaration. Strelka
# comes with one alternative "exclusive" router that implements a more
# restrictive mapping:
#
#   class ExclusiveHelloWorld < Strelka::App
#
#       plugins :routing
#       router :exclusive
#
#       # match a GET request for the exact route only
#       get do |req|
#           return req.response << 'Hello, World!'
#       end
#
#       # only match a GET request for '/goodbye'
#       get '/goodbye' do |req|
#           return req.response << "Goodbye, cruel World!"
#       end
#
#      # Every other request responds with a 404
#
#   end # class ExclusiveHelloWorld
#
# == Custom Routers
#
# See the Strelka::Router for information on how to define your own
# routing strategies.
#
module Strelka::App::Routing
	extend Loggability,
	       Strelka::Plugin
	include Strelka::Constants


	# Loggability API -- set up logging under the 'strelka' log host
	log_to :strelka

	# Plugins API -- set up load order
	run_after :templating, :filters, :parameters


	# Class methods to add to classes with routing.
	module ClassMethods # :nodoc:

		# The list of routes to pass to the Router when the application is created
		attr_reader :routes
		@routes = []

		# The name of the routing strategy class to use
		attr_accessor :routerclass
		@routerclass = :default


		### Return a Hash of the methods defined by routes.
		def route_methods
			return self.instance_methods.grep( /^#{HTTP::RFC2616_VERB_REGEX}(_|$)/ )
		end


		### Returns +true+ if the app has a route for the specified +verb+ and +path+.
		def has_route?( http_verb, path )
			path_pattern = self.split_route_pattern( path )
			self.routes.find {|tuple| tuple[0] == http_verb && tuple[1] == path_pattern }
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
				self.log.info "%p router class set to: %p" % [ self, newclass ]
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
			self.log.debug "Split pattern %p into parts: %p" % [ pattern, patternparts ]

			# Make a method name from the directories and the named captures of the patterns
			# in the route
			patternparts.each do |part|
				if part.is_a?( Regexp )
					methodparts << '_' + part.names.join( '_' )
				else
					methodparts << part
				end
			end
			self.log.debug "  route methodname parts are: %p" % [ methodparts ]
			methodname = methodparts.join( '_' )

			# Define the method using the block from the route as its body
			self.log.debug "  adding route method %p for %p route: %p" % [ methodname, verb, block ]
			define_method( methodname, &block )

			# Remove any existing route for the same verb, patternparts, and options
			# (support for overriding inherited routes)
			self.routes.delete_if do |r|
				r[0] == verb && r[1] == patternparts && r[2][:options] == options
			end

			# Now add all the parts to the routes array for the router created by
			# instances
			self.routes << [
				verb,
				patternparts,
				{:action => self.instance_method(methodname), :options => options}
			]
		end


		### Split the given +pattern+ into its path components and
		def split_route_pattern( pattern )
			pattern.slice!( 0, 1 ) if pattern.start_with?( '/' )

			return pattern.split( '/' ).collect do |component|

				if component.start_with?( ':' )
					self.log.debug "translating parameter component %p to a regexp" % [component]
					raise ScriptError,
						"parameter-based routing not supported without a 'parameters' plugin" unless
						self.respond_to?( :paramvalidator )
					component = component.slice( 1..-1 )
					self.paramvalidator.constraint_regexp_for( component )
				else
					component
				end
			end
		end


		### Inheritance hook -- inheriting classes inherit their parents' routes table.
		def inherited( subclass )
			super
			subclass.instance_variable_set( :@routerclass, self.routerclass )
			subclass.instance_variable_set( :@routes, self.routes.dup )
		end

	end # module ClassMethods


	### Create a new router object for each class with Routing.
	def initialize( * )
		super
		@router ||= Strelka::Router.create( self.class.routerclass, self.class.routes )
	end


	# The App's router object
	attr_reader :router


	### Dispatch the request using the Router.
	def handle_request( request, &block )
		self.log.debug "[:routing] Routing request using %p" % [ self.router.class ]

		if route = self.router.route_request( request )
			# Track which route was chosen for later plugins
			request.notes[:routing][:route] = route
			# Bind the action of the route and call it
			return route[:action].bind( self ).call( request, &block )
		else
			finish_with HTTP::NOT_FOUND, "The requested resource was not found on this server."
		end

		self.log.debug "[:routing] Done with routing."
	end

end # module Strelka::App::Routing


