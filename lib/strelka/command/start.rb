# -*- ruby -*-
#encoding: utf-8

require 'strelka/cli' unless defined?( Strelka::CLI )


# Command to start a Strelka application
module Strelka::CLI::Start
	extend Strelka::CLI::Subcommand

	desc 'Start a Strelka app'
	arg :GEMNAME, :optional
	arg :APPNAME
	command :start do |cmd|

		cmd.action do |global, options, args|
			appname = args.pop
			gemname = args.pop

			gem( gemname ) if gemname

			app = if File.exist?( appname )
					Strelka::Discovery.load_file( appname ) or
						exit_now!( "Didn't find an app while loading %p!" % [appname] )
				else
					Strelka::Discovery.load( appname ) or
						exit_now!( "Couldn't find the %p app!" % [appname] )
				end

			Strelka::CLI.prompt.say "Starting %s (%p)." % [ appname, app ]
			Strelka.load_config( global.config ) if global.config
			unless_dryrun( "starting the app" ) do
				app.run
			end
		end
	end

end # module Strelka::CLI::Start

