# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require 'inversion'

require 'strelka' unless defined?( Strelka )
require 'strelka/app' unless defined?( Strelka::App )

require 'strelka/plugins'


# A templated content-generation plugin for Strelka::Apps. It uses the
# Inversion[http://deveiate.org/projects/Inversion] templating system.
#
# It adds:
#
# * a preloaded/cached template table
# * a mechanism for fetching templates from the table
# * a global layout template which is automatically wrapped around responses
#
# == Usage
#
# To use it, just load the <tt>:templating</tt> plugin in your app:
#
#   plugins :templating
#
# and declare one or more templates that your application will use:
#
#   templates :console =>   'views/console.tmpl',
#             :proctable => 'partials/proctable.tmpl'
#
# Then, inside your app, you can fetch a copy of one or more of the templates and
# return it as the reponse:
#
#   def handle_request( req )
#       super do
#           res = request.response
#
#           proctable = template :proctable
#           proctable.processes = ProcessList.fetch
#
#           tmpl = template :console
#           tmpl.message = "Everything's up."
#           tmpl.proctable = proctable
#           res.body = tmpl
#
#           return res
#       end
#   end
#
# You can also just return the template if you don't need to do anything else to the
# response.
#
# When returning a template, either in the body of the response or directly, it will
# automatically set a few attributes for commonly-used objects:
#
# request ::          The current Strelka::HTTPRequest
# strelka_version ::  Strelka.version_string( true )
# mongrel2_version :: Mongrel2.version_string( true )
# route ::            If the :routing plugin is loaded, this will be set to the
#                     'routing_info' of the chosen route. See
#                     Strelka::Router#add_route for details.
#
# If your app will *only* be loading and returning a template without doing anything
# with it, you can return just its name:
#
#   def handle_request( req )
#       super { :console }
#   end
#
# It will be loaded, set as the response body, and the above common objects added to it.
#
# === Layouts
#
# Very often, you'll want your app to share a common page layout. To accomplish this, you
# can declare a special layout template:
#
#   layout 'layout.tmpl'
#
# Any template that you return will be set as the 'body' attribute of this layout
# template, and the layout rendered as the body of the response.
#
# Note that if you want any of the "common objects" from above with a layout template,
# you must use the <tt><?import ?></tt> directive to import them:
#
#   <?import request, strelka_version, route ?>
#
module Strelka::App::Templating
	include Strelka::Constants
	extend Strelka::Plugin

	run_before :routing, :negotiation, :errors
	run_after :filters


	# Class methods to add to classes with templating.
	module ClassMethods

		# The map of template names to template file paths.
		@template_map = {}
		attr_reader :template_map

		@layout_template = nil
		attr_accessor :layout_template


		### Extension callback -- add instance variables to extending objects.
		def inherited( subclass )
			super
			subclass.instance_variable_set( :@template_map, @template_map.dup )
			subclass.instance_variable_set( :@layout_template, @layout_template.dup ) if @layout_template
		end


		### Get/set the templates declared for the App.
		def templates( newhash=nil )
			if newhash
				self.template_map.merge!( newhash )
			end

			return self.template_map
		end


		### Declare a template that will act as a wrapper for all other templates
		def layout( tmplpath=nil )
			self.layout_template = tmplpath if tmplpath
			return self.layout_template
		end

	end # module ClassMethods


	### Preload any templates registered with the template map.
	def initialize( * )
		super
		@template_map = self.load_template_map
		@layout = self.load_layout_template
	end


	######
	public
	######

	# The map of template names to Inversion::Template instances.
	attr_reader :template_map

	# The layout template (an Inversion::Template), if one was declarted
	attr_reader :layout


	### Return the template keyed by the given +name+.
	### :TODO: Add auto-reloading,
	def template( name )
		template = self.template_map[ name ] or
			raise ArgumentError, "no %p template registered!" % [ name ]
		template.reload if template.changed?
		return template.dup
	end


	### Load instances for all the template paths specified in the App's class
	### and return them in a hash keyed by name (Symbol).
	def load_template_map
		return self.class.template_map.inject( {} ) do |map, (name, path)|
			map[ name ] = Inversion::Template.load( path )
			map
		end
	end


	### Load an Inversion::Template for the layout template and return it if one was declared.
	### If none was declared, returns +nil+.
	def load_layout_template
		return nil unless ( lt_path = self.class.layout_template )
		return Inversion::Template.load( lt_path )
	end


	### Intercept responses on the way back out and turn them into a Mongrel2::HTTPResponse
	### with a String for its entity body.
	def handle_request( request, &block )
		response = super

		self.log.debug "Templating: examining %p response." % [ response.class ]
		template = nil

		# Response is a template name
		if response.is_a?( Symbol ) && self.template_map.key?( response )
			self.log.debug "  response is a template name (Symbol); using the %p template" % [ response ]
			template = self.template( response )
			response = request.response

		# Template object
		elsif response.is_a?( Inversion::Template )
			self.log.debug "  response is an %p; wrapping it in a Response object" % [ response.class ]
			template = response
			response = request.response

		# Template object already in a Response
		elsif response.is_a?( Mongrel2::Response ) && response.body.is_a?( Inversion::Template )
			template = response.body
			self.log.debug "  response is a %p in the body of a %p" % [ template.class, response.class ]

		# Not templated; returned as-is
		else
			self.log.debug "  response isn't templated; returning it as-is"
			return response
		end

		# Wrap the template in a layout if there is one
		if self.layout
			self.layout.reload if self.layout.changed?
			l_template = self.layout.dup
			self.log.debug "  wrapping response in layout %p" % [ l_template ]
			l_template.body = template
			template = l_template
		end

		# Set some default stuff on the top-level template
		template.request          = request
		template.strelka_version  = Strelka.version_string( true )
		template.mongrel2_version = Mongrel2.version_string( true )
		template.route            = request.notes[:routing][:route]

		# Now render the response body
		self.log.debug "  rendering the template into the response body"
		response.body = template.render
		response.status ||= HTTP::OK

		return response
	end

end # module Strelka::App::Templating


