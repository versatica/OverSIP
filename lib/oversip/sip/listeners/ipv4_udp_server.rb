module OverSIP::SIP

  class IPv4UdpServer < UdpConnection

    @ip_type = :ipv4
    @transport = :udp
    @connections = nil  # To be set after creating the unique server instance.
    @invite_server_transactions = {}
    @non_invite_server_transactions = {}
    @invite_client_transactions = {}
    @non_invite_client_transactions = {}
    @is_outbound_listener = true

    LOG_ID = "SIP UDP IPv4 server"
    def log_id
      LOG_ID
    end

  end

end