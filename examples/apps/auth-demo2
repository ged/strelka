# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
#encoding: utf-8

require 'strelka'

# Another demo of the :auth plugin, this time implemented as form-based session
# auth.

class AuthDemo2 < Strelka::App

	# The Mongrel2 appid of this app
	ID = 'auth-demo2'

	plugins :auth, :errors, :templating
	auth_provider :session

	layout 'examples/layout.tmpl'
	templates \
		form: 'examples/auth-form.tmpl',
		success: 'examples/auth-success.tmpl'

	on_status AUTH_REQUIRED, :form


	### Handle any (authenticated) HTTP request
	def handle_request( req )
		return :success
	end


end # class AuthDemo2


Strelka.load_config( 'examples/config.yml' )
AuthDemo2.run

