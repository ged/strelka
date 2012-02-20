#!/usr/bin/env ruby

require 'strelka' unless defined?( Strelka )
require 'strela/app' unless defined?( Strelka::App )

require 'strelka/app/defaultrouter'

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
class Strelka::App::ExclusiveRouter < Strelka::App::DefaultRouter
	include Strelka::Loggable

	######
	public
	######

	### Add a route for the specified +verb+, +path+, and +options+ that will return
	### +action+ when a request matches them.
	def add_route( verb, path, action, options={} )
		re = Regexp.compile( '^' + path.join('/') + '$' )

		# Make the Hash for the specified HTTP verb if it hasn't been created already
		self.routes[ verb ][ re ] = { :options => options, :action => action }
	end

end # class Strelka::App::DefaultRouter
