module OverSIP::WebSocket

  class IPv4TlsServer < TlsServer

    @ip_type = :ipv4
    @transport = :tls

    LOG_ID = "WS TLS IPv4 server"
    def log_id
      LOG_ID
    end

  end

end