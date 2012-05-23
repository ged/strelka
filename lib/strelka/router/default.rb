# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require 'loggability'

require 'strelka' unless defined?( Strelka )
require 'strelka/app' unless defined?( Strelka::App )
require 'strelka/router'

# Simple (dumb?) request router for Strelka::App-based applications.
class Strelka::Router::Default < Strelka::Router
	extend Loggability
	include Strelka::Constants,
	        Strelka::ResponseHelpers

	### Create a new router that will route requests according to the specified
	### +routes+. Each route is a tuple of the form:
	###
	###   [
	###     <http_verb>,    # The HTTP verb as a Symbol (e.g., :GET, :POST, etc.)
	###     <path_array>,   # An Array of the parts of the path, as Strings and Regexps.
	###     <route>,        # A hash of routing data built by the Routing plugin
	###   ]
	def initialize( routes=[], options={} )
		@routes = Hash.new {|hash, path| hash[path] = {} }

		routes.each {|r| self.add_route( *r ) }

		super
	end


	######
	public
	######

	# A Hash, keyed by Regexps, that contains the routing logic
	attr_reader :routes


	### Add a route for the specified +verb+, +path+, and +options+ that will return
	### +action+ when a request matches them.
	def add_route( verb, path, route )
		re = Regexp.compile( '^' + path.join('/') )

		# Add the route keyed by path regex and HTTP verb
		self.routes[ re ][ verb ] = route
	end


	### Determine the most-specific route for the specified +request+ and return
	### the UnboundMethod object of the App that should handle it.
	def route_request( request )
		route = nil
		path  = request.app_path || ''
		verb  = request.verb

		path.slice!( 0, 1 ) if path.start_with?( '/' ) # Strip the leading '/'
		self.log.debug "Looking for routes for: %p %p" % [ verb, path ]
		match = self.find_longest_match( self.routes.keys, path ) or return nil
		self.log.debug "  longest match result: %p" % [ match ]
		routekey = match.regexp

		# Pick the appropriate route based on the HTTP verb of the request. HEAD requests
		# use the GET route. If there isn't a defined route for the request's verb
		# send a 405 (Method Not Allowed) response
		verb       = :GET if verb == :HEAD
		verbroutes = self.routes[ routekey ]
		route      = verbroutes[ verb ] or not_allowed_response( verbroutes.keys )

		# Inject the parameters that are part of the route path (/foo/:id) into
		# the parameters hash. They'll be the named match-groups in the matching
		# Regex.
		route_params = match.names.each_with_object({}) do |name, hash|
			hash[ name ] = match[ name ]
		end

		# Add routing information to the request, and merge parameters if there are any
		request.params.merge!( route_params ) unless route_params.empty?

		# Return the routing data that should be used
		return route
	end


	### Build an HTTP Allowed header out of the +allowed_verbs+ and throw a 405 response.
	###
	def not_allowed_response( allowed_verbs )
		allowed_verbs << :HEAD if allowed_verbs.include?( :GET )
		allowed_hdr = allowed_verbs.map {|verb| verb.to_s.upcase }.join( ', ' )
		finish_with( HTTP::METHOD_NOT_ALLOWED, 'Method not allowed.', allow: allowed_hdr )
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

end # class Strelka::Router::Default
