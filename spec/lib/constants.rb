#!/usr/bin/env ruby

require 'strelka' unless defined?( Strelka )


### A collection of constants used in testing
module Strelka::TestConstants # :nodoc:all

	include Strelka::Constants

	unless defined?( TEST_HOST )

		TEST_HOST = 'localhost'

		# App id for testing
		TEST_APPID = 'BD17D85C-4730-4BF2-999D-9D2B2E0FCCF9'

		# 0mq socket specifications for Handlers
		TEST_SEND_SPEC = 'tcp://127.0.0.1:9998'
		TEST_RECV_SPEC = 'tcp://127.0.0.1:9997'


		# Freeze all testing constants
		constants.each do |cname|
			const_get(cname).freeze
		end
	end

end


