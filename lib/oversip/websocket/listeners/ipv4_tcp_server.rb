module OverSIP::WebSocket

  class IPv4TcpServer < TcpServer

    @ip_type = :ipv4
    @transport = :tcp

    LOG_ID = "WS TCP IPv4 server"
    def log_id
      LOG_ID
    end

  end

end