# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:

require 'loggability'
require 'securerandom'
require 'forwardable'

require 'strelka' unless defined?( Strelka )
require 'strelka/app' unless defined?( Strelka::App )
require 'strelka/cookie'
require 'strelka/session'
require 'strelka/mixins'

# Default session class -- simple in-memory, cookie-based base-bones session.
#
# == Hash Interface
#
# The following methods are delegated to the inner Hash via the #namespaced_hash method:
# #[], #[]=, #delete, #key?
class Strelka::Session::Default < Strelka::Session
	extend Loggability,
	       Forwardable,
	       Strelka::MethodUtilities,
	       Strelka::Delegation
	include Strelka::DataUtilities

	# Default configuration
	DEFAULT_COOKIE_OPTIONS = {
		:name => 'strelka-session'
	}.freeze


	# Class-instance variables
	@cookie_options = DEFAULT_COOKIE_OPTIONS.dup
	@sessions = {}

	##
	# In-memory session store
	singleton_attr_reader :sessions

	##
	# The configured session cookie parameters
	singleton_attr_accessor :cookie_options


	### Configure the session class with the given +options+, which should be a
	### Hash or an object that has a Hash-like interface. Sets cookie options
	### for the session if the +:cookie+ key is set.
	def self::configure( options=nil )
		if options
			self.cookie_options.merge!( options[:cookie] ) if options[:cookie]
		else
			self.cookie_options = DEFAULT_COOKIE_OPTIONS.dup
		end
	end


	### Load a session instance from storage using the given +session_id+ and return
	### it. Returns +nil+ if no session could be loaded.
	def self::load_session_data( session_id )
		return Strelka::DataUtilities.deep_copy( self.sessions[session_id] )
	end


	### Save the given +data+ to memory associated with the given +session_id+.
	def self::save_session_data( session_id, data )
		self.sessions[ session_id ] = Strelka::DataUtilities.deep_copy( data )
	end


	### Delete the data associated with the given +session_id+ from memory.
	def self::delete_session_data( session_id )
		self.sessions.delete( session_id )
	end


	### Try to fetch a session ID from the specified +request+, returning +nil+
	### if there isn't one.
	def self::get_existing_session_id( request )
		cookie = request.cookies[ self.cookie_options[:name] ] or return nil

		if cookie.value =~ /^([[:xdigit:]]+)$/i
			return $1.untaint
		else
			self.log.warn "Request with a malformed session cookie: %p" % [ request ]
			return nil
		end
	end


	### Fetch the session ID from the given +request+, or create a new one if the
	### request doesn't have the necessary attributes.
	def self::get_session_id( request=nil )
		id = self.get_existing_session_id( request ) if request
		return id || SecureRandom.hex
	end


	### Return +true+ if the given +request+ has a session token which corresponds
	### to an existing session key.
	def self::has_session_for?( request )
		self.log.debug "Checking request (%s/%d) for session." % [ request.sender_id, request.conn_id ]
		id = self.get_existing_session_id( request ) or return false
		self.log.debug "  got a session ID: %p" % [ id ]
		return @sessions.key?( id )
	end


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Create a new session store using the given +hash+ for initial values.
	def initialize( session_id=nil, initial_values={} )
		@hash       = Hash.new {|h,k| h[k] = {} }
		@hash.merge!( initial_values )

		@namespace  = nil

		super
	end


	### Make sure the inner Hash is unique on duplications.
	def initialize_dup( * ) # :nodoc:
		@hash = deep_copy( @hash )
	end


	### Make sure the inner Hash is unique on clones.
	def initialize_clone( * ) # :nodoc:
		@hash = deep_copy( @hash )
	end


	######
	public
	######

	# The namespace that determines which subhash of the session is exposed
	# to the application.
	attr_reader :namespace

	# Delegate Hash methods to whichever Hash is the current namespace
	def_method_delegators :namespaced_hash, :[], :[]=, :delete, :key?


	### Set the current namespace for session values to +namespace+. Setting
	### +namespace+ to +nil+ exposes the toplevel namespace (keys are named
	### namespaces)
	def namespace=( namespace )
		@namespace = namespace.nil? ? nil : namespace.to_sym
	end


	### Save the session to storage and add the session cookie to the given +response+.
	def save( response )
		self.log.debug "Saving session %s" % [ self.session_id ]
		self.class.save_session_data( self.session_id, @hash )
		self.log.debug "Adding session cookie to the request."

		session_cookie = Strelka::Cookie.new(
			self.class.cookie_options[ :name ],
			self.session_id,
			self.class.cookie_options
		)

		response.cookies << session_cookie
	end


	### Return the Hash that corresponds with the current namespace's storage. If no
	### namespace is currently set, returns the entire session store as a Hash of Hashes
	### keyed by namespaces as Symbols.
	def namespaced_hash
		if @namespace
			self.log.debug "Returning namespaced hash: %p" % [ @namespace ]
			return @hash[ @namespace ]
		else
			self.log.debug "Returning toplevel namespace"
			return @hash
		end
	end


	#########
	protected
	#########

	### Proxy method: handle getting/setting headers via methods instead of the
	### index operator.
	def method_missing( sym, *args )
		# work magic
		return super unless sym.to_s =~ /^([a-z]\w+)(=)?$/

		# If it's an assignment, the (=)? will have matched
		key, assignment = $1, $2

		method_body = nil
		if assignment
			method_body = self.make_setter( key )
		else
			method_body = self.make_getter( key )
		end

		self.class.send( :define_method, sym, &method_body )
		return self.method( sym ).call( *args )
	end


	### Create a Proc that will act as a setter for the given key
	def make_setter( key )
		return Proc.new {|new_value| self.namespaced_hash[ key.to_sym ] = new_value }
	end


	### Create a Proc that will act as a getter for the given key
	def make_getter( key )
		return Proc.new { self.namespaced_hash[key.to_sym] }
	end

end # class Strelka::Session::Default
