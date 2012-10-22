module OverSIP::WebSocket

  def self.module_init
    conf = ::OverSIP.configuration

    @callback_on_client_tls_handshake = conf[:websocket][:callback_on_client_tls_handshake]

    @timeout_anti_slow_attacks = conf[:websocket][:timeout_anti_slow_attacks]
  end

  def self.callback_on_client_tls_handshake
    @callback_on_client_tls_handshake
  end

  def self.timeout_anti_slow_attacks
    @timeout_anti_slow_attacks
  end

end
