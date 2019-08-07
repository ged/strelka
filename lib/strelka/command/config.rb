# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# frozen-string-literal: true

require 'strelka/cli' unless defined?( Strelka::CLI )


# Command to start a Strelka application
module Strelka::CLI::Config
	extend Strelka::CLI::Subcommand

	desc 'Generate a config file (to STDOUT) for the specified GEM (or local apps)'
	arg :GEM, :optional
	command :config do |cmd|

		cmd.action do |globals, options, args|
			require 'strelka/discovery'

			apps = Array( args )
			discovered_apps = Strelka::Discovery.discovered_apps
			raise ArgumentError, "No apps discovered" if discovered_apps.empty?

			apps.each do |app_name|
				app_path = discovered_apps[ app_name ] or
					raise "No such app: %s" % [ app_name ]

				app_path = Pathname( app_path )
				prompt.say "  loading %s (%s)" % [ app_path, app_path.basename('.rb') ]
				Strelka::Discovery.load( app_path )
			end

			prompt.say "  generating config:"
			yaml = Configurability.default_config.dump
			yaml.gsub!( /(?<!^---)\n(\w)/m, "\n\n\\1" )
			$stdout.puts( yaml )
		end
	end

end # module Strelka::CLI::Config

