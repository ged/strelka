# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require 'strelka' unless defined?( Strelka )


### A collection of constants used in testing
module Strelka::TestConstants # :nodoc:all

	include Strelka::Constants,
	        Mongrel2::WebSocket::Constants

	unless defined?( TEST_HOST )

		TEST_HOST = 'localhost'

		# App id for testing
		TEST_APPID = 'BD17D85C-4730-4BF2-999D-9D2B2E0FCCF9'

		# 0mq socket specifications for Handlers
		TEST_SEND_SPEC = 'tcp://127.0.0.1:9998'
		TEST_RECV_SPEC = 'tcp://127.0.0.1:9997'


		# Freeze all testing constants
		constants.each do |cname|
			const_get(cname).freeze if cname.to_s.start_with?( 'TEST_' )
		end
	end

end


