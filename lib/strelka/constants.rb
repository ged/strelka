# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# frozen-string-literal: true

require 'uri'
require 'mongrel2/constants'
require 'strelka' unless defined?( Strelka )


# A collection of constants that are shared across the library
module Strelka::Constants

	# Import Mongrel2's constants, too
	include Mongrel2::Constants

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


	# Constants for parsing Cookie headers, mostly taken from
	# RFC6265 - HTTP State Management Mechanism
	#
	#    http://tools.ietf.org/html/rfc6265
	#
	module CookieHeader

		# Literals
		CRLF     = "\r\n"
		WSP      = '[\\x20\\t]'

		# OWS            = *( [ obs-fold ] WSP )
		#                     ; "optional" whitespace
		# obs-fold       = CRLF
		OBS_FOLD = CRLF
		OWS      = /(#{OBS_FOLD}#{WSP})*/

		# CTL            = <any US-ASCII control character
		#                   (octets 0 - 31) and DEL (127)>
		CTL = '[:cntrl:]'

		# separators     = "(" | ")" | "<" | ">" | "@"
		#               | "," | ";" | ":" | "\" | <">
		#               | "/" | "[" | "]" | "?" | "="
		#               | "{" | "}" | SP | HT
		SEPARATORS = '\\x28\\x29\\x3c\\x3e\\x40' +
		             '\\x2c\\x3b\\x3a\\x5c\\x22' +
		             '\\x2f\\x5b\\x5d\\x3f\\x3d' +
		             '\\x7b\\x7d\x20\x09'

		# Double-quote
		DQUOTE = '"'

		# token          = 1*<any CHAR except CTLs or separators>
		TOKEN = %r{ [^#{CTL}#{SEPARATORS}]+ }x

		# cookie-name       = token
		COOKIE_NAME = /(?<cookie_name>#{TOKEN})/

		# cookie-octet      = %x21 / %x23-2B / %x2D-3A / %x3C-5B / %x5D-7E
		#                    ; US-ASCII characters excluding CTLs,
		#                    ; whitespace DQUOTE, comma, semicolon,
		#                    ; and backslash
		COOKIE_OCTET = '[\x21\x23-\x2b\x2d-\x3a\x3c-\x5b\x5d-\x7e]'

		# cookie-value      = *cookie-octet / ( DQUOTE *cookie-octet DQUOTE )
		COOKIE_VALUE = %r{(?<cookie_value>
			#{COOKIE_OCTET}*
			|
			#{DQUOTE} #{COOKIE_OCTET}*? #{DQUOTE}
		)}x

		# cookie-pair       = cookie-name "=" cookie-value
		COOKIE_PAIR = %r{(?<cookie_pair>
			#{COOKIE_NAME}
			=
			#{COOKIE_VALUE}
		)}x

		# Version option (not part of RFC6265)
		COOKIE_VERSION = /;\s*Version=(?<version>\d+)/i

	end # module Cookie

end # module Strelka::Constants

