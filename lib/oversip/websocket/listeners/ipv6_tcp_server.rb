module OverSIP::WebSocket

  class IPv6TcpServer < TcpServer

    @ip_type = :ipv6
    @transport = :tcp

    LOG_ID = "WS TCP IPv6 server"
    def log_id
      LOG_ID
    end

  end

end