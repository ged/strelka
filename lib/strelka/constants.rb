#!/usr/bin/ruby
#encoding: utf-8

require 'mongrel2/constants'
require 'strelka' unless defined?( Strelka )


# A collection of constants that are shared across the library
module Strelka::Constants

	# Import Mongrel2's constants, too
	include Mongrel2::Constants

	# Override the path to the default Sqlite configuration database
	# remove_const( :DEFAULT_CONFIG_URI )
	DEFAULT_CONFIG_URI = 'strelka.sqlite'

	# The admin server port
	DEFAULT_ADMIN_PORT = 7337


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

		# A registry of HTTP status codes that don't allow an entity body 
		# in the response.
		BODILESS_HTTP_RESPONSE_CODES = [
			CONTINUE,
			SWITCHING_PROTOCOLS,
			PROCESSING,
			NO_CONTENT,
			RESET_CONTENT,
			NOT_MODIFIED,
			USE_PROXY,
		]

	end # module HTTP

end # module Strelka::Constants

