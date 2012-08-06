module OverSIP

  module SystemEvents

    extend ::OverSIP::Logger

    def self.on_started
      log_system_notice "on_started() event is not defined"
    end

    def self.on_user_reload
      log_system_notice "on_user_reload() event is not defined"
    end

  end

  module SipEvents

    extend ::OverSIP::Logger

    def self.on_request request
      log_system_notice "on_request() event is not defined"
    end

  end

  module WebSocketEvents

    extend ::OverSIP::Logger

    def self.on_connection connection, http_request
      log_system_notice "on_connection() event is not defined"
    end

    def self.on_connection_closed connection, client_closed
      log_system_notice "on_connection_closed() event is not defined"
    end

  end

end
