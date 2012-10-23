module OverSIP::WebSocket

  class WsSipApp

    include ::OverSIP::Logger
    include ::OverSIP::SIP::MessageProcessor

    def self.class_init
      @@ws_keepalive_interval = ::OverSIP.configuration[:websocket][:ws_keepalive_interval]
    end


    LOG_ID = "WsSipApp"
    def log_id
      LOG_ID
    end


    def initialize connection, ws_framing
      @connection = connection
      @ws_framing = ws_framing
      @ws_message = ::IO::Buffer.new

      # Mantain WebSocket keepalive.
      @ws_framing.do_keep_alive @@ws_keepalive_interval  if @@ws_keepalive_interval

      # WebSocket is message boundary so we just need a SIP parser instance.
      @@parser ||= ::OverSIP::SIP::MessageParser.new
      @parser = @@parser
    end


    def receive_payload_data payload_data
      # payload_data is always Encoding::BINARY so also @ws_message.to_str.
      @ws_message << payload_data

      # Check max message size.
      return false  if @ws_message.size > ::OverSIP::Security.websocket_max_message_size
      true
    end


    def message_done type
      log_system_debug "received WS message: type=#{type}, length=#{@ws_message.size}"  if $oversip_debug

      # Better to encode it as BINARY (to later extract the body).
      process_sip_message @ws_message.to_str.force_encoding ::Encoding::BINARY

      @ws_message.clear
      true
    end


    def process_sip_message ws_message
      # Just a single SIP message allowed per WS message.
      @parser.reset

      unless parser_nbytes = @parser.execute(ws_message, 0)
        if wrong_message = @parser.parsed
          log_system_warn "SIP parsing error for #{MSG_TYPE[wrong_message.class]}: \"#{@parser.error}\""
        else
          log_system_warn "SIP parsing error: \"#{@parser.error}\""
        end
        @connection.close 4000, "SIP message parsing error"
        return
      end

      unless @parser.finished?
        log_system_warn "SIP parsing error: message not completed"

        @connection.close 4001, "SIP message incomplete"
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

      @msg.connection = @connection
      @msg.transport = @connection.class.transport
      @msg.source_ip = @connection.remote_ip
      @msg.source_port = @connection.remote_port
      @msg.source_ip_type = @connection.remote_ip_type

      return  unless valid_message? @parser
      # TODO: Make it configurable:
      #add_via_received_rport  if @msg.request?
      return  unless check_via_branch

      # Get the body.
      if parser_nbytes != ws_message.bytesize
        @msg.body = ws_message[parser_nbytes..-1]

        # Check max body size.
        body_length = if @msg.content_length
          @msg.content_length
        elsif @msg.body
          @msg.body.bytesize
        else
          0
        end

        if body_length > ::OverSIP::Security.sip_max_body_size
          if @msg.request?
            log_system_warn "request body size too big => 403"
            @msg.reply 403, "body size too big"
          else
            log_system_warn "response body size too big, discarding response"
          end
          @connection.close 4002, "SIP message body too big"
          return
        end

        if @msg.content_length and @msg.content_length != @msg.body.bytesize
          log_system_warn "SIP message body size (#{@msg.body.bytesize}) does not match Content-Length (#{@msg.content_length.inspect}), ignoring message"
          @connection.close 4002, "SIP message body size does not match Content-Length"
          return
        end
      end

      if @msg.request?
        process_request
      else
        process_response
      end

    end

  end

end
