# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:

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
	include Strelka::Loggable
	extend Forwardable

	# Class-instance variables
	@cookie_name  = DEFAULT_COOKIE_NAME
	@table_name   = :sessions
	@db           = nil
	@dataset      = nil

	class << self
		# The Sequel dataset connection
		attr_reader :db

		# The Sequel dataset for the sessions table
		attr_reader :dataset

		# The name of the cookie that stores the session ID
		attr_accessor :cookie_name
	end


	########################################################################
	### C L A S S   M E T H O D S
	########################################################################

	### Configure the session class with the given +options+, which should be a
	### Hash or an object that has a Hash-like interface.
	###
	### Valid options:
	###    cookie_name  -> Set the name of the session cookie
	###    connect      -> The Sequel connection string
	###    table_name   -> The name of the sessions table
	def self::configure( options={} )
		options ||= {}

		self.cookie_name = options[:cookie_name] || DEFAULT_COOKIE_NAME
		@table_name      = options[:table_name]  || :sessions

		@db = options[ :connect ].nil? ? Sequel.sqlite : Sequel.connect( options[:connect] )
		@db.logger = Strelka.logger

		self.initialize_sessions_table
	end


	### Create the initial DB sessions schema if needed, setting the +sessions+
	### attribute to a Sequel dataset on the configured DB table.
	###
	def self::initialize_sessions_table
		if self.db.table_exists?( @table_name )
			Strelka.log.debug "Using existing sessions table for %p" % [ db ]

		else
			Strelka.log.debug "Creating new sessions table for %p" % [ db ]
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
	def self::save_session_data( session_id, data )
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

end # class Strelka::Session::Db

