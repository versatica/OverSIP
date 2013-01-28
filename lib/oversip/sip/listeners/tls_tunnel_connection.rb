module OverSIP::SIP

  class TlsTunnelConnection < TcpConnection

    # Max size (bytes) of the buffered data when receiving message headers
    # (avoid DoS attacks).
    HEADERS_MAX_SIZE = 16384

    def process_received_data
      @state == :ignore and return

      while (case @state
        when :init
          @parser.reset
          @parser_nbytes = 0
          # If it's a TCP connection from the TLS tunnel then parse the HAProxy Protocol line
          # if it's not yet done.
          unless @haproxy_protocol_parsed
            @state = :haproxy_protocol
          else
            @state = :headers
          end

        when :haproxy_protocol
          parse_haproxy_protocol

        when :headers
          parse_headers

        when :body
          get_body

        when :finished
          if @msg.request?
            process_request
          else
            process_response
          end

          # Set state to :init.
          @state = :init
          # Return true to continue processing possible remaining data.
          true

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

        # Add the connection with the client's source data. Note that we pass a TlsServer as class, but
        # the server instance is a TcpServer.
        @connection_id = case @remote_ip_type
          when :ipv4
            ::OverSIP::SIP::TransportManager.add_connection self, ::OverSIP::SIP::IPv4TlsServer, :ipv4, @remote_ip, @remote_port
          when :ipv6
            ::OverSIP::SIP::TransportManager.add_connection self, ::OverSIP::SIP::IPv6TlsServer, :ipv6, @remote_ip, @remote_port
          end

        # Update log information.
        remote_desc true

        # Remove the HAProxy Protocol line from the received data.
        @buffer.read haproxy_protocol_data[0]

        @state = :headers

      else
        log_system_error "HAProxy Protocol parsing error, closing connection"
        close_connection_after_writing
        @state = :ignore
        return false
      end
    end

  end

end

