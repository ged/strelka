#!/usr/bin/env ruby

# This experiment is to test the following things:
#
# * can add methods to a module *after* it's already mixed into a class?
# * can you declared the added methods from a block defined in the including class?
# * can you subvert a Module's included hook to cause the including module to
#   instead get the features of an anonymous clone of itself instead? This would
#   be necessary so that the added methods would be unique per including class.
#

module Reflector

	def self::add_api_method( sym )
		$stderr.puts "Adding reflective API method %p" % [ sym ]
		define_method( sym ) do |*args, &block|
			block.call( *args ) if block
			return *args
		end
	end


	def self::included( klass )
		# Append features from an anonymous duplicate of the module instead
		# of Reflector itself.
		reflector = self.dup
		$stderr.puts "Appending features of %p to %p" % [ reflector, klass ]
		reflector.send( :append_features, klass )
		$stderr.puts "Adding declaratives."
		klass.extend( Declaratives )
		klass.reflector = reflector

		# (no super)
	end


	# Methods for declaring the API in the Reflector.
	module Declaratives

		def self::extended( obj )
			super
			obj.in_definition_block = false
		end


		attr_accessor :in_definition_block, :reflector

		def api_methods( *symbols )
			$stderr.puts "Declaring API methods."
			symbols.each do |methodname|
				self.reflector.add_api_method( methodname )
			end
		end

	end


end # module Reflector


class A
	include Reflector

	api_methods :foo, :bar

end

$stderr.puts "Ancestors:"
A.ancestors.each do |mod|
	$stderr.puts "-- %p" % [ mod ], *mod.instance_methods( false )
	$stderr.puts
end

A.new.foo { puts "Yep." }
p A.new.bar( 1, :eight, 'nein' )


