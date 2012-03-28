# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
#encoding: utf-8

require 'strelka'

class AuthDemo < Strelka::App

	# The Mongrel2 appid of this app
	ID = 'auth-demo'

	plugins :routing, :auth
	auth_provider :basic

	### Handle any (authenticated) HTTP request
	get do |req|
		res = req.response
		res.content_type = 'text/plain'
		res.status = HTTP::OK

		self.log.debug "Authenticated user is: %p" % [ req.authenticated_user ]
		res.puts "You authenticated successfully (as %p)." % [ req.authenticated_user ]

		return res
	end


end # class AuthDemo


Strelka.load_config( 'examples/config.yml' )
AuthDemo.run
