#!/usr/bin/env ruby

require 'inversion'

require 'strelka' unless defined?( Strelka )
require 'strelka/app' unless defined?( Strelka::App )

require 'strelka/app/plugins'


# Templating plugin for Strelka::Apps.
module Strelka::App::Templating
	include Strelka::Constants
	extend Strelka::App::Plugin

	run_before :routing, :filters, :negotiation


	# Class methods to add to classes with templating.
	module ClassMethods

		# The map of template names to template file paths.
		@template_map = {}
		attr_reader :template_map

		@layout_template = nil
		attr_accessor :layout_template


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
	### with a String for its entity body. It will take action if the response is one of:
	###
	### 1. A Mongrel2::Response with an Inversion::Template as its body.
	### 2. An Inversion::Template by itself.
	### 3. A Symbol that matches one of the keys of the registered templates.
	###
	### In all three of these cases, the return value will be a Mongrel2::Request with a
	### body set to the rendered value of the template in question, and with its status
	### set to '200 OK' unless it is already set to something else.
	###
	### If there is a registered layout template, and any of the three cases is true, the
	### layout template is loaded, its #body attributes set to the content template,
	### and its rendered output set as the body of the response instead.
	###
	### Every other response is returned without modification.
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
			l_template = self.layout.dup
			self.log.debug "  wrapping response in layout %p" % [ l_template ]
			l_template.body = template
			template = l_template
		end

		self.log.debug "  rendering the template into the response body"
		response.body = template.render
		response.status ||= HTTP::OK

		return response
	end

end # module Strelka::App::Templating


