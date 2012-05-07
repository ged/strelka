# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:

require 'ipaddr'
require 'loggability'
require 'configurability'

require 'strelka' unless defined?( Strelka )
require 'strelka/app' unless defined?( Strelka::App )
require 'strelka/authprovider'
require 'strelka/mixins'

# HostAccess AuthProvider class -- restricts access to requests coming from a list of
# netblocks.
#
# You can configure which ones from the +auth+ section of the config:
#
#   auth:
#     allowed_netblocks:
#     - 127.0.0.0/8
#     - 10.5.3.0/22
class Strelka::AuthProvider::HostAccess < Strelka::AuthProvider
	extend Loggability
	include Configurability,
	        Strelka::Constants,
	        Strelka::MethodUtilities


	# Loggability API -- set up logging under the 'strelka' log host
	log_to :strelka


	# The default list of netblocks to allow
	DEFAULT_ALLOWED_NETBLOCKS = %w[127.0.0.0/8]


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Create a new Default AuthProvider.
	def initialize( * )
		super

		self.allowed_netblocks = DEFAULT_ALLOWED_NETBLOCKS

		# Register this instance with Configurability
		config_key :auth
	end


	######
	public
	######

	# An Array of IPAddr objects that represent the netblocks that will be allowed
	# access to the protected resources
	attr_reader :allowed_netblocks


	### Set the list of allowed netblocks to +newblocks+.
	def allowed_netblocks=( newblocks )
		@allowed_netblocks = Array( newblocks ).map {|addr| IPAddr.new(addr) }
	end


	### Configurability API -- configure the auth provider instance.
	def configure( config=nil )
		self.log.debug "Configuring %p with config: %p" % [ self, config ]
		if config && config['allowed_netblocks']
			self.allowed_netblocks = config['allowed_netblocks']
		else
			self.allowed_netblocks = DEFAULT_ALLOWED_NETBLOCKS
		end
	end


	### Check authorization for the specified +request+ by testing its the IP in its
	### X-forwarded-for header against the allowed_netblocks.
	def authorize( _, request )
		client_ip = request.header.x_forwarded_for or
			raise "No X-Forwarded-For header?!"
		addr = IPAddr.new( client_ip )

		return true if self.in_allowed_netblocks?( addr )

		return false
	end


	### Returns +true+ if the given +ipaddr+ is in the #allowed_netblocks.
	def in_allowed_netblocks?( ipaddr )
		return self.allowed_netblocks.any? {|nb| nb.include?(ipaddr) }
	end

end # class Strelka::AuthProvider::HostAccess
