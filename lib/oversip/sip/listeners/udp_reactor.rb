module OverSIP::SIP

  class UdpReactor < Reactor

    def receive_data data
      @buffer << data

      while (case @state
        when :init
          @parser.reset
          @parser_nbytes = 0
          @state = :message

        when :message
          parse_message

        when :finished
          if @msg.request?
            process_request
          else
            process_response
          end
          @state = :init
          false
        end)
      end  # while
    end

    def parse_message
      return false if @buffer.empty?

      buffer_str = @buffer.to_str

      # Quikly ignore single CRLF (widely used by SIP UDP clients as keep-alive.
      if buffer_str == CRLF
        @buffer.clear
        @state = :init
        return false
      end

      begin
        source_port, source_ip = ::Socket.unpack_sockaddr_in(get_peername)
      rescue => e
        log_system_crit "error obtaining remote IP/port (#{e.class}: #{e.message})"
        @buffer.clear
        @state = :init
        return false
      end

      case stun_res = ::OverSIP::Stun.parse_request(buffer_str, source_ip, source_port)
        # Not a STUN request so continue with SIP parsing.
        when nil
        # An invalid STUN request, log it and drop it.
        when false
          log_system_debug "invalid STUN message received (not a valid STUN Binding Request)"  if $oversip_debug
          @buffer.clear
          @state = :init
          return false
        # A valid STUN Binding Request so we get a response to be sent.
        when String
          log_system_debug "STUN Binding Request received, replying to it"  if $oversip_debug
          send_data stun_res
          @buffer.clear
          @state = :init
          return false
        end          

      # Parse the currently buffered data. If parsing fails @parser_nbytes gets nil value.
      unless @parser_nbytes = @parser.execute(buffer_str, @parser_nbytes)
        # The parsed data is invalid, however some data could be parsed so @parsed.parsed
        # can be:
        # - SIP::Request
        # - SIP::Response
        # - nil (the message is so wrong that cannot be neither a request or response).
        if wrong_message = @parser.parsed
          log_system_warn "parsing error for #{MSG_TYPE[wrong_message.class]}: \"#{@parser.error}\""
        else
          log_system_warn "parsing error: \"#{@parser.error}\""
        end

        @buffer.clear
        @state = :init
        return false
      end

      unless @parser.finished?
        # The parsing has not finished.
        # If UDP it's invalid as per RFC 3261 a UDP datagram MUST contain an entire
        # SIP request or response. Note we also allow double CRLF in UDP. If just a
        # single CRLF arrives ignore it and clear the buffer.
        # Maybe the parser has gone enought data to determine if the unfinished
        # message is a SIP request or response, log it if so.
        # If not, then @parser.parsed returns nil and nothing is logged.
        unfinished_msg = @parser.parsed
        log_system_warn "ignoring not finished #{MSG_TYPE[unfinished_msg.class]} via UDP" if
          unfinished_msg.is_a? ::OverSIP::SIP::Request or unfinished_msg.is_a? ::OverSIP::SIP::Response
        # Clear the buffer, set :init state and wait for new messages.
        @buffer.clear
        @state = :init
        return false
      end

      # At this point we've got a SIP::Request, SIP::Response or :outbound_keepalive symbol.
      @msg = @parser.parsed

      # Clear parsed data from the buffer.
      @buffer.read(@parser_nbytes)

      # Received data is a Outbound keealive (also allowed in UDP however). Reply single CRLF.
      if @msg == :outbound_keepalive
        log_system_debug "Outbound keepalive received, replying single CRLF"  if $oversip_debug
        # Reply a single CRLF over the same connection.
        send_data CRLF
        # If UDP there could be invalid data after double CRLF CRLF, just ignore it
        # and clear the buffer. Set :init state and return false so we leave receive_data()
        # method.
        @buffer.clear
        @state = :init
        return false
      end

      @parser.post_parsing

      # Here we have received the entire headers of a SIP request or response. Fill some
      # attributes.
      @msg.connection = self
      @msg.transport = :udp
      @msg.source_ip = source_ip
      @msg.source_port = source_port
      @msg.source_ip_type = self.class.ip_type

      unless valid_message?
        @buffer.clear
        @state = :init
        return false
      end

      add_via_received_rport if @msg.request?

      unless check_via_branch
        @buffer.clear
        @state = :init
        return false
      end

      # Examine Content-Length header.
      # There is Content-Length header.
      if cl = @msg.content_length and cl > 0
        # Body size is correct. Read it and clear the buffer.
        # Set :finished state and return true so message will be processed.
        if cl == @buffer.size
          @msg.body = @buffer.read.force_encoding(::Encoding::UTF_8)
          @buffer.clear
          @state = :finished
          return true
        # In UDP the remaining data after headers must be the entire body
        # and fill exactly Content-Length bytes. If not it's invalid. Reply
        # 400 and clear the buffer.
        else
          if @msg.request?
            unless @msg.sip_method == :ACK
              log_system_warn "request body size doesn't match Content-Length => 400"
              @msg.reply 400, "Body size doesn't match Content-Length"
            else
              log_system_warn "ACK body size doesn't match Content-Length, ignoring it"
            end
          else
            log_system_warn "response body size doesn't match Content-Length, ignoring it"
          end
          @buffer.clear
          @state = :init
          return false
        end
      # No Content-Length header or 0 value. However it could occur that the datagram
      # contains remaining unuseful data, in this case reply 400. If not
      # set :finished state and return true so message will be processed.
      else
        # Ensure there is no more data in the buffer. If it's ok set :finished
        # state and return true so message will be processed.
        if @buffer.size.zero?
          @state = :finished
          return true
        # Non valid remaining data in the UDP datagram. Reply 400.
        else
          if @msg.request?
            log_system_warn "request contains body but Content-Length is zero or not present => 400"
            @msg.reply 400, "request contains body but Content-Length is zero or not present"
          else
            log_system_warn "response contains body but Content-Length is zero or not present, ignoring it"
          end
          @buffer.clear
          @state = :init
          return false
        end
      end

    end  # parse_headers

    def send_sip_msg msg, ip, port
      send_datagram msg, ip, port
      true
    end


    def unbind cause=nil
      unless $!.is_a? ::SystemExit
        log_system_crit "UDP socket closed!!! cause: #{cause.inspect}"
      end
    end

  end  # class UdpReactor

end

