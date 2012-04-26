# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require 'logger'

require 'strelka' unless defined?( Strelka )
require 'strelka/constants'


module Strelka

	# Add logging to a Strelka class. Including classes get #log and
	# #log_debug methods.
	#
	#   class MyClass
	#       include Inversion::Loggable
	#
	#       def a_method
	#           self.log.debug "Doing a_method stuff..."
	#       end
	#   end
	#
	module Loggable

		# A logging proxy class that wraps calls to the logger into calls that include
		# the name of the calling class.
		class ClassNameProxy

			### Create a new proxy for the given +klass+.
			def initialize( klass, force_debug=false )
				@classname   = klass.name
				@force_debug = force_debug
			end

			### Delegate debug messages to the global logger with the appropriate class name.
			def debug( msg=nil, &block )
				Strelka.logger.add( Logger::DEBUG, msg, @classname, &block )
			end

			### Delegate info messages to the global logger with the appropriate class name.
			def info( msg=nil, &block )
				return self.debug( msg, &block ) if @force_debug
				Strelka.logger.add( Logger::INFO, msg, @classname, &block )
			end

			### Delegate warn messages to the global logger with the appropriate class name.
			def warn( msg=nil, &block )
				return self.debug( msg, &block ) if @force_debug
				Strelka.logger.add( Logger::WARN, msg, @classname, &block )
			end

			### Delegate error messages to the global logger with the appropriate class name.
			def error( msg=nil, &block )
				return self.debug( msg, &block ) if @force_debug
				Strelka.logger.add( Logger::ERROR, msg, @classname, &block )
			end

			### Delegate fatal messages to the global logger with the appropriate class name.
			def fatal( msg=nil, &block )
				Strelka.logger.add( Logger::FATAL, msg, @classname, &block )
			end

		end # ClassNameProxy

		#########
		protected
		#########

		### Copy constructor -- clear the original's log proxy.
		def initialize_copy( original )
			@log_proxy = @log_debug_proxy = nil
			super
		end

		### Return the proxied logger.
		def log
			@log_proxy ||= ClassNameProxy.new( self.class )
		end

		### Return a proxied "debug" logger that ignores other level specification.
		def log_debug
			@log_debug_proxy ||= ClassNameProxy.new( self.class, true )
		end

	end # module Loggable


	# Hides your class's ::new method and adds a +pure_virtual+ method generator for
	# defining API methods. If subclasses of your class don't provide implementations of
	# "pure_virtual" methods, NotImplementedErrors will be raised if they are called.
	#
	#   # AbstractClass
	#   class MyBaseClass
	#       include Strelka::AbstractClass
	#
	#       # Define a method that will raise a NotImplementedError if called
	#       pure_virtual :api_method
	#   end
	#
	module AbstractClass

		### Methods to be added to including classes
		module ClassMethods

			### Define one or more "virtual" methods which will raise
			### NotImplementedErrors when called via a concrete subclass.
			def pure_virtual( *syms )
				syms.each do |sym|
					define_method( sym ) do |*args|
						raise ::NotImplementedError,
							"%p does not provide an implementation of #%s" % [ self.class, sym ],
							caller(1)
					end
				end
			end


			### Turn subclasses' new methods back to public.
			def inherited( subclass )
				subclass.module_eval { public_class_method :new }
				super
			end

		end # module ClassMethods


		### Inclusion callback
		def self::included( mod )
			super
			if mod.respond_to?( :new )
				mod.extend( ClassMethods )
				mod.module_eval { private_class_method :new }
			end
		end


	end # module AbstractClass


	# A collection of various delegation code-generators that can be used to define
	# delegation through other methods, to instance variables, etc.
	module Delegation

		###############
		module_function
		###############

		### Define the given +delegated_methods+ as delegators to the like-named method
		### of the return value of the +delegate_method+.
		###
		###    class MyClass
		###      extend Strelka::Delegation
		###
		###      # Delegate the #bound?, #err, and #result2error methods to the connection
		###      # object returned by the #connection method. This allows the connection
		###      # to still be loaded on demand/overridden/etc.
		###      def_method_delegators :connection, :bound?, :err, :result2error
		###
		###      def connection
		###        @connection ||= self.connect
		###      end
		###    end
		###
		def def_method_delegators( delegate_method, *delegated_methods )
			delegated_methods.each do |name|
				body = make_method_delegator( delegate_method, name )
				define_method( name, &body )
			end
		end


		### Define the given +delegated_methods+ as delegators to the like-named method
		### of the specified +ivar+. This is pretty much identical with how 'Forwardable'
		### from the stdlib does delegation, but it's reimplemented here for consistency.
		###
		###    class MyClass
		###      extend Strelka::Delegation
		###
		###      # Delegate the #each method to the @collection ivar
		###      def_ivar_delegators :@collection, :each
		###
		###    end
		###
		def def_ivar_delegators( ivar, *delegated_methods )
			delegated_methods.each do |name|
				body = make_ivar_delegator( ivar, name )
				define_method( name, &body )
			end
		end


		### Define the given +delegated_methods+ as delegators to the like-named class
		### method.
		def def_class_delegators( *delegated_methods )
			delegated_methods.each do |name|
				define_method( name ) do |*args|
					self.class.__send__( name, *args )
				end
			end
		end


		#######
		private
		#######

		### Make the body of a delegator method that will delegate to the +name+ method
		### of the object returned by the +delegate+ method.
		def make_method_delegator( delegate, name )
			error_frame = caller(5)[0]
			file, line = error_frame.split( ':', 2 )

			# Ruby can't parse obj.method=(*args), so we have to special-case setters...
			if name.to_s =~ /(\w+)=$/
				name = $1
				code = <<-END_CODE
				lambda {|*args| self.#{delegate}.#{name} = *args }
				END_CODE
			else
				code = <<-END_CODE
				lambda {|*args,&block| self.#{delegate}.#{name}(*args,&block) }
				END_CODE
			end

			return eval( code, nil, file, line.to_i )
		end


		### Make the body of a delegator method that will delegate calls to the +name+
		### method to the given +ivar+.
		def make_ivar_delegator( ivar, name )
			error_frame = caller(5)[0]
			file, line = error_frame.split( ':', 2 )

			# Ruby can't parse obj.method=(*args), so we have to special-case setters...
			if name.to_s =~ /(\w+)=$/
				name = $1
				code = <<-END_CODE
				lambda {|*args| #{ivar}.#{name} = *args }
				END_CODE
			else
				code = <<-END_CODE
				lambda {|*args,&block| #{ivar}.#{name}(*args,&block) }
				END_CODE
			end

			return eval( code, nil, file, line.to_i )
		end

	end # module Delegation


	# A collection of miscellaneous functions that are useful for manipulating
	# complex data structures.
	#
	#   include Strelka::DataUtilities
	#   newhash = deep_copy( oldhash )
	#
	module DataUtilities

		###############
		module_function
		###############

		### Recursively copy the specified +obj+ and return the result.
		def deep_copy( obj )

			# Handle mocks during testing
			return obj if obj.class.name == 'RSpec::Mocks::Mock'

			return case obj
				when NilClass, Numeric, TrueClass, FalseClass, Symbol
					obj

				when Array
					obj.map {|o| deep_copy(o) }

				when Hash
					newhash = {}
					newhash.default_proc = obj.default_proc if obj.default_proc
					obj.each do |k,v|
						newhash[ deep_copy(k) ] = deep_copy( v )
					end
					newhash

				else
					obj.clone
				end
		end


		### Create and return a Hash that will auto-vivify any values it is missing with
		### another auto-vivifying Hash.
		def autovivify( hash, key )
			hash[ key ] = Hash.new( &Strelka::DataUtilities.method(:autovivify) )
		end

	end # module DataUtilities


	# A collection of methods for declaring other methods.
	#
	#   class MyClass
	#       include Strelka::MethodUtilities
	#
	#       singleton_attr_accessor :types
	#       singleton_method_alias :kinds, :types
	#   end
	#
	#   MyClass.types = [ :pheno, :proto, :stereo ]
	#   MyClass.kinds # => [:pheno, :proto, :stereo]
	#
	module MethodUtilities

		### Creates instance variables and corresponding methods that return their
		### values for each of the specified +symbols+ in the singleton of the
		### declaring object (e.g., class instance variables and methods if declared
		### in a Class).
		def singleton_attr_reader( *symbols )
			symbols.each do |sym|
				singleton_class.__send__( :attr_reader, sym )
			end
		end

		### Creates methods that allow assignment to the attributes of the singleton
		### of the declaring object that correspond to the specified +symbols+.
		def singleton_attr_writer( *symbols )
			symbols.each do |sym|
				singleton_class.__send__( :attr_writer, sym )
			end
		end

		### Creates readers and writers that allow assignment to the attributes of
		### the singleton of the declaring object that correspond to the specified
		### +symbols+.
		def singleton_attr_accessor( *symbols )
			symbols.each do |sym|
				singleton_class.__send__( :attr_accessor, sym )
			end
		end

		### Creates an alias for the +original+ method named +newname+.
		def singleton_method_alias( newname, original )
			singleton_class.__send__( :alias_method, newname, original )
		end


	end # module MethodUtilities


	# A collection of functions for generating responses.
	module ResponseHelpers

		### Abort the current execution and return a response with the specified
		### http_status code immediately. The specified +message+ will be logged,
		### and will be included in any message that is returned as part of the
		### response. The +headers+ hash will be used to set response headers.
		### As a shortcut, you can call #finish_with again with the Hash that it
		### builds to re-throw it.
		def finish_with( http_status, message=nil, headers={} )
			status_info = nil

			if http_status.is_a?( Hash ) && http_status.key?(:status)
				self.log.debug "Re-finishing with a status_info struct: %p." % [ http_status ]
				status_info = http_status
			else
				message ||= HTTP::STATUS_NAME[ http_status ]
				status_info = {
					status:    http_status,
					message:   message,
					headers:   headers,
					backtrace: caller(1),
				}
			end

			throw :finish, status_info
		end

	end # module ResponseHelpers

end # module Strelka

# vim: set nosta noet ts=4 sw=4:

