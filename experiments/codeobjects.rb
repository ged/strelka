#!/usr/bin/env ruby

require 'pp'
require 'ripper'


class CodeObjectParser < Ripper::SexpBuilderPP

	def initialize( * )
		@yydebug = true
		super
	end

	# def on_comment( *content )
	# 	[ :comment, content ]
	# end

end

src = ARGF.each.to_a.join
pp CodeObjectParser.new( src ).parse

