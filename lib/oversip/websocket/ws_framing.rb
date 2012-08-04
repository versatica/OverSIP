module OverSIP::WebSocket

  class WsFraming

    include ::OverSIP::Logger

    OPCODE = {
      0  => :continuation,
      1  => :text,
      2  => :binary,
      8  => :close,
      9  => :ping,
      10 => :pong
    }

    keepalive_ping_frame = "".encode ::Encoding::BINARY
    keepalive_ping_frame << 137
    keepalive_ping_frame << "keep-alive".bytesize
    keepalive_ping_frame << "keep-alive".encode(::Encoding::BINARY)
    KEEPALIVE_PING_FRAME = keepalive_ping_frame


    attr_writer :ws_app


    def self.class_init
      @@max_frame_size = ::OverSIP.configuration[:websocket][:max_ws_frame_size]
    end


    def log_id
      @log_id ||= "WsFramming #{@connection.connection_log_id}"
    end


    def initialize connection, buffer
      @connection = connection
      @buffer = buffer
      @utf8_validator = ::OverSIP::WebSocket::FramingUtils::Utf8Validator.allocate
      @state = :init
    end


    def do_keep_alive interval
      @keep_alive_timer = ::EM::PeriodicTimer.new(interval) do
        log_system_debug "sending keep-alive ping frame: payload_length=10"  if $oversip_debug
        @connection.send_data KEEPALIVE_PING_FRAME
      end
    end


    def receive_data
      while (case @state
        when :init
          return false  if @buffer.size < 2

          byte1 = @buffer.read(1).getbyte(0)
          byte2 = @buffer.read(1).getbyte(0)

          # FIN is the bit 0.
          @fin = (byte1 & 0b10000000) == 0b10000000

          # RSV1-3 are bits 1-3.
          @rsv1 = (byte1 & 0b01000000) == 0b01000000
          @rsv2 = (byte1 & 0b00100000) == 0b00100000
          @rsv3 = (byte1 & 0b00010000) == 0b00010000

          if @rsv1 or @rsv2 or @rsv3
            log_system_notice "frame has RSV bits set, clossing the connection"
            send_close_frame 1002, "RSV bit set not supported"
            return false
          end

          # opcode are bits 4-7.
          @opcode = byte1 & 0b00001111
          unless (@sym_opcode = OPCODE[@opcode])
            send_close_frame 1002, "unknown opcode=#{@opcode}"
            return false
          end

          # MASK is bit 8.
          @mask = (byte2 & 0b10000000) == 0b10000000
          unless @mask
            send_close_frame 1002, "MASK bit not set"
            return false
          end

          # payload_len are bits 9-15.
          length = byte2 & 0b01111111

          case length
          # Length defined by 8 bytes.
          when 127
            @state = :payload_length_8_bytes
          # Length defined by 2 bytes.
          when 126
            @state = :payload_length_2_bytes
          # Length defined by already received 7 bits.
          else
            @payload_length = length
            @state = :masking_key
          end

          @payload = nil
          true

        when :payload_length_2_bytes
          return false  if @buffer.size < 2

          # Get the payload length and remove first two bytes fro
          # the buffer at the same time.
          @payload_length = @buffer.read(2).unpack('n').first

          @state = :masking_key
          true

        when :payload_length_8_bytes
          return false  if @buffer.size < 8

          # Get the payload length.
          # NOTE: Just take the last 4 bytes (4 GB frame is enough!!!),
          # Check that first 4 bytes are 0000. If not then the frame is bigger
          # than 4 GB and must be rejected!

          if @buffer.read(4).unpack('N').first != 0
            log_system_notice "frame size bigger than 4 GB, rejected"
            send_close_frame 1008
            return false
          end

          @payload_length = @buffer.read(4).unpack('N').first

          @state = :masking_key
          true

        when :masking_key
          return false  if @buffer.size < 4

          # Get the masking key (4 bytes) and remove first 4 bytes
          # from the buffer.
          @masking_key = @buffer.read(4)

          @state = :check_frame
          true

        when :check_frame
          # All control frames MUST have a payload length of 125 bytes or
          # less and MUST NOT be fragmented.
          if control_frame? and @payload_length > 125
            log_system_notice "received invalid control frame (payload_length > 125), sending close frame"
            send_close_frame 1002
            return false
          end

          if control_frame? and not @fin
            log_system_notice "received invalid control frame (FIN=0), sending close frame"
            send_close_frame 1002, "forbidden FIN=0 in control frame"
            return false
          end

          # A continuation frame can only arrive if previously a text/binary frame
          # arrived with FIN=0.
          if continuation_frame? and not @msg_sym_opcode
            log_system_notice "invalid continuation frame received (no previous unfinished message), sending close frame"
            send_close_frame 1002, "invalid continuation frame received"
            return false
          end

          # If a previous frame had FIN=0 and opcode=text/binary, then it cannot arrive
          # a new frame with opcode=text/binary.
          if @msg_sym_opcode and text_or_binary_frame?
            log_system_notice "invalid text/binary frame received (expecting a continuation frame), sending close frame"
            send_close_frame 1002, "expected a continuation frame"
            return false
          end

          # Check max frame size.
          if @payload_length > @@max_frame_size
            send_close_frame 1009, "frame too big"
            return false
          end

          @state = :payload_data
          true

        when :payload_data
          return false  if @buffer.size < @payload_length

          unless @payload_length.zero?
            # NOTE: @payload will always be Encoding::BINARY
            @payload = ::OverSIP::WebSocket::FramingUtils.unmask @buffer.read(@payload_length), @masking_key
          end
          # NOTE: @payload could be nil.

          @state = :process_frame
          true

        when :process_frame
          # Set it here as it could be changed later in this block.
          @state = :init

          case @sym_opcode

          when :text
            log_system_debug "received text frame: FIN=#{@fin}, RSV1-3=#{@rsv1}/#{@rsv2}/#{@rsv3}, payload_length=#{@payload_length}"  if $oversip_debug

            # Store the opcode of the first frame (if there is more frames for same message
            # they will have opcode=continuation).
            @msg_sym_opcode = @sym_opcode

            # Reset the UTF8 validator.
            @utf8_validator.reset

            if @payload
              if (valid_utf8 = @utf8_validator.validate(@payload)) == false
                log_system_notice "received single text frame contains invalid UTF-8, closing the connection"
                send_close_frame 1007, "single text frame contains invalid UTF-8"
                return false
              end

              if @fin and not valid_utf8
                log_system_notice "received single text frame contains incomplete UTF-8, closing the connection"
                send_close_frame 1007, "single text frame contains incomplete UTF-8"
                return false
              end

              return false  unless @ws_app.receive_payload_data @payload
            end

            # If message is finished tell it to the WS application.
            if @fin
              @ws_app.message_done @msg_sym_opcode
              @msg_sym_opcode = nil
            end

          when :binary
            log_system_debug "received binary frame: FIN=#{@fin}, RSV1-3=#{@rsv1}/#{@rsv2}/#{@rsv3}, payload_length=#{@payload_length}"  if $oversip_debug

            # Store the opcode of the first frame (if there is more frames for same message
            # they will have opcode=continuation).
            @msg_sym_opcode = @sym_opcode

            if @payload
              return false  unless @ws_app.receive_payload_data @payload
            end

            # If message is finished tell it to the WS application.
            if @fin
              @ws_app.message_done @msg_sym_opcode
              @msg_sym_opcode = nil
            end

          when :continuation
            log_system_debug "received continuation frame: FIN=#{@fin}, RSV1-3=#{@rsv1}/#{@rsv2}/#{@rsv3}, payload_length=#{@payload_length}"  if $oversip_debug

            if @payload
              if @msg_sym_opcode == :text
                if (valid_utf8 = @utf8_validator.validate(@payload)) == false
                  log_system_notice "received continuation text frame contains invalid UTF-8, closing the connection"
                  send_close_frame 1007, "continuation text frame contains invalid UTF-8"
                  return false
                end

                if @fin and not valid_utf8
                  log_system_notice "received continuation final text frame contains incomplete UTF-8, closing the connection"
                  send_close_frame 1007, "continuation final text frame contains incomplete UTF-8"
                  return false
                end
              end

              return false  unless @ws_app.receive_payload_data @payload
            end

            # If message is finished tell it to the WS application.
            if @fin
              @ws_app.message_done @msg_sym_opcode
              @msg_sym_opcode = nil
            end

          when :close
            if @payload_length >= 2
              status = ""
              status << @payload.getbyte(0) << @payload.getbyte(1)
              status =  status.unpack('n').first
              if (reason = @payload[2..-1])
                # Reset the UTF8 validator.
                @utf8_validator.reset

                # The UTF-8 validator returns:
                # - true: Valid UTF-8 string.
                # - nil: Valid but not terminated UTF-8 string.
                # - false: Invalid UTF-8 string.
                # So it must be true for the close frame reason.
                unless @utf8_validator.validate(reason)
                  log_system_notice "received close frame with invalid UTF-8 data in the reason: status=#{status.inspect}"
                  send_close_frame 1007, "close frame reason contains incomplete UTF-8"
                  return false
                end
              end
            else
              status = nil
            end

            case status
            when 1002
              log_system_notice "received close frame due to WS protocol error: status=1002, reason=#{reason.inspect}"
            when 1003
              log_system_notice "received close frame due to sent data type: status=1003, reason=#{reason.inspect}"
            when 1007
              log_system_notice "received close frame due to non valid UTF-8 data sent: status=1007, reason=#{reason.inspect}"
            when 1009
              log_system_notice "received close frame due to too big message sent: status=1009, reason=#{reason.inspect}"
            when 1010
              log_system_notice "received close frame due to extensions negotiation failure: status=1010, reason=#{reason.inspect}"
            else
              log_system_debug "received close frame: status=#{status.inspect}, reason=#{reason.inspect}"  if $oversip_debug
            end

            send_close_frame nil, nil, true
            return false

          when :ping
            log_system_debug "received ping frame: payload_length=#{@payload_length}"  if $oversip_debug
            send_pong_frame @payload

          when :pong
            log_system_debug "received pong frame: payload_length=#{@payload_length}"  if $oversip_debug

          end

          true

        when :ws_closed
          false

        when :tcp_closed
          false

        end)
      end # while

    end  # receive_data


    def control_frame?
      @opcode > 2
    end


    def text_or_binary_frame?
      @opcode == 1 or @opcode == 2
    end


    def continuation_frame?
      @opcode == 0
    end


    # NOTE: A WS message is always set in a single WS frame.
    def send_text_frame message
      case @state
      when :ws_closed
        log_system_debug "cannot send text frame, WebSocket session is closed"  if $oversip_debug
        return false
      when :tcp_closed
        log_system_debug "cannot send text frame, TCP session is closed"  if $oversip_debug
        return false
      end
      log_system_debug "sending text frame: payload_length=#{message.bytesize}"  if $oversip_debug

      frame = "".encode ::Encoding::BINARY

      # byte1 = OPCODE_TO_INT[:text] | 0b10000000 => 129
      #
      # - FIN bit set.
      # - RSV1-3 bits not set.
      # - opcode = 1
      frame << 129

      length = message.bytesize
      if length <= 125
        frame << length # since rsv4 is 0
      elsif length < 65536 # write 2 byte length
        frame << 126
        frame << [length].pack('n')
      else # write 8 byte length
        frame << 127
        frame << [length >> 32, length & 0xFFFFFFFF].pack("NN")
      end

      if message.encoding == ::Encoding::BINARY
        frame << message
      else
        frame << message.force_encoding(::Encoding::BINARY)
      end

      @connection.send_data frame
      true
    end


    def send_binary_frame message
      case @state
      when :ws_closed
        log_system_debug "cannot send binary frame, WebSocket session is closed"  if $oversip_debug
        return false
      when :tcp_closed
        log_system_debug "cannot send binary frame, TCP session is closed"  if $oversip_debug
        return false
      end
      log_system_debug "sending binary frame: payload_length=#{message.bytesize}"  if $oversip_debug

      frame = "".encode ::Encoding::BINARY

      # byte1 = OPCODE_TO_INT[:binary] | 0b10000000 => 130
      #
      # - FIN bit set.
      # - RSV1-3 bits not set.
      # - opcode = 2
      frame << 130

      length = message.bytesize
      if length <= 125
        frame << length # since rsv4 is 0
      elsif length < 65536 # write 2 byte length
        frame << 126
        frame << [length].pack('n')
      else # write 8 byte length
        frame << 127
        frame << [length >> 32, length & 0xFFFFFFFF].pack("NN")
      end

      if message.encoding == ::Encoding::BINARY
        frame << message
      else
        frame << message.force_encoding(::Encoding::BINARY)
      end

      @connection.send_data frame
      true
    end


    def send_ping_frame data=nil
      case @state
      when :ws_closed
        log_system_debug "cannot send ping frame, WebSocket session is closed"  if $oversip_debug
        return false
      when :tcp_closed
        log_system_debug "cannot send ping frame, TCP session is closed"  if $oversip_debug
        return false
      end
      if data
        log_system_debug "sending ping frame: payload_length=#{data.bytesize}"  if $oversip_debug
      else
        log_system_debug "sending ping frame: payload_length=0"  if $oversip_debug
      end

      frame = "".encode ::Encoding::BINARY

      # byte1 = OPCODE_TO_INT[:ping] | 0b10000000 => 137
      #
      # - FIN bit set.
      # - RSV1-3 bits not set.
      # - opcode = 9
      frame << 137

      length = ( data ? data.bytesize : 0 )
      frame << length

      if data
        if data.encoding == ::Encoding::BINARY
          frame << data
        else
          frame << data.force_encoding(::Encoding::BINARY)
        end
      end

      @connection.send_data frame
      true
    end


    def send_pong_frame data=nil
      case @state
      when :ws_closed
        log_system_debug "cannot send pong frame, WebSocket session is closed"  if $oversip_debug
        return false
      when :tcp_closed
        log_system_debug "cannot send pong frame, TCP session is closed"  if $oversip_debug
        return false
      end
      if data
        log_system_debug "sending pong frame: payload_length=#{data.bytesize}"  if $oversip_debug
      else
        log_system_debug "sending pong frame: payload_length=0"  if $oversip_debug
      end

      frame = "".encode ::Encoding::BINARY

      # byte1 = OPCODE_TO_INT[:pong] | 0b10000000 => 138
      #
      # - FIN bit set.
      # - RSV1-3 bits not set.
      # - opcode = 10
      frame << 138

      length = ( data ? data.bytesize : 0 )
      frame << length

      if data
        if data.encoding == ::Encoding::BINARY
          frame << data
        else
          frame << data.force_encoding(::Encoding::BINARY)
        end
      end

      @connection.send_data frame
      true
    end


    def send_close_frame status=nil, reason=nil, in_reply_to_close=nil
      @keep_alive_timer.cancel  if @keep_alive_timer

      case @state
      when :ws_closed
        log_system_debug "cannot send close frame, WebSocket session is closed"  if $oversip_debug
        return false
      when :tcp_closed
        log_system_debug "cannot send close frame, TCP session is closed"  if $oversip_debug
        return false
      end

      unless in_reply_to_close
        log_system_debug "sending close frame: status=#{status.inspect}, reason=#{reason.inspect}"  if $oversip_debug
      else
        log_system_debug "sending reply close frame: status=#{status.inspect}, reason=#{reason.inspect}"  if $oversip_debug
      end

      @state = :ws_closed
      @buffer.clear

      frame = "".encode ::Encoding::BINARY

      # byte1 = OPCODE_TO_INT[:close] | 0b10000000 => 136
      #
      # - FIN bit set.
      # - RSV1-3 bits not set.
      # - opcode = 8
      frame << 136
      if status
        length = ( reason ? 2 + reason.bytesize : 2 )
      else
        length = 0
      end

      frame << length # since rsv4 is 0
      if status
        frame << [status].pack('n')
        if reason
          if reason.encoding == ::Encoding::BINARY
            frame << reason
          else
            frame << reason.force_encoding(::Encoding::BINARY)
          end
        end
      end

      @connection.ignore_incoming_data
      @connection.send_data frame

      unless in_reply_to_close
        # Let's some time for the client to send us a close frame (it will
        # be ignored anyway) before closing the TCP connection.
        ::EM.add_timer(0.2) do
          @connection.close_connection_after_writing
        end
      else
        @connection.close_connection_after_writing
      end
      true
    end


    def tcp_closed
      @keep_alive_timer.cancel  if @keep_alive_timer
      @state = :tcp_closed
      # Tell it to the WS application.
      @ws_app.tcp_closed rescue nil
    end

  end  # class WsFraming

end
