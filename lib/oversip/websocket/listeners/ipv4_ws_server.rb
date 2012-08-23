module OverSIP::WebSocket

  class IPv4WsServer < WsServer

    @ip_type = :ipv4
    @transport = :ws
    @connections = {}
    @invite_server_transactions = {}
    @non_invite_server_transactions = {}
    @invite_client_transactions = {}
    @non_invite_client_transactions = {}
    @is_reliable_transport_listener = true

    LOG_ID = "SIP WS IPv4 server"
    def log_id
      LOG_ID
    end

  end

end