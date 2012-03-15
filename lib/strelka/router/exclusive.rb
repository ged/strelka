#!/usr/bin/env ruby

require 'strelka' unless defined?( Strelka )
require 'strela/app' unless defined?( Strelka::App )

require 'strelka/router/default'

# Alternative (stricter) router strategy for Strelka::App::Routing plugin.
#
# == Examples
#
#     class MyApp < Strelka::App
#         plugins :routing
#         router :exclusive
#
#         # Unlike the default router, this route will *only* respond to
#         # a request that matches the app's route with no additional path.
#         get '' do
#             # ...
#         end
#
#     end # class MyApp
#
class Strelka::Router::Exclusive < Strelka::Router::Default
	include Strelka::Loggable

	######
	public
	######

	### Add a route for the specified +verb+, +path+, and +options+ that will return
	### +action+ when a request matches them.
	def add_route( verb, path, route )
		re = Regexp.compile( '^' + path.join('/') + '$' )

		# Make the Hash for the specified HTTP verb if it hasn't been created already
		self.routes[ verb ][ re ] = route
	end

end # class Strelka::Router::Default
