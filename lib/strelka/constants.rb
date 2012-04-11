#!/usr/bin/ruby
#encoding: utf-8

require 'mongrel2/constants'
require 'strelka' unless defined?( Strelka )


# A collection of constants that are shared across the library
module Strelka::Constants

	# Import Mongrel2's constants, too
	include Mongrel2::Constants

	# The data directory in the project if that exists, otherwise the gem datadir
	DATADIR = if ENV['STRELKA_DATADIR']
			Pathname( ENV['STRELKA_DATADIR'] )
		elsif File.directory?( 'data/strelka' )
			Pathname( 'data/strelka' )
		elsif path = Gem.datadir('strelka')
			Pathname( path )
		else
			raise ScriptError, "can't find the data directory!"
		end

	# Extend Mongrel2's HTTP constants collection
	module HTTP
		include Mongrel2::Constants::HTTP

		# The list of valid verbs for regular HTTP
		RFC2616_VERBS = %w[OPTIONS GET HEAD POST PUT DELETE TRACE CONNECT]

		# A regex for matching RFC2616 verbs
		RFC2616_VERB_REGEX = Regexp.union( RFC2616_VERBS )

		# The list of HTTP verbs considered "safe"
		SAFE_RFC2616_VERBS = %w[GET HEAD]

		# The list of HTTP verbs considered "idempotent"
		IDEMPOTENT_RFC2616_VERBS = %w[OPTIONS GET HEAD PUT DELETE TRACE]

	end # module HTTP

end # module Strelka::Constants

