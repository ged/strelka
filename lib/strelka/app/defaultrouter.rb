#!/usr/bin/env ruby

require 'strelka' unless defined?( Strelka )
require 'strelka/app' unless defined?( Strelka::App )

# Simple (dumb?) request router for Strelka::App-based applications.
class Strelka::App::DefaultRouter
	include Strelka::Loggable

	### Create a new router that will route requests according to the specified 
	### +routes+. Each route is a tuple of the form:
	###
	###   [
	###     <http_verb>,    # The HTTP verb as a Symbol (e.g., :GET, :POST, etc.)
	###     <path_array>,   # An Array of the parts of the path, as Strings and Regexps.
	###     <action>,       # A #to_proc-able object to invoke when the route is matched
	###     <options_hash>, # The hash of route config options
	###   ]
	def initialize( routes=[] )
		@routes = Hash.new {|routes, verb| routes[verb] = {} }
		routes.each do |tuple|
			self.log.debug "  adding route: %p" % [ tuple ]
			self.add_route( *tuple )
		end 
	end


	######
	public
	######

	# A Hash, keyed by Regexps, that contains the routing logic
	attr_reader :routes


	### Add a route for the specified +verb+, +path+, and +options+ that will return
	### +action+ when a request matches them.
	def add_route( verb, path, action, options={} )
		re = Regexp.compile( path.join('/') )

		# Make the Hash for the specified HTTP verb if it hasn't been 
		self.routes[ verb ][ re ] = { :options => options, :action => action }
	end


	### Determine the most-specific route for the specified +request+ and return
	### the #to_proc-able object that handles it.
	def route_request( request )
		verb = request.verb
		path = request.app_path || ''
		route = nil

		# Strip the leading '/'
		path.slice!( 0, 1 ) if path.start_with?( '/' )

		verbroutes = @routes[ verb ] or return nil
		longestmatch = verbroutes.keys.inject( nil ) do |longestmatch, pattern|
			self.log.debug "Matching pattern %p; longest match so far: %p" %
				[ pattern, longestmatch ]

			# If the pattern doesn't match, keep the longest match and move on to the next
			match = pattern.match( path ) or next longestmatch

			# If there was no previous match, or this match was longer, keep it
			self.log.debug "  matched: %p (size = %d)" % [ match[0], match[0].length ]
			next match if longestmatch.nil? || match[0].length > longestmatch[0].length

			# Otherwise just keep the previous match
			self.log.debug "  kept longer match %p (size = %d)" %
				[ longestmatch[0], longestmatch[0].length ]
			longestmatch
		end

		# If there wasn't a match, abort
		return nil unless longestmatch

		# The best route is the one with the key of the regexp of the 
		# longest match
		route = verbroutes[ longestmatch.regexp ]

		# Bind the method to the app and 
		return route[:action]
	end

end # class Strelka::App::DefaultRouter
