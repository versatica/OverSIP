module OverSIP::SIP

  class Reactor < ::EM::Connection

    include ::OverSIP::Logger
    include ::OverSIP::SIP::MessageProcessor

    class << self
      attr_accessor :ip_type, :ip, :port, :transport,
                    :via_core,
                    :record_route,
                    :outbound_record_route_fragment, :outbound_path_fragment,
                    :connections,
                    :invite_server_transactions, :non_invite_server_transactions,
                    :invite_client_transactions, :non_invite_client_transactions

      def reliable_transport_listener?
        @is_reliable_transport_listener
      end
    end

    def initialize
      @parser = ::OverSIP::SIP::MessageParser.new
      @buffer = ::IO::Buffer.new
      @state = :init

      # Set the socket sending error handling to report the error:
      # :ERRORHANDLING_KILL, :ERRORHANDLING_IGNORE, :ERRORHANDLING_REPORT
      self.send_error_handling = :ERRORHANDLING_REPORT
    end

    def receive_senderror error, data
      log_system_error "Socket sending error: #{error.inspect}, #{data.inspect}"
    end

  end  # class Reactor

end

