# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# frozen-string-literal: true

require_relative '../../helpers'

require 'strelka'
require 'strelka/plugins'
require 'strelka/websocketserver/heartbeat'

require 'strelka/behavior/plugin'


RSpec.describe Strelka::WebSocketServer::Heartbeat do

	it_should_behave_like( "A Strelka Plugin" )

end

