# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:

require 'digest/sha1'
require 'pluginfactory'

require 'strelka' unless defined?( Strelka )
require 'strelka/mixins'

# Abstract base class for pluggable session strategies for the Sessions
# plugin.
#
# To define your own session type, you'll need to inherit this class (either
# directly or via a subclass), name it <tt>Strelka::Session::{Something}</tt>,
# save it in a file named <tt>strelka/session/{something}.rb</tt>, and
# override the required methods.
#
# The class methods you'll need to provide implementations for are:
#
# * self.configure
# * self.get_session_id
# * self.load_session_data
# * self.save_session_data
# * self.delete_session_data
#
# The instance methods fetch and set values in the session itself, and manipulate
# the namespace that's used to partition session data between applications:
#
# * #[]
# * #[]=
# * #save
# * #delete
# * #key?
# * #namespace=
# * #namespace
#
# These methods provide basic functionality, but you might find it more efficient
# to override them:
#
# * self.load_or_create
# * self.load
#
#
class Strelka::Session
	include PluginFactory,
	        Strelka::Loggable,
			Strelka::AbstractClass

	# The default name of the cookie that stores the session ID
	DEFAULT_COOKIE_NAME = 'strelka-sessionid'

	### PluginFactory API -- return the Array of directories to search for concrete
	### Session classes.
	def self::derivative_dirs
		return ['strelka/session']
	end


	### Configure the session class with the given +options+, which should be a
	### Hash or an object that has a Hash-like interface. This is a no-op by
	### default.
	def self::configure( options )
	end


	### Fetch the session ID from the given +request+, or create a new one if the
	### request is +nil+ or doesn't have the necessary attributes. You should
	### override this, as the default implementation just returns +nil+.
	def self::get_session_id( request=nil )
		return nil
	end


	### Load session data for the specified +session_id+.  This should return a data
	### structure that can #merge!, or +nil+ if there was no existing session data
	### associated with +session_id+.
	def self::load_session_data( session_id )
		return nil
	end


	### Save the session data for the specified +session_id+.
	def self::save_session_data( session_id, data )
	end


	### Delete the session data for the specified +session_id+.
	def self::delete_session_data( session_id )
	end


	### Load a session instance from storage using the given +session_id+ and return
	### it. Returns +nil+ if no session could be loaded. You can either overload
	### ::load_session_data if you are loading a data structure, or override ::load
	### if you're serializing the session object directly.
	def self::load( session_id )
		values = self.load_session_data( session_id ) or return nil
		return new( session_id, values )
	end


	### Return an instance of the session class that's associated with the specified
	### request, either loading one from the persistant store, or creating a new one
	### if it can't be loaded or +request+ is nil.
	def self::load_or_create( request=nil )
		session_id = self.get_session_id( request )
		return self.load( session_id ) || new( session_id )
	end


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Set up a new instance with the given +session_id+ and +initial_values+.
	def initialize( session_id, initial_values={} ) # :notnew:
		@session_id = session_id
	end


	######
	public
	######

	# The key of the session in the session store
	attr_reader :session_id


	# :call-seq:
	#   session[ key ]  -> object
	#
	# Index operator -- fetch the value associated with +key+ in the current namespace
	pure_virtual :[]


	# :call-seq:
	#   session[ key ] = object
	#
	# Index set operator -- set the value associated with +key+ in the current
	# namespace to +object+.
	pure_virtual :[]=


	# :call-seq:
	#   save( response )
	#
	# Save the session and set up the specified +response+ to persist the
	# session ID.
	pure_virtual :save


	# :call-seq:
	#   key?( key ) -> boolean
	#
	# Returns +true+ if the specified +key+ exists in the current namespace.
	pure_virtual :key?


	# :call-seq:
	#   namespace = new_namespace
	#
	# Set the namespace of the session that will be used for future access.
	pure_virtual :namespace=


	# :call-seq:
	#   namespace -> symbol
	#
	# Return the current namespace of the session.
	pure_virtual :namespace


	# :call-seq:
	#   delete( key ) -> object
	#
	# Remove the value associated with the specified +key+ from the current namespace
	# and return it, if it exists.
	pure_virtual :delete

end # class Strelka::Session
