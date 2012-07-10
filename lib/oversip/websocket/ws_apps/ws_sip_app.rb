module OverSIP::WebSocket

  class WsSipApp < WsApp

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


    attr_reader :outbound_flow_token


    def initialize *args
      super
      # WebSocket is message boundary so we just need a SIP parser instance.
      @@parser ||= ::OverSIP::SIP::MessageParser.new
      @parser = @@parser

      # If the request comes from the TLS proxy then take it into account.
      if @connection.class == ::OverSIP::WebSocket::IPv4TlsTunnelServer
        @connection_id = ::OverSIP::SIP::TransportManager.add_connection self, ::OverSIP::WebSocket::IPv4WssSipApp, :ipv4,
                                                                         @connection.remote_ip, @connection.remote_port
      elsif @connection.class == ::OverSIP::WebSocket::IPv6TlsTunnelServer
        @connection_id = ::OverSIP::SIP::TransportManager.add_connection self, ::OverSIP::WebSocket::IPv6WssSipApp, :ipv6,
                                                                         @connection.remote_ip, @connection.remote_port
      else
        @connection_id = ::OverSIP::SIP::TransportManager.add_connection self, self.class, self.class.ip_type,
                                                                         @connection.remote_ip, @connection.remote_port
      end

      # Create an Outbound (RFC 5626) flow token for this connection.
      @outbound_flow_token = ::OverSIP::SIP::TransportManager.add_outbound_connection self
    end


    def process_text_message ws_message
      process_sip_message ws_message
    end


    def process_binary_message ws_message
      process_sip_message ws_message
    end


    def process_sip_message ws_message
      # Just a single SIP message allowed per WS message.
      @parser.reset

      # Better to encode it as BINARY (to later extract the body).
      ws_message.force_encoding ::Encoding::BINARY

      unless parser_nbytes = @parser.execute(ws_message, 0)
        if wrong_message = @parser.parsed
          log_system_warn "SIP parsing error for #{MSG_TYPE[wrong_message.class]}: \"#{@parser.error}\""
        else
          log_system_warn "SIP parsing error: \"#{@parser.error}\""
        end
        close_connection 4000, "SIP message parsing error"
        return
      end

      unless @parser.finished?
        log_system_warn "SIP parsing error: message not completed"

        close_connection 4001, "SIP message incomplete"
        return
      end

      # At this point we've got a SIP::Request, SIP::Response or :outbound_keepalive symbol.
      @msg = @parser.parsed

      # Received data is a SIP Outbound keealive (double CRLF). Reply with single CRLF.
      if @msg == :outbound_keepalive
        log_system_debug "Outbound keepalive received, replying single CRLF"  if $oversip_debug
        @ws_framing.send_text_frame(CRLF)
        return
      end

      @parser.post_parsing

      @msg.connection = self
      @msg.transport = self.class.transport
      @msg.source_ip = @connection.remote_ip
      @msg.source_port = @connection.remote_port
      @msg.source_ip_type = @connection.remote_ip_type

      return  unless valid_message?
      add_via_received_rport  if @msg.request?
      return  unless check_via_branch

      # Get the body.
      if parser_nbytes != ws_message.bytesize
        @msg.body = ws_message[parser_nbytes..-1]

        if @msg.content_length and @msg.content_length != @msg.body.bytesize
          log_system_warn "SIP message body size (#{@msg.body.bytesize}) does not match Content-Length (#{@msg.content_length.inspect}), ignoring message"
          close_connection 4002, "SIP message body size does not match Content-Length"
          return
        end
      end

      if @msg.request?
        process_request
      else
        process_response
      end

    end


    def tcp_closed
      # Remove the connection.
      self.class.connections.delete @connection_id

      # Remove the Outbound token flow.
      ::OverSIP::SIP::TransportManager.delete_outbound_connection @outbound_flow_token
    end


    # Parameters ip and port are just included because they are needed in UDP, so the API remains equal.
    def send_sip_msg msg, ip=nil, port=nil
      # If the SIP message is fully valid UTF-8 send a WS text frame.
      if msg.force_encoding(::Encoding::UTF_8).valid_encoding?
        unless @ws_framing.send_text_frame(msg)
          log_system_notice "SIP message could not be sent, WebSocket connection is closed"
          return false
        end

      # If not, send a WS binary frame.
      else
        unless @ws_framing.send_binary_frame(msg)
          log_system_notice "SIP message could not be sent, WebSocket connection is closed"
          return false
        end
      end

      true
    end


  end  # WsSipApplication

end
