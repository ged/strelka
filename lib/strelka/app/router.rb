#!/usr/bin/env ruby

require 'pluginfactory'

require 'strelka' unless defined?( Strelka )
require 'strelka/app' unless defined?( Strelka::App )
require 'strelka/mixins'

# Abstract base class for pluggable routing strategies for the Routing
# plugin.
#
class Strelka::App::Router
	include PluginFactory,
	        Strelka::Loggable,
			Strelka::AbstractClass

	### PluginFactory API -- return the Array of directories to search for plugins.
	def self::derivative_dirs
		return ['strelka/app']
	end


	### Create a new router that will route requests according to the specified
	### +routes+. Each route is a tuple of the form:
	###
	###   [
	###     <http_verb>,    # The HTTP verb as a Symbol (e.g., :GET, :POST, etc.)
	###     <path_array>,   # An Array of the parts of the path, as Strings and Regexps.
	###     <action>,       # A #to_proc-able object to invoke when the route is matched
	###     <options_hash>, # The hash of route config options
	###   ]
	###
	### If the optional +options+ hash is specified, it is passed to the router
	### strategy.
	def initialize( routes=[], options={} )
		routes.each do |tuple|
			self.log.debug "  adding route: %p" % [ tuple ]
			self.add_route( *tuple )
		end
	end


	######
	public
	######

	### Document-method: add_route
	### Add a route for the specified +verb+, +path+, and +options+ that will return
	### +action+ when a request matches them.
	pure_virtual :add_route


	### Document-method: route_request
	### Determine the most-specific route for the specified +request+ and return
	### the UnboundMethod object of the App that should handle it.
	pure_virtual :route_request

end # class Strelka::App::Router
