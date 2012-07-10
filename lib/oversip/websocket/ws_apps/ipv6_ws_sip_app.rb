module OverSIP::WebSocket

  class IPv6WsSipApp < WsSipApp

    @ip_type = :ipv6
    @transport = :ws
    @connections = {}
    @invite_server_transactions = {}
    @non_invite_server_transactions = {}
    @invite_client_transactions = {}
    @non_invite_client_transactions = {}
    @is_reliable_transport_listener = true

    LOG_ID = "WS IPv6 SIP app"
    def log_id
      LOG_ID
    end

  end

end
