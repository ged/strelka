#!/usr/bin/env ruby

require 'pluginfactory'

require 'strelka' unless defined?( Strelka )
require 'strelka/app' unless defined?( Strelka::App )
require 'strelka/mixins'

# Abstract base class for pluggable routing strategies for the Routing
# plugin.
#
# This class can't be instantiated itself, but it does act as a factory for
# loading and instantiating its subclasses:
#
#     # Create an instance of the default router strategy with the given
#     # routes and options.
#     Strelka::Router.create( 'default', routes, options )
#
# To define your own strategy, you'll need to inherit this class, name it
# <tt>Strelka::App::{Something}Router</tt>, save it in a file named
# <tt>strelka/app/{something}router.rb</tt>, and be sure to override the
# #add_route and #route_request methods.
class Strelka::Router
	include PluginFactory,
	        Strelka::Loggable,
			Strelka::AbstractClass

	### PluginFactory API -- return the Array of directories to search for plugins.
	def self::derivative_dirs
		return ['strelka/router']
	end


	### Create a new router that will route requests according to the specified
	### +routes+.
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

	##
	# :call-seq:
	#   add_route( http_verb, path_array, routing_info )
	#
	# Add a route for the specified +http_verb+, +path_array+, and +routing_info+. The
	# +http_verb+ will be one of the methods from
	# {RFC 2616}[http://tools.ietf.org/html/rfc2616#section-9] as a Symbol (e.g.,
	# +:GET+, +:DELETE+). The +path_array+ will be the route path split up by
	# path separator. The +routing_info+ is a Hash that contains the action
   	# that will be run when the route matches, routing options, and any other
	# routing information associated with the route.
	pure_virtual :add_route


	##
	# :call-seq:
	#   route_request( request )
	#
	# Determine the most-specific route for the specified +request+ and return
	# the routing info Hash.
	pure_virtual :route_request

end # class Strelka::Router
