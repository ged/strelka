# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# frozen-string-literal: true

require 'strelka/cli' unless defined?( Strelka::CLI )
require 'strelka/multirunner'


# Command to start a Strelka application
module Strelka::CLI::Start
	extend Strelka::CLI::Subcommand

	desc 'Start a Strelka app'
	arg :GEMNAME, :optional
	arg :APPNAME

	command :start do |cmd|

		cmd.switch [:I, :isolate],
			desc: "Run in a sandboxed environment",
			long_desc: %{Run the app inside a sandbox using the Isolate gem. This is not
				installed by default, so you'll need to ensure it's installed before
				using this option.
			},
			negatable: false
		cmd.flag [ :n, :number ],
			desc: 'Spin up this many handlers via fork()',
			default_value: 1,
			type: Integer

		cmd.action do |global, options, args|
			appname = args.pop
			gemname = args.pop

			if options.isolate
				require 'isolate/now'
			end

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
				if options.number == 1
					app.run
				else
					Strelka::MultiRunner.new( app, options.number ).run
				end
			end
		end
	end

end # module Strelka::CLI::Start

