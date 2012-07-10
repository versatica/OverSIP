module OverSIP::WebSocket

  class IPv4TlsTunnelServer < TlsTunnelServer

    @ip_type = :ipv4
    @transport = :tls

    LOG_ID = "WS TLS-Tunnel IPv4 server"
    def log_id
      LOG_ID
    end

  end

end