# -*- ruby -*-
#encoding: utf-8

require 'strelka/cli' unless defined?( Strelka::CLI )


# Command to start a Strelka application
module Strelka::CLI::Config
	extend Strelka::CLI::Subcommand

	desc 'Dump a config file for the specified GEM (or local apps)'
	arg :GEM, :optional
	command :config do |cmd|

		cmd.action do |globals, options, args|
			gemname = args.shift
			discovery_name = gemname || ''

			prompt.say( headline_string "Dumping config for %s" % [ gemname || 'local apps' ] )
			discovered_apps = Strelka::Discovery.discover_apps

			raise ArgumentError, "No apps discovered" unless discovered_apps.key?( discovery_name )

			discovered_apps[ discovery_name ].each do |apppath|
				prompt.say "  loading %s (%s)" % [ apppath, apppath.basename('.rb') ]
				Strelka::Discovery.load( apppath )
			end

			prompt.say "  dumping config:"
			$stdout.puts Configurability.default_config.dump
		end
	end

end # module Strelka::CLI::Config

