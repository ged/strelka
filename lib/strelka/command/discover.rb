# -*- ruby -*-
#encoding: utf-8

require 'strelka/cli' unless defined?( Strelka::CLI )


# Command to show discovered Strelka apps
module Strelka::CLI::Discover
	extend Strelka::CLI::Subcommand

	desc 'Show installed Strelka apps'
	command :discover do |cmd|

		cmd.action do |globals, options, args|
			prompt.say( headline_string "Searching for Strelka applications..." )

			apps = Strelka::Discovery.discovered_apps

			if apps.empty?
				prompt.say "None found."
			else
				rows = apps.sort_by {|name, path| name }
				display_table( rows )
			end
		end
	end

end # module Strelka::CLI::Discover

