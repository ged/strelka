# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require 'set'
require 'sequel'
require 'sequel/extensions/pretty_table'

require 'strelka' unless defined?( Strelka )
require 'strelka/app' unless defined?( Strelka::App )


# RESTful resource utilities for Strelka::App.
#
# This plugin allows you to automatically set up RESTful service resources
# for Sequel::Model-derived classes.
#
# For example, if you have a model class called ACME::Customer for tracking
# customer data, you can set up a RESTful resource in your Strelka app like this:
#
#     require 'strelka'
#     require 'acme/customer'
#
#     class ACME::RestServices < Strelka::App
#         plugins :restresources
#         resource ACME::Customer
#     end
#
# Assuming the primary key for customers is a column called 'id', this will install
# the following routes:
#
#     options 'customers'
#     get 'customers'
#     get 'customers/:id'
#     post 'customers'
#     put 'customers'
#     put 'customers/:id'
#     delete 'customers'
#     delete 'customers/:id'
#
# The restresources plugin depends on the routing[Strelka::App::Routing],
# negotiation[Strelka::App::Negotiation], and
# parameters[Strelka::App::Parameters] plugins, and will load them
# automatically if they haven't been already.
#
# Stuff left to do:
#
# * Composite resources generated from associations
# * Honor If-unmodified-since and If-match headers
# * Caching support (ETag, If-modified-since)
# * Means of tailoring responses for requests for which the response
#   isn't clearly specified in the RFC (DELETE /resource)
# * Sequel plugin for adding links to serialized representations
module Strelka::App::RestResources
	extend Strelka::Plugin

	# Resource route option defaults
	DEFAULTS = {
		prefix:           '',
		name:             nil,
		readonly:         false,
		use_transactions: true,
	}.freeze


	# Class methods to add to classes with REST resources.
	module ClassMethods # :nodoc:
		include Sequel::Inflections,
		        Strelka::Constants

		# Set of verbs that are valid for a resource, keyed by the resource path
		@resource_verbs = Hash.new {|h,k| h[k] = Set.new }

		# Global options
		@service_options = DEFAULTS.dup

		# The list of REST routes assigned to Sequel::Model objects
		attr_reader :resource_verbs

		# The global service options hash
		attr_reader :service_options


		### Extension callback -- overridden to also install dependencies.
		def self::extended( obj )
			super

			# Enable text tables for text/plain responses
			Sequel.extension( :pretty_table )

			# Load the plugins this one depends on if they aren't already
			obj.plugins :routing, :negotiation, :parameters

			# Use the 'exclusive' router instead of the more-flexible
			# Mongrel2-style default one
			obj.router :exclusive
		end


		### Inheritance callback -- copy plugin data to inheriting subclasses.
		def inherited( subclass )
			super

			verbs_copy = Strelka::DataUtilities.deep_copy( self.resource_verbs )
			subclass.instance_variable_set( :@resource_verbs, verbs_copy )

			opts_copy = Strelka::DataUtilities.deep_copy( self.service_options )
			subclass.instance_variable_set( :@service_options, opts_copy )
		end


		### Set the prefix for all following resource routes to +route+.
		def resource_prefix( route )
			self.service_options[ :prefix ] = route
		end


		### Expose the specified +rsrcobj+ (which should be an object that responds to #dataset
		### and returns a Sequel::Dataset)
		def resource( rsrcobj, options={} )
			self.log.debug "Adding REST resource for %p" % [ rsrcobj ]
			options = self.service_options.merge( options )

			# Add a parameter for the primary key
			pkey = rsrcobj.primary_key
			pkey_schema = rsrcobj.db_schema[ pkey.to_sym ] or
				raise ArgumentError,
					"cannot generate services for %p: resource has no schema" % [ rsrcobj ]
			self.param( pkey, pkey_schema[:type] ) unless
				self.paramvalidator.param_names.include?( pkey.to_s )

			# Figure out what the resource name is, and make the route from it
			name = options[:name] || rsrcobj.implicit_table_name
			route = [ options[:prefix], name ].compact.join( '/' )

			# Ensure validated parameters are untainted
			self.untaint_all_constraints

			# Make and install handler methods
			self.log.debug "  adding readers"
			self.add_options_handler( route, rsrcobj, options )
			self.add_read_handler( route, rsrcobj, options )
			self.add_collection_read_handler( route, rsrcobj, options )

			# Add handler methods for the mutator parts of the API unless
			# the resource is read-only
			if options[:readonly]
				self.log.debug "  skipping mutators (read-only set)"
			else
				self.add_collection_create_handler( route, rsrcobj, options )
				self.add_update_handler( route, rsrcobj, options )
				self.add_collection_update_handler( route, rsrcobj, options )
				self.add_delete_handler( route, rsrcobj, options )
				self.add_collection_deletion_handler( route, rsrcobj, options )
			end

			# Add any composite resources based on the +rsrcobj+'s associations
			self.add_composite_resource_handlers( route, rsrcobj, options )
		end


		### Add a handler method for discovery for the specified +rsrcobj+.
		### OPTIONS /resources
		def add_options_handler( route, rsrcobj, options )
			# :TODO: Documentation for HTML mode (possibly using http://swagger.wordnik.com/)
			self.log.debug "Adding OPTIONS handler for %s (%p)" % [ route, rsrcobj ]
			self.add_route( :OPTIONS, route, options ) do |req|
				self.log.debug "OPTIONS handler!"
				res = req.response

				# Gather up metadata describing the resource
				verbs = self.class.resource_verbs[ route ].sort
				columns = rsrcobj.allowed_columns || rsrcobj.columns
				attributes = columns.each_with_object({}) do |col, hash|
					hash[ col ] = rsrcobj.db_schema[ col ][:type]
				end

				self.log.debug "  making a reply with Allowed: %s" % [ verbs.join(', ') ]
				res.header.allowed = verbs.join(', ')
				res.for( :json, :yaml ) do |req|
					{
						'methods' => verbs,
						'attributes' => attributes,
					}
				end
				res.for( :text ) do
					"Methods: #{verbs.join(', ')}\n" +
					"Attributes: \n" +
					attributes.map {|name,type| "  "}
				end


				return res
			end

			self.resource_verbs[ route ] << :OPTIONS
		end


		### Add a handler method for reading a single instance of the specified +rsrcobj+, which
		### should be a Sequel::Model class or a ducktype-alike. GET /resources/{id}
		def add_read_handler( route_prefix, rsrcobj, options )
			pkey = rsrcobj.primary_key
			route = "#{route_prefix}/:#{pkey}"

			self.log.debug "Creating handler for reading a single %p: GET %s" % [ rsrcobj, route ]
			self.add_route( :GET, route, options ) do |req|
				finish_with( HTTP::BAD_REQUEST, req.params.error_messages.join("\n") ) unless
					req.params.okay?

				id = req.params[ pkey ]
				resource = rsrcobj[ id ] or
					finish_with( HTTP::NOT_FOUND, "No such %s [%p]" % [rsrcobj.table_name, id] )

				res = req.response
				res.for( :json, :yaml ) { resource }
				res.for( :text ) { Sequel::PrettyTable.string(resource) }

				return res
			end

			self.resource_verbs[ route_prefix ] << :GET << :HEAD
		end


		### Add a handler method for reading a collection of the specified +rsrcobj+, which should
		### be a Sequel::Model class or a ducktype-alike.
		### GET /resources
		def add_collection_read_handler( route, rsrcobj, options )
			self.log.debug "Creating handler for reading collections of %p: GET %s" %
				[ rsrcobj, route ]

			# Make a column regexp for validating the order field
			colunion = Regexp.union( (rsrcobj.allowed_columns || rsrcobj.columns).map(&:to_s) )
			colre = /^(?<column>#{colunion})$/

			self.add_route( :GET, route, options ) do |req|
				# Add validations for limit, offset, and order parameters
				req.params.add :limit, :integer
				req.params.add :offset, :integer
				req.params.add :order, colre

				finish_with( HTTP::BAD_REQUEST, req.params.error_messages.join("\n") ) unless
					req.params.okay?

				limit, offset, order = req.params.values_at( :limit, :offset, :order )
				res = req.response

				dataset = rsrcobj.dataset
				if order
					order = Array( order ).map( &:to_sym )
					self.log.debug "Ordering result set by %p" % [ order ]
					dataset = dataset.order( *order )
				end

				if limit
					self.log.debug "Limiting result set to %p records" % [ limit ]
					dataset = dataset.limit( limit, offset )
				end

				self.log.debug "Returning collection: %s" % [ dataset.sql ]
				res.for( :json, :yaml ) { dataset.all }
				res.for( :text ) { Sequel::PrettyTable.string(dataset) }

				return res
			end

			self.resource_verbs[ route ] << :GET << :HEAD
		end


		### Add a handler method for creating a new instance of +rsrcobj+.
		### POST /resources
		def add_collection_create_handler( route, rsrcobj, options )
			self.log.debug "Creating handler for creating %p resources: POST %s" %
				[ rsrcobj, route ]

			self.add_route( :POST, route, options ) do |req|
				add_resource_params( req, rsrcobj )
				finish_with( HTTP::BAD_REQUEST, req.params.error_messages.join(", ") ) unless
					req.params.okay?

				resource = rsrcobj.new( req.params.valid )

				# Save it in a transaction, erroring if any of 'em fail validations
				begin
					resource.save
				rescue Sequel::ValidationFailed => err
					finish_with( HTTP::BAD_REQUEST, err.message )
				end

				# :TODO: Eventually, this should be factored out into the Sequel plugin
				resuri = [ req.base_uri, route, resource.pk ].join( '/' )

				res = req.response
				res.status = HTTP::CREATED
				res.headers.location = resuri
				res.headers.content_location = resuri

				res.for( :json, :yaml ) { resource }

				return res
			end

			self.resource_verbs[ route ] << :POST
		end


		### Add a handler method for updating an instance of +rsrcobj+.
		### PUT /resources/{id}
		def add_update_handler( route_prefix, rsrcobj, options )
			pkey = rsrcobj.primary_key
			route = "#{route_prefix}/:#{pkey}"

			self.log.debug "Creating handler for creating %p resources: POST %s" %
				[ rsrcobj, route ]
			self.add_route( :PUT, route, options ) do |req|
				add_resource_params( req, rsrcobj )
				finish_with( HTTP::BAD_REQUEST, req.params.error_messages.join(", ") ) unless
					req.params.okay?

				id = req.params[ pkey ]
				resource = rsrcobj[ id ] or
					finish_with( HTTP::NOT_FOUND, "no such %s [%p]" % [ rsrcobj.name, id ] )

				newvals = req.params.valid
				newvals.delete( pkey.to_sym )
				self.log.debug "Updating %p with new values: %p" % [ resource, newvals ]

				begin
					resource.update( newvals )
				rescue Sequel::Error => err
					finish_with( HTTP::BAD_REQUEST, err.message )
				end

				res = req.response
				res.status = HTTP::NO_CONTENT

				return res
			end

			self.resource_verbs[ route_prefix ] << :PUT
		end


		### Add a handler method for updating all instances of +rsrcobj+ collection.
		### PUT /resources
		def add_collection_update_handler( route, rsrcobj, options )
			pkey = rsrcobj.primary_key
			self.log.debug "Creating handler for updating every %p resources: PUT %s" %
				[ rsrcobj, route ]

			self.add_route( :PUT, route, options ) do |req|
				add_resource_params( req, rsrcobj )
				finish_with( HTTP::BAD_REQUEST, req.params.error_messages.join(", ") ) unless
					req.params.okay?

				newvals = req.params.valid
				newvals.delete( pkey.to_s )
				self.log.debug "Updating %p with new values: %p" % [ rsrcobj, newvals ]

				# Save it in a transaction, erroring if any of 'em fail validations
				begin
					rsrcobj.db.transaction do
						rsrcobj.update( newvals )
					end
				rescue Sequel::ValidationFailed => err
					finish_with( HTTP::BAD_REQUEST, err.message )
				end

				res = req.response
				res.status = HTTP::NO_CONTENT

				return res
			end

			self.resource_verbs[ route ] << :PUT
		end


		### Add a handler method for deleting an instance of +rsrcobj+ with +route_prefix+ as the
		### base URI path.
		### DELETE /resources/{id}
		def add_delete_handler( route_prefix, rsrcobj, options )
			pkey = rsrcobj.primary_key
			route = "#{route_prefix}/:#{pkey}"

			self.add_route( :DELETE, route, options ) do |req|
				finish_with( HTTP::BAD_REQUEST, req.params.error_messages.join(", ") ) unless
					req.params.okay?

				id = req.params[ pkey ]

				if resource = rsrcobj[ id ]
					self.log.debug "Deleting %p [%p]" % [ resource.class, id ]

					begin
						resource.destroy
					rescue Sequel::Error => err
						finish_with( HTTP::BAD_REQUEST, err.message )
					end
				end

				res = req.response
				res.status = HTTP::NO_CONTENT

				return res
			end

			self.resource_verbs[ route_prefix ] << :DELETE
		end


		### Add a handler method for deleting all instances of +rsrcobj+ collection with +route+
		### as the base URI path.
		### DELETE /resources
		def add_collection_deletion_handler( route, rsrcobj, options )
			pkey = rsrcobj.primary_key
			self.log.debug "Creating handler for deleting every %p resources: DELETE %s" %
				[ rsrcobj, route ]

			self.add_route( :DELETE, route, options ) do |req|
				self.log.debug "Deleting all %p objects" % [ rsrcobj ]

				# Save it in a transaction, erroring if any of 'em fail validations
				begin
					rsrcobj.db.transaction do
						rsrcobj.each {|obj| obj.destroy }
					end
				rescue Sequel::Error => err
					finish_with( HTTP::BAD_REQUEST, err.message )
				end

				res = req.response
				res.status = HTTP::NO_CONTENT

				return res
			end

			self.resource_verbs[ route ] << :DELETE
		end


		### Add routes for any associations +rsrcobj+ has as composite resources.
		def add_composite_resource_handlers( route_prefix, rsrcobj, options )

			# Add a method for each dataset method that only has a single argument
			# :TODO: Support multiple args? (customers/by_city_state/{city}/{state})
			rsrcobj.dataset_methods.each do |name, proc|
				if proc.parameters.length > 1
					self.log.debug "  skipping dataset method %p: more than 1 argument" % [ name ]
					next
				end

				# Use the name of the dataset block's parameter
				# :TODO: Handle the case where the parameter name doesn't match a column
				#        or a parameter-type more gracefully.
				unless proc.parameters.empty?
					param = proc.parameters.first[1]
					route = "%s/%s/:%s" % [ route_prefix, name, param ]
					self.log.debug "  route for dataset method %s: %s" % [ name, route ]
					self.add_dataset_read_handler( route, rsrcobj, name, param, options )
				end
			end

			# Add composite service routes for each association
			self.log.debug "Adding composite resource routes for %p" % [ rsrcobj ]
			rsrcobj.association_reflections.each do |name, refl|
				pkey = rsrcobj.primary_key
				route = "%s/:%s/%s" % [ route_prefix, pkey, name ]
				self.log.debug "  route for associated %p objects via the %s association: %s" %
					[ refl[:class_name], name, route ]
				self.add_composite_read_handler( route, rsrcobj, name, options )
			end

		end


		### Add a GET route for the dataset method +dsname+ for the given +rsrcobj+ at the
		### given +path+.
		def add_dataset_read_handler( path, rsrcobj, dsname, param, options )
			self.log.debug "Adding dataset method read handler: %s" % [ path ]

			config = rsrcobj.db_schema[ param ] or
				raise ArgumentError, "no such column %p for %p" % [ param, rsrcobj ]
			param( param, config[:type] )

			self.add_route( :GET, path, options ) do |req|
				self.log.debug "Resource dataset GET request for dataset %s on %p" %
					[ dsname, rsrcobj ]
				finish_with( HTTP::BAD_REQUEST, req.params.error_messages.join("\n") ) unless
					req.params.okay?

				# Get the parameter and make the dataset
				res = req.response
				arg = req.params[ param ]
				dataset = rsrcobj.send( dsname, arg )
				self.log.debug "  dataset is: %p" % [ dataset ]

				# Apply offset and limit if they're present
				limit, offset = req.params.values_at( :limit, :offset )
				if limit
					self.log.debug "  limiting result set to %p records" % [ limit ]
					dataset = dataset.limit( limit, offset )
				end

				# Fetch and return the records as JSON or YAML
				# :TODO: Handle other mediatypes
				self.log.debug "  returning collection: %s" % [ dataset.sql ]
				res.for( :json, :yaml ) { dataset.all }
				res.for( :text ) { Sequel::PrettyTable.string(dataset) }

				return res
			end
		end


		### Add a GET route for the specified +association+ of the +rsrcobj+ at the given
		### +path+.
		def add_composite_read_handler( path, rsrcobj, association, options )
			self.log.debug "Adding composite read handler for association: %s" % [ association ]

			pkey = rsrcobj.primary_key
			colunion = Regexp.union( (rsrcobj.allowed_columns || rsrcobj.columns).map(&:to_s) )
			colre = /^(?<column>#{colunion})$/

			self.add_route( :GET, path, options ) do |req|

				# Add validations for limit, offset, and order parameters
				req.params.add :limit, :integer
				req.params.add :offset, :integer
				req.params.add :order, colre
				finish_with( HTTP::BAD_REQUEST, req.params.error_messages.join("\n") ) unless
					req.params.okay?

				# Fetch the primary key from the parameters
				res = req.response
				id = req.params[ pkey ]

				# Look up the resource, and if it exists, use it to fetch its associated
				# objects
				resource = rsrcobj[ id ] or
					finish_with( HTTP::NOT_FOUND, "No such %s [%p]" % [rsrcobj.table_name, id] )

				limit, offset, order = req.params.values_at( :limit, :offset, :order )
				dataset = resource.send( "#{association}_dataset" )

				# Apply the order parameter if it exists
				if order
					order = Array( order ).map( &:to_sym )
					self.log.debug "Ordering result set by %p" % [ order ]
					dataset = dataset.order( *order )
				end

				# Apply limit and offset parameters if they exist
				if limit
					self.log.debug "Limiting result set to %p records" % [ limit ]
					dataset = dataset.limit( limit, offset )
				end

				# Fetch and return the records as JSON or YAML
				# :TODO: Handle other mediatypes
				self.log.debug "Returning collection: %s" % [ dataset.sql ]
				res.for( :json, :yaml ) { dataset.all }
				res.for( :text ) { Sequel::PrettyTable.string(dataset) }

				return res
			end
		end


	end # module ClassMethods


	### This is just here for logging.
	def handle_request( * ) # :nodoc:
		self.log.debug "[:restresources] handling request for REST resource."
		super
	end


	#######
	private
	#######

	### Add parameter validations for the given +columns+ of the specified resource object +rsrcobj+
	### to the specified +req+uest. 
	def add_resource_params( req, rsrcobj, *columns )
		columns = rsrcobj.allowed_columns || rsrcobj.columns if columns.empty?

		columns.each do |col|
			config = rsrcobj.db_schema[ col ] or
				raise ArgumentError, "no such column %p for %p" % [ col, rsrcobj ]
			req.params.add( col, config[:type] ) unless req.params.param_names.include?( col.to_s )
		end

	end

end # module Strelka::App::RestResources
