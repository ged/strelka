# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
#encoding: utf-8

require 'strelka'

class SessionsDemo < Strelka::App

	# The Mongrel2 appid of this app
	ID = 'sessions-demo'

	plugins :sessions

	### Set up the run counter
	def initialize( * )
		@runcount = 0
		super
	end


	### Handle any HTTP request
	def handle_request( req )
		res = req.response
		res.content_type = 'text/plain'
		res.status = HTTP::OK

		@runcount += 1
		req.session.counter ||= 0
		req.session.counter += 1

		self.log.debug "Request session is: %p" % [ req.session ]
		res.puts "Session [%s]: session counter: %d, run counter: %d" %
			[ req.session.session_id, req.session.counter, @runcount ]

		return res
	end


end # class SessionsDemo


Strelka.load_config( 'examples/config.yml' )
SessionsDemo.run