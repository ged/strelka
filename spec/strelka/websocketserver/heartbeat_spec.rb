#!/usr/bin/env rspec -cfd

require_relative '../../helpers'

require 'strelka'
require 'strelka/plugins'
require 'strelka/websocketserver/heartbeat'

require 'strelka/behavior/plugin'


describe Strelka::WebSocketServer::Heartbeat do

	it_should_behave_like( "A Strelka Plugin" )

end

