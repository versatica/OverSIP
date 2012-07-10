module OverSIP::WebSocket

  class TlsTunnelServer < TcpServer

    def initialize
      @http_parser = ::OverSIP::WebSocket::HttpRequestParser.new
      @buffer = ::IO::Buffer.new
      @state = :init
    end


    def post_connection
      begin
        @remote_port, @remote_ip = ::Socket.unpack_sockaddr_in(get_peername)
      rescue => e
        log_system_error "error obtaining remote IP/port (#{e.class}: #{e.message}), closing connection"
        close_connection
        @state = :ignore
        return
      end
      @connection_log_id = ::SecureRandom.hex(4)

      log_system_info "connection from the TLS tunnel " << remote_desc
    end


    def receive_data data
      @state == :ignore and return
      @buffer << data

      while (case @state
        when :init
          @http_request = ::OverSIP::WebSocket::HttpRequest.new
          @http_parser.reset
          @http_parser_nbytes = 0
          @bytes_remaining = 0
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
          check_http_request

        when :accept_ws_handshake
          accept_ws_handshake

        when :websocket_frames
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

