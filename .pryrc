#!/usr/bin/ruby -*- ruby -*-

require 'loggability'
require 'pathname'

$LOAD_PATH.unshift( 'lib' )

begin
	require 'strelka'

	Loggability.level = :debug
	Loggability.format_with( :color )

rescue Exception => e
	$stderr.puts "Ack! Strelka libraries failed to load: #{e.message}\n\t" +
		e.backtrace.join( "\n\t" )
end


