#!/usr/bin/env ruby

require 'pathname'

require 'mongrel2/config'
include Mongrel2::Config::DSL

require 'strelka'
require 'strelka/constants'
include Strelka::Constants

# Load the app classes to grab their appids. Only necessary for bootstrapping.
adminapp = Strelka::App.load( DATADIR + 'apps/strelka-admin' ).first
helloapp = Strelka::App.load( DATADIR + 'apps/hello-world' ).first

# This is the config that's loaded by 'leash setup' to get the admin server
# up and running.
server ADMINSERVER_ID do
    name 'Strelka Admin Server'
	port 8833
	chroot '.'
	access_log '/logs/admin-access.log'
	error_log '/logs/admin-error.log'
	pid_file '/run/admin.pid'
	bind_addr '127.0.0.1'

	default_host 'localhost'

    host 'localhost' do
        route '/', handler( 'tcp://127.0.0.1:19999', adminapp.default_appid )
        route '/hello', handler( 'tcp://127.0.0.1:19995', helloapp.default_appid )

		route '/css',    directory( 'static/css/', 'base.css', 'text/css' )
		route '/images', directory( 'static/images/' )
		route '/fonts',  directory( 'static/fonts/' )
		route '/js',     directory( 'static/js/', 'index.js', 'text/javascript' )
    end
end

setting "control_port", 'ipc://run/control'

mimetypes '.ttf' => 'application/x-font-truetype',
          '.otf' => 'application/x-font-opentype'

