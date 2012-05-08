# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:

require 'loggability'
require 'securerandom'
require 'forwardable'
require 'sequel'
require 'yaml'

require 'strelka' unless defined?( Strelka )
require 'strelka/app' unless defined?( Strelka::App )
require 'strelka/session/default'

# Database session class -- this class offers persistent session data using
# any database that Sequel supports.  It defaults to non-persistent, in memory Sqlite.
#
class Strelka::Session::Db < Strelka::Session::Default
	extend Loggability,
	       Forwardable,
	       Strelka::MethodUtilities

	# Loggability API -- set up logging under the 'strelka' log host
	log_to :strelka


	# Class-instance variables
	@table_name   = :sessions
	@db           = nil
	@dataset      = nil
	@cookie_options = {
		:name => 'strelka-session'
	}

	##
	# The Sequel dataset connection
	singleton_attr_reader :db

	##
	# The Sequel dataset for the sessions table
	singleton_attr_reader :dataset

	##
	# The configured session cookie parameters
	singleton_attr_accessor :cookie_options


	########################################################################
	### C L A S S   M E T H O D S
	########################################################################

	### Configure the session class with the given +options+, which should be a
	### Hash or an object that has a Hash-like interface.
	###
	### Valid options:
	###    cookie     -> A hash that contains valid Strelka::Cookie options
	###    connect    -> The Sequel connection string
	###    table_name -> The name of the sessions table
	def self::configure( options={} )
		options ||= {}

		self.cookie_options.merge!( options[:cookie] ) if options[:cookie]
		@table_name      = options[:table_name]  || :sessions

		@db = options[ :connect ].nil? ?
			 Mongrel2::Config.in_memory_db :
			 Sequel.connect( options[:connect] )
		@db.logger = Loggability[ Mongrel2 ].proxy_for( @db )

		self.initialize_sessions_table
	end


	### Create the initial DB sessions schema if needed, setting the +sessions+
	### attribute to a Sequel dataset on the configured DB table.
	###
	def self::initialize_sessions_table
		if self.db.table_exists?( @table_name )
			self.log.debug "Using existing sessions table for %p" % [ db ]

		else
			self.log.debug "Creating new sessions table for %p" % [ db ]
			self.db.create_table( @table_name ) do
				text :session_id, :index => true
				text :session
				timestamp :created

				primary_key :session_id
			end
		end

		@dataset = self.db[ @table_name ]
	end


	### Load a session instance from storage using the given +session_id+.
	def self::load( session_id )
		session_row = self.dataset.filter( :session_id => session_id ).first
		session = session_row.nil? ? {} : YAML.load( session_row[:session] )
		return new( session_id, session )
	end


	### Save the given +data+ associated with the +session_id+ to the DB.
	def self::save_session_data( session_id, data={} )
		self.db.transaction do
			self.delete_session_data( session_id.to_s )
			self.dataset.insert(
				:session_id => session_id,
				:session    => data.to_yaml,
				:created    => Time.now.utc.to_s
			)
		end
	end


	### Delete the data associated with the given +session_id+ from the DB.
	def self::delete_session_data( session_id )
		self.dataset.filter( :session_id => session_id ).delete
	end


	### Return +true+ if the given +request+ has a session token which corresponds
	### to an existing session key.
	def self::has_session_for?( request )
		id = self.get_existing_session_id( request ) or return false
		return !self.dataset.filter( :session_id => id ).empty?
	end

end # class Strelka::Session::Db

