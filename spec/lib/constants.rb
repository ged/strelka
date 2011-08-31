#!/usr/bin/env ruby

require 'strelka' unless defined?( Strelka )


### A collection of constants used in testing
module Strelka::TestConstants # :nodoc:all

	include Strelka::Constants

	unless defined?( TEST_HOST )

		TEST_HOST = 'localhost'



		# Freeze all testing constants
		constants.each do |cname|
			const_get(cname).freeze
		end
	end

end


