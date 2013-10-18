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
# app ::              The application object (Strelka::App instance).
# strelka_version ::  Strelka.version_string( true )
# mongrel2_version :: Mongrel2.version_string( true )
# ruby_version ::     The RUBY_VERSION of the running interpreter.
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
# :TODO: Explain how returning things other than responses doesn't work well with
#        :filters and maybe other plugins that run inside :templating.
#
#
# === Layouts
#
# Very often, you'll want all or most of the views in your app to share a common page
# layout. To accomplish this, you can declare a layout template:
#
#   layout 'layout.tmpl'
#
# Any template that you return will be set as the 'body' attribute of this layout
# template (which you'd place into the layout with <tt><?attr body ?></tt>) and the
# layout rendered as the body of the response.
#
# Note that if you want any of the "common objects" from above with a layout template,
# they'll be set on it since it's the top-level template, but you can still access them
# using the <tt><?import ?></tt> directive:
#
#   <?import request, strelka_version, route ?>
#
#
# == Template Locations
#
# Inversion looks for templates in a load path much like Ruby does for libraries that
# you 'require'. It contains just the current working directory by default. You can add
# your own template directories via the config file (under +template_paths+ in
# the +templates+ section), or programmatically from your application, but very often you'll
# want to distribute templates with the application gem.
#
# The plugin supports this by looking for a +templates/+ directory under your gem's
# data directory. If it finds such a directory for any loaded gem that has a Strelka dependency,
# it appends it to Inversion's +template_paths+. This also works for plugins, should you
# write your own, and want to provide some default templates. See the 'laika-fancyerrors'
# gem for an example of this.
#
module Strelka::App::Templating
	include Strelka::Constants
	extend Strelka::Plugin,
	       Loggability


	# Loggability API -- log to strelka's logger
	log_to :strelka

	# Run order
	run_outside :routing, :negotiation, :errors, :filters


	### Return an Array of Pathnames to all directories named 'templates' under the
	### data dirctories of loaded gems which have a dependency on Strelka.
	def self::discover_template_dirs
		directories = Strelka::Discovery.discover_data_dirs.values.flatten

		self.log.debug "Discovered data directories: %p" % [ directories ]

		return directories.inject( [] ) do |array, dir|
			pattern = File.join( dir, 'templates' )
			self.log.debug "  adding: %s" % [ pattern ]
			array += Pathname.glob( pattern )
		end
	end


	### Inclusion callback -- add the plugin's templates directory right before activation
	### so loading the config doesn't clobber it.
	def self::included( mod )

		# Add the plugin's template directory to Inversion's template path
		dirs = self.discover_template_dirs
		self.log.info "Discovered template directories: %p" % [ dirs ]
		Inversion::Template.template_paths.concat( dirs )

		super
	end


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

	# The layout template (an Inversion::Template), if one was declared
	attr_accessor :layout


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
			enc = Encoding.default_internal || Encoding::UTF_8
			map[ name ] = Inversion::Template.load( path, encoding: enc )
			map
		end
	end


	### Load an Inversion::Template for the layout template and return it if one was declared.
	### If none was declared, returns +nil+.
	def load_layout_template
		return nil unless ( lt_path = self.class.layout_template )
		enc = Encoding.default_internal || Encoding::UTF_8
		return Inversion::Template.load( lt_path, encoding: enc )
	end


	### Intercept responses on the way back out and turn them into a Mongrel2::HTTPResponse
	### with a String for its entity body.
	def handle_request( request, &block )
		response = super

		self.log.debug "Templating: examining %p response." % [ response.class ]
		template = self.extract_template_from_response( response ) or
			return response

		# Wrap the template in a layout if there is one
		template = self.wrap_in_layout( template, request )

		# Set some default stuff on the top-level template
		self.set_common_attributes( template, request )

		# Now render the response body
		self.log.debug "  rendering the template into the response body"
		response = request.response unless response.is_a?( Mongrel2::Response )
		response.body = template.render
		response.status ||= HTTP::OK

		return response
	end


	### Fetch the template from the +response+ (if there is one) and return it. If
	### +response+ itself is a template.
	def extract_template_from_response( response )

		# Response is a template name
		if response.is_a?( Symbol ) && self.template_map.key?( response )
			self.log.debug "  response is a template name (Symbol); using the %p template" % [ response ]
			return self.template( response )

		# Template object
		elsif response.respond_to?( :render )
			self.log.debug "  response is a #renderable %p; returning it as-is" % [ response.class ]
			return response

		# Template object already in a Response
		elsif response.is_a?( Mongrel2::Response ) && response.body.respond_to?( :render )
			self.log.debug "  response is a %p in the body of a %p" % [ response.body.class, response.class ]
			return response.body

		# Not templated; returned as-is
		else
			self.log.debug "  response isn't templated; returning nil"
			return nil
		end
	end


	### Wrap the specified +content+ template in the layout template and
	### return it. If there isn't a layout declared, just return +content+ as-is.
	def wrap_in_layout( content, request )
		return content unless self.layout

		self.layout.reload if self.layout.changed?
		l_template = self.layout.dup
		self.log.debug "  wrapping response in layout %p" % [ l_template ]
		l_template.body = content

		return l_template
	end


	### Set some default values from the +request+ in the given top-level +template+.
	def set_common_attributes( template, request )
		template.request          = request
		template.app              = self
		template.strelka_version  = Strelka.version_string( true )
		template.mongrel2_version = Mongrel2.version_string( true )
		template.ruby_version     = RUBY_VERSION
		template.route            = request.notes[:routing][:route]
	end

end # module Strelka::App::Templating


