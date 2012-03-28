# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
#encoding: utf-8

require 'strelka'

class AuthDemo < Strelka::App

	# The Mongrel2 appid of this app
	ID = 'auth-demo'

	plugins :auth
	auth_provider :passphrase

	### Handle any (authenticated) HTTP request
	def handle_request( req )
		res = req.response
		res.content_type = 'text/plain'
		res.status = HTTP::OK

		self.log.debug "Authenticated user is: %p" % [ req.user ]
		res.puts "You authenticated successfully."

		return res
	end


end # class AuthDemo


Strelka.load_config( 'examples/config.yml' )
AuthDemo.run
