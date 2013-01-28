module OverSIP::WebSocket

  def self.module_init
    conf = ::OverSIP.configuration

    @callback_on_client_tls_handshake = conf[:websocket][:callback_on_client_tls_handshake]
  end

  def self.callback_on_client_tls_handshake
    @callback_on_client_tls_handshake
  end

end
