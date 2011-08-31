#!/usr/bin/env ruby

require 'mongrel2'
require 'inversion'
require 'configurability'

# An application framework for Ruby-mongrel2
# 
# == Author/s
#
# * Michael Granger <ged@FaerieMUD.org>
# 
module Strelka

	# Library version constant
	VERSION = '0.0.1'

	# Version-control revision constant
	REVISION = %q$Revision$


	require 'strelka/logging'
	extend Strelka::Logging

	require 'strelka/constants'
	include Strelka::Constants


	### Get the library version. If +include_buildnum+ is true, the version string will
	### include the VCS rev ID.
	def self::version_string( include_buildnum=false )
		vstring = "%s %s" % [ self.name, VERSION ]
		vstring << " (build %s)" % [ REVISION[/: ([[:xdigit:]]+)/, 1] || '0' ] if include_buildnum
		return vstring
	end

end # module Strelka

