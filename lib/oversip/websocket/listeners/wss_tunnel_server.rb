module OverSIP::WebSocket

  class WssTunnelServer < WsServer

    def post_connection
      begin
        # Temporal @remote_ip and @remote_port until the HAProxy protocol line is parsed.
        @remote_port, @remote_ip = ::Socket.unpack_sockaddr_in(get_peername)
      rescue => e
        log_system_error "error obtaining remote IP/port (#{e.class}: #{e.message}), closing connection"
        close_connection
        @state = :ignore
        return
      end

      # Create an Outbound (RFC 5626) flow token for this connection.
      @outbound_flow_token = ::OverSIP::SIP::TransportManager.add_outbound_connection self

      log_system_debug ("connection from the TLS tunnel " << remote_desc)  if $oversip_debug
    end


    def unbind cause=nil
      @state = :ignore

      # Remove the connection.
      self.class.connections.delete @connection_id  if @connection_id

      # Remove the Outbound token flow.
      ::OverSIP::SIP::TransportManager.delete_outbound_connection @outbound_flow_token

      @local_closed = true  if cause == ::Errno::ETIMEDOUT
      @local_closed = false  if @client_closed

      if $oversip_debug
        log_msg = "connection from the TLS tunnel #{remote_desc} "
        log_msg << ( @local_closed ? "locally closed" : "remotely closed" )
        log_msg << " (cause: #{cause.inspect})"  if cause
        log_system_debug log_msg
      end unless $!

      if @ws_established
        # Run OverSIP::WebSocketEvents.on_disconnection
        ::Fiber.new do
          begin
            ::OverSIP::WebSocketEvents.on_disconnection self, !@local_closed
          rescue ::Exception => e
            log_system_error "error calling OverSIP::WebSocketEvents.on_disconnection():"
            log_system_error e
          end
        end.resume
      end unless $!
    end


    def process_received_data
      @state == :ignore and return

      while (case @state
        when :init
          @http_parser = ::OverSIP::WebSocket::HttpRequestParser.new
          @http_request = ::OverSIP::WebSocket::HttpRequest.new
          @http_parser.reset
          @http_parser_nbytes = 0
          @bytes_remaining = 0
          @parsing_message = false
          # If it's a TCP connection from the TLS proxy then parse the HAProxy Protocol line
          # if it's not yet done.
          unless @haproxy_protocol_parsed
            @state = :haproxy_protocol
          else
            @state = :http_headers
          end

        when :haproxy_protocol
          parse_haproxy_protocol

        when :http_headers
          parse_http_headers

        when :check_http_request
          # Stop the timer that avoids slow attacks.
          @timer_anti_slow_attack_http.cancel
          @parsing_message = false

          check_http_request

        when :on_connection_callback
          do_on_connection_callback
          false

        when :accept_ws_handshake
          accept_ws_handshake

        when :websocket
          @ws_established ||= true
          return false  if @buffer.size.zero?
          @ws_framing.receive_data
          false

        when :ignore
          false
        end)
      end  # while

    end


    def parse_haproxy_protocol
      if (haproxy_protocol_data = ::OverSIP::Utils.parse_haproxy_protocol(@buffer.to_str))
        @haproxy_protocol_parsed = true

        # Update connection information.
        @remote_ip_type = haproxy_protocol_data[1]
        @remote_ip = haproxy_protocol_data[2]
        @remote_port = haproxy_protocol_data[3]

        # Update log information.
        remote_desc true

        # Remove the HAProxy Protocol line from the received data.
        @buffer.read haproxy_protocol_data[0]

        @state = :http_headers

      # If parsing fails then the TLS proxy has sent us a wrong HAProxy Protocol line ¿?
      else
        log_system_error "HAProxy Protocol parsing error, closing connection"
        close_connection_after_writing
        @state = :ignore
        return false
      end
    end

  end

end

