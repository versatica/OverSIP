module OverSIP::WebSocket

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
      @buffer = ::IO::Buffer.new
      @state = :init
      @cvars = {}
    end

    def open?
      ! error?
    end

    def close status=nil, reason=nil
      # When in WebSocket protocol send a close control frame before closing
      # the connection.
      if @state == :websocket
        @ws_framing.send_close_frame status, reason
      end

      close_connection_after_writing
      @state = :ignore
    end
  end

end
