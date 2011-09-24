#!/usr/bin/env ruby

require 'mongrel2/config'
include Mongrel2::Config::DSL

require 'strelka/constants'
include Strelka::Constants

# This is the config that's loaded by 'leash setup' to get the admin server
# up and running.

server 'admin' do
    name 'adminserver'
	port DEFAULT_ADMIN_PORT
	access_log '/logs/admin-access.log'
	error_log '/logs/admin-error.log'
	pid_file '/run/admin.pid'

	default_host 'localhost'

    host 'localhost' do
        route '/', handler( 'tcp://127.0.0.1:19999', 'admin-console' )

		route '/css',    directory( 'data/strelka/static/css/', 'base.css', 'text/css' )
		route '/images', directory( 'data/strelka/static/images/' )
		route '/fonts',  directory( 'data/strelka/static/fonts/' )
		route '/js',     directory( 'data/strelka/static/js/', 'index.js', 'text/javascript' )
    end
end

setting "control_port", 'ipc://run/admin-control'

mkdir_p 'logs'
mkdir_p 'run'
