module OverSIP::SIP

  class IPv4TlsClient < TlsClient

    @ip_type = :ipv4
    @transport = :tls
    @server_class = ::OverSIP::SIP::IPv4TlsServer
    @connections = @server_class.connections
    @invite_server_transactions = @server_class.invite_server_transactions
    @non_invite_server_transactions = @server_class.non_invite_server_transactions
    @invite_client_transactions = @server_class.invite_client_transactions
    @non_invite_client_transactions = @server_class.non_invite_client_transactions

    LOG_ID = "SIP TLS IPv4 client"
    def log_id
      LOG_ID
    end

  end

end