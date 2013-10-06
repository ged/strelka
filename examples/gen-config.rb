# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
#encoding: utf-8

# The Mongrel config used by the examples. Load it with:
#
#   m2sh.rb -c examples/mongrel2.sqlite load examples/gen-config.rb
#

require 'mongrel2'
require 'mongrel2/config/dsl'


# samples server
server 'examples' do

	name         'Strelka Examples'
	default_host 'localhost'

	access_log   'logs/access.log'
	error_log    'logs/error.log'
	pid_file     'run/mongrel2.pid'

	chroot       ''
	bind_addr    '0.0.0.0'
	port         8113

	host 'localhost' do

		route '/', directory( 'static/', 'examples.html', 'text/html' )

		# Handlers
		route '/hello', handler( 'tcp://127.0.0.1:9900', 'hello-world' )
		route '/sessions', handler( 'tcp://127.0.0.1:9905', 'sessions-demo' )
		route '/auth', handler( 'tcp://127.0.0.1:9910', 'auth-demo' )
		route '/formauth', handler( 'tcp://127.0.0.1:9915', 'auth-demo2' )
		route '/upload', handler( 'tcp://127.0.0.1:9925', 'upload-demo' )
		route '/ws', handler( 'tcp://127.0.0.1:9920', 'ws-echo' )

	end

end

setting "zeromq.threads", 1

setting 'limits.content_length', 8096
setting 'upload.temp_store', 'var/uploads/mongrel2.upload.XXXXXX'
setting 'server.daemonize', false

mkdir_p 'var/uploads'
mkdir_p 'run'
mkdir_p 'logs'

