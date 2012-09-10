module OverSIP::SIP

  class Connection < ::EM::Connection

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

      def outbound_listener?
        @is_outbound_listener
      end
    end


    attr_reader :cvars

    def initialize
      @parser = ::OverSIP::SIP::MessageParser.new
      @buffer = ::IO::Buffer.new
      @state = :init
      @cvars = {}

      # Set the socket sending error handling to report the error:
      # :ERRORHANDLING_KILL, :ERRORHANDLING_IGNORE, :ERRORHANDLING_REPORT
      self.send_error_handling = :ERRORHANDLING_REPORT
    end

    def receive_senderror error, data
      log_system_error "Socket sending error: #{error.inspect}, #{data.inspect}"
    end

    def transport
      self.class.transport
    end

    def open?
      ! error?
    end

    # close() method causes @local_closed = true.
    alias close close_connection_after_writing
  end

end

