#!/usr/bin/env ruby

require 'strelka' unless defined?( Strelka )
require 'strelka/app' unless defined?( Strelka::App )
require 'strelka/app/router'

# Simple (dumb?) request router for Strelka::App-based applications.
class Strelka::App::DefaultRouter < Strelka::App::Router
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
	def initialize( routes=[], options={} )
		@routes = Hash.new {|hash, verb| hash[verb] = {} }

		super
	end


	######
	public
	######

	# A Hash, keyed by Regexps, that contains the routing logic
	attr_reader :routes


	### Add a route for the specified +verb+, +path+, and +options+ that will return
	### +action+ when a request matches them.
	def add_route( verb, path, action, options={} )
		re = Regexp.compile( '^' + path.join('/') )

		# Make the Hash for the specified HTTP verb if it hasn't been 
		self.routes[ verb ][ re ] = { :options => options, :action => action }
	end


	### Determine the most-specific route for the specified +request+ and return
	### the UnboundMethod object of the App that should handle it.
	def route_request( request )
		route = nil
		verb = request.verb
		path = request.app_path || ''
		path.slice!( 0, 1 ) if path.start_with?( '/' ) # Strip the leading '/'

		self.log.debug "Looking for a route for: %p %p" % [ verb, path ]
		verbroutes = @routes[ verb ] or return nil
		match = self.find_longest_match( verbroutes.keys, path ) or return nil
		self.log.debug "  longest match result: %p" % [ match ]

		# The best route is the one with the key of the regexp of the 
		# longest match
		route = verbroutes[ match.regexp ].merge( :match => match )
		route_params = match.names.inject({}) do |hash,name|
			hash[ name ] = match[ name ]
			hash
		end

		# Add routing information to the request, and merge parameters if there are any
		request.notes[ :routing ][ :route ] = route
		request.params.merge!( route_params ) unless route_params.empty?

		# Return the UnboundMethod object for the route to call
		return route[:action]
	end


	#########
	protected
	#########

	### Find the longest match in +patterns+ for the given +path+ and return the MatchData
	### object for it. Returns +nil+ if no match was found.
	def find_longest_match( patterns, path )

		return patterns.inject( nil ) do |longestmatch, pattern|
			self.log.debug "  trying pattern %p; longest match so far: %p" %
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

	end

end # class Strelka::App::DefaultRouter
