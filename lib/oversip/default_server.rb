module OverSIP

  module SystemEvents

    extend ::OverSIP::Logger

    def self.on_initialize
    end

    def self.on_started
    end

    def self.on_user_reload
    end

    def self.on_terminated error
    end


  end

  module SipEvents

    extend ::OverSIP::Logger

    def self.on_request request
    end

    def self.on_client_tls_handshake connection, pems
    end

    def self.on_server_tls_handshake connection, pems
    end

  end

  module WebSocketEvents

    extend ::OverSIP::Logger

    def self.on_connection connection, http_request
    end

    def self.on_disconnection connection, client_closed
    end

    def self.on_client_tls_handshake connection, pems
    end

  end

end
