#!/usr/bin/env ruby

require 'daemons'

require 'strelka' unless defined?( Strelka )

# An application manager class for managing mongrel2 instances and
# applications that connect to them.
class Strelka::Runner

	### Create a new Strelka::Runner.
	def initialize
		@apps = {}
	end


	######
	public
	######

	# The Hash of Daemon::Application objects, keyed by the appid of the apps they are
	# running.
	attr_reader :apps


	### Run an instance of the  Strelka app at +app_path+, optionally overriding its 
	### default application ID with +appid+.
	###
	### Raises a RuntimeError if an app is already running with the specified +appid+
	### or 
	def run( app_path, appid=nil )
		
	end

end # class Strelka::Runner


