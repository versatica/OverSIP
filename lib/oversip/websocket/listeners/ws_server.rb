module OverSIP::WebSocket

  class WsServer < Connection

   # Max size (bytes) of the buffered data when receiving HTTP headers
    # (avoid DoS attacks).
    HEADERS_MAX_SIZE = 2048

    WS_MAGIC_GUID_04 = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11".freeze
    WS_VERSIONS = { 7=>true, 8=>true, 13=>true }
    HDR_SUPPORTED_WEBSOCKET_VERSIONS = [ "X-Supported-WebSocket-Versions: #{WS_VERSIONS.keys.join(", ")}" ]


    attr_reader :outbound_flow_token
    attr_writer :ws_established, :client_closed


    def initialize
      @buffer = ::IO::Buffer.new
      @state = :init
      @cvars = {}
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

      @connection_id = ::OverSIP::SIP::TransportManager.add_connection self, self.class, self.class.ip_type, @remote_ip, @remote_port

      # Create an Outbound (RFC 5626) flow token for this connection.
      @outbound_flow_token = ::OverSIP::SIP::TransportManager.add_outbound_connection self

      # Initialize @cvars.
      @cvars = {}

      log_system_debug("connection opened from " << remote_desc)  if $oversip_debug
    end


    def remote_desc force=nil
      if force
        @remote_desc = case @remote_ip_type
          when :ipv4  ; "#{@remote_ip}:#{@remote_port.to_s}"
          when :ipv6  ; "[#{@remote_ip}]:#{@remote_port.to_s}"
          end
      else
        @remote_desc ||= case self.class.ip_type
          when :ipv4  ; "#{@remote_ip}:#{@remote_port.to_s}"
          when :ipv6  ; "[#{@remote_ip}]:#{@remote_port.to_s}"
          end
      end
    end


    def unbind cause=nil
      @state = :ignore

      # Remove the connection.
      self.class.connections.delete @connection_id

      # Remove the Outbound token flow.
      ::OverSIP::SIP::TransportManager.delete_outbound_connection @outbound_flow_token

      @local_closed = true  if cause == ::Errno::ETIMEDOUT
      @local_closed = false  if @client_closed

      if $oversip_debug
        log_msg = "connection from #{remote_desc} "
        log_msg << ( @local_closed ? "locally closed" : "remotely closed" )
        log_msg << " (cause: #{cause.inspect})"  if cause
        log_system_debug log_msg
      end unless $!

      if @ws_established
        begin
          ::OverSIP::WebSocketEvents.on_disconnection self, !@local_closed
        rescue ::Exception => e
          log_system_error "error calling OverSIP::WebSocketEvents.on_disconnection():"
          log_system_error e
        end
      end unless $!
    end


    def receive_data data
      @state == :ignore and return
      @buffer << data

      while (case @state
        when :init
          @http_parser = ::OverSIP::WebSocket::HttpRequestParser.new
          @http_request = ::OverSIP::WebSocket::HttpRequest.new
          @http_parser_nbytes = 0
          @bytes_remaining = 0
          @state = :http_headers

        when :http_headers
          parse_http_headers

        when :check_http_request
          check_http_request

        when :ws_connection_callback
          ws_connection_callback

        when :accept_ws_handshake
          accept_ws_handshake

        when :websocket
          @ws_established = true
          @ws_framing.receive_data
          false

        when :ignore
          false
        end)
      end  # while

    end


    def parse_http_headers
      return false if @buffer.empty?

      # Parse the currently buffered data. If parsing fails @http_parser_nbytes gets nil value.
      unless @http_parser_nbytes = @http_parser.execute(@http_request, @buffer.to_str, @http_parser_nbytes)
        log_system_warn "parsing error: \"#{@http_parser.error}\""
        close_connection_after_writing
        @state = :ignore
        return false
      end

      # Avoid flood attacks in TCP (very long headers).
      if @http_parser_nbytes > HEADERS_MAX_SIZE
        log_system_warn "DoS attack detected: headers size exceedes #{HEADERS_MAX_SIZE} bytes, closing connection with #{remote_desc}"
        close_connection
        @state = :ignore
        return false
      end

      return false  unless @http_parser.finished?

      # Clear parsed data from the buffer.
      @buffer.read(@http_parser_nbytes)

      @http_request.connection = self

      @state = :check_http_request
      true
    end  # parse_headers


    def check_http_request

      # HTTP method must be GET.
      if @http_request.http_method != :GET
        log_system_notice "rejecting HTTP #{@http_request.http_method} request => 405"
        http_reject 405
        return false
      end

      # "Sec-WebSocket-Version" must be 8.
      unless WS_VERSIONS[@http_request.hdr_sec_websocket_version]
        if @http_request.hdr_sec_websocket_version
          log_system_notice "WebSocket version #{@http_request.hdr_sec_websocket_version} not implemented => 426"
        else
          log_system_notice "WebSocket version header not present => 426"
        end
        http_reject 426, nil, HDR_SUPPORTED_WEBSOCKET_VERSIONS
        return false
      end

      # Connection header must include "upgrade".
      unless @http_request.hdr_connection and @http_request.hdr_connection.include? "upgrade"
        log_system_notice "Connection header must include \"upgrade\" => 400"
        http_reject 400, "Connection header must include \"upgrade\""
        return false
      end

      # "Upgrade: websocket" is required.
      unless @http_request.hdr_upgrade == "websocket"
        log_system_notice "Upgrade header must be \"websocket\" => 400"
        http_reject 400, "Upgrade header must be \"websocket\""
        return false
      end

      # Sec-WebSocket-Key is required.
      unless @http_request.hdr_sec_websocket_key
        log_system_notice "Sec-WebSocket-Key header not present => 400"
        http_reject 400, "Sec-WebSocket-Key header not present"
        return false
      end

      # Check Sec-WebSocket-Protocol.
      if @http_request.hdr_sec_websocket_protocol
        if @http_request.hdr_sec_websocket_protocol.include? WS_SIP_PROTOCOL
          @websocket_protocol_negotiated = true
        else
          log_system_notice "Sec-WebSocket-Protocol does not contain a supported protocol but #{@http_request.hdr_sec_websocket_protocol} => 501"
          http_reject 501, "No Suitable WebSocket Protocol"
          return false
        end
      end

      @state = :ws_connection_callback
      true
    end


    def ws_connection_callback
      begin
        ::OverSIP::WebSocketEvents.on_connection self, @http_request
      rescue ::Exception => e
        log_system_error "error calling OverSIP::WebSocketEvents.on_connection() => 500:"
        log_system_error e
        http_reject 500
        return false
      end

      # The user provided callback could have reject the WS connection, so
      # check it not to reply a 101 after the reply sent by the user.
      if @state == :ws_connection_callback
        @state = :accept_ws_handshake
        true
      else
        false
      end
    end


    def accept_ws_handshake
      sec_websocket_accept = Digest::SHA1::base64digest @http_request.hdr_sec_websocket_key + WS_MAGIC_GUID_04

      extra_headers = [
        "Upgrade: websocket",
        "Connection: Upgrade",
        "Sec-WebSocket-Accept: #{sec_websocket_accept}"
      ]

      if @websocket_protocol_negotiated
        extra_headers << "Sec-WebSocket-Protocol: #{WS_SIP_PROTOCOL}"
      end

      if @websocket_extensions
        extra_headers << "Sec-WebSocket-Extensions: #{@websocket_extensions.to_s}"
      end

      @http_request.reply 101, nil, extra_headers

      # Set the WS framing layer and WS application layer.
      @ws_framing = ::OverSIP::WebSocket::WsFraming.new self, @buffer
      ws_sip_app = ::OverSIP::WebSocket::WsSipApp.new self, @ws_framing
      @ws_framing.ws_app = ws_sip_app

      @state = :websocket
      true
    end


    def http_reject status_code=403, reason_phrase=nil, extra_headers=nil
      @http_request.reply(status_code, reason_phrase, extra_headers)
      close_connection_after_writing
      @state = :ignore
    end


    # Parameters ip and port are just included because they are needed in UDP, so the API remains equal.
    def send_sip_msg msg, ip=nil, port=nil
      if self.error?
        log_system_notice "SIP message could not be sent, connection is closed"
        return false
      end

      # If the SIP message is fully valid UTF-8 send a WS text frame.
      if msg.force_encoding(::Encoding::UTF_8).valid_encoding?
        @ws_framing.send_text_frame msg

      # If not, send a WS binary frame.
      else
        @ws_framing.send_binary_frame msg
      end

      true
    end

  end

end

