#!/usr/bin/env ruby

require 'mongrel2/handler'
require 'strelka' unless defined?( Strelka )


# The process-style handler base class.
class Strelka::Process < Mongrel2::Handler
	include Strelka::Loggable,
	        Strelka::Constants

	### Create a new Process.
	def initialize( * )
		@
	end


end # class Strelka::Process

