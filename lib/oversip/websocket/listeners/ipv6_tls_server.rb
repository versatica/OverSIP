module OverSIP::WebSocket

  class IPv6TlsServer < TlsServer

    @ip_type = :ipv6
    @transport = :tls

    LOG_ID = "WS TLS IPv6 server"
    def log_id
      LOG_ID
    end

  end

end