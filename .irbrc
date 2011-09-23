#!/usr/bin/env ruby
# vim: set nosta noet ts=4 sw=4:

BEGIN {
    require 'pathname'
	$LOAD_PATH.unshift( Pathname.new( __FILE__ ).dirname + 'lib' )
	$LOAD_PATH.unshift( Pathname.new( __FILE__ ).dirname.parent + 'Mongrel2/lib' )
}

begin
	require 'strelka'
rescue Exception => err
	$stderr.puts "Strelka failed to load: %p: %s" % [ err.class, err.message ]
	$stderr.puts( err.backtrace )
end

