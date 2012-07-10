module OverSIP::WebSocket

  class IPv6TlsTunnelServer < TlsTunnelServer

    @ip_type = :ipv6
    @transport = :tls

    LOG_ID = "WS TLS-Tunnel IPv6 server"
    def log_id
      LOG_ID
    end

  end

end