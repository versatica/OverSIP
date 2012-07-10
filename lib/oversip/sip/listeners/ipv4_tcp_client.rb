module OverSIP::SIP

  class IPv4TcpClient < TcpClient

    @ip_type = :ipv4
    @transport = :tcp
    @server_class = ::OverSIP::SIP::IPv4TcpServer
    @connections = @server_class.connections
    @invite_server_transactions = @server_class.invite_server_transactions
    @non_invite_server_transactions = @server_class.non_invite_server_transactions
    @invite_client_transactions = @server_class.invite_client_transactions
    @non_invite_client_transactions = @server_class.non_invite_client_transactions

    LOG_ID = "SIP TCP IPv4 client"
    def log_id
      LOG_ID
    end

  end

end