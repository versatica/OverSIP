module OverSIP::SIP

  class IPv6TcpServer < TcpServer

    @ip_type = :ipv6
    @transport = :tcp
    @connections = {}
    @invite_server_transactions = {}
    @non_invite_server_transactions = {}
    @invite_client_transactions = {}
    @non_invite_client_transactions = {}
    @is_reliable_transport_listener = true
    @is_outbound_listener = true

    LOG_ID = "SIP TCP IPv6 server"
    def log_id
      LOG_ID
    end

  end

end