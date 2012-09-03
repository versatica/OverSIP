module OverSIP

  module SystemEvents

    extend ::OverSIP::Logger

    def self.on_configuration
      log_system_notice "on_configuration() method is not defined"
    end

    def self.on_started
      log_system_notice "on_started() method is not defined"
    end

    def self.on_user_reload
      log_system_notice "on_user_reload() method is not defined"
    end

    def self.on_terminated error
      log_system_notice "on_terminated() method is not defined"
    end


  end

  module SipEvents

    extend ::OverSIP::Logger

    def self.on_request request
      log_system_notice "on_request() method is not defined"
    end

    def self.on_client_tls_handshake connection, pems
      log_system_notice "on_client_tls_handshake() method is not defined"
    end

    def self.on_server_tls_handshake connection, pems
      log_system_notice "on_server_tls_handshake() method is not defined"
    end

  end

  module WebSocketEvents

    extend ::OverSIP::Logger

    def self.on_connection connection, http_request
      log_system_notice "on_connection() method is not defined"
    end

    def self.on_disconnection connection, client_closed
      log_system_notice "on_disconnection() method is not defined"
    end

    def self.on_client_tls_handshake connection, pems
      log_system_notice "on_client_tls_handshake() method is not defined"
    end

  end

end
