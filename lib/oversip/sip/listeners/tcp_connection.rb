module OverSIP::SIP

  class TcpConnection < Connection

    # Max size (bytes) of the buffered data when receiving message headers
    # (avoid DoS attacks).
    HEADERS_MAX_SIZE = 16384

    def remote_ip_type
      @remote_ip_type || self.class.ip_type
    end

    def remote_ip
      @remote_ip
    end

    def remote_port
      @remote_port
    end

    def receive_data data
      @state == :ignore and return
      @buffer << data

      while (case @state
        when :init
          @parser.reset
          @parser_nbytes = 0
          @state = :headers

        when :headers
          parse_headers
          # TODO: Add a timer for the case in which an attacker sends us slow headers that never end:
          #   http://ha.ckers.org/slowloris/.

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

    def parse_headers
      return false if @buffer.empty?

      # Parse the currently buffered data. If parsing fails @parser_nbytes gets nil value.
      unless @parser_nbytes = @parser.execute(@buffer.to_str, @parser_nbytes)
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

        close_connection_after_writing
        @state = :ignore
        return false
      end

      # Avoid flood attacks in TCP (very long headers).
      if @parser_nbytes > HEADERS_MAX_SIZE
        log_system_warn "DoS attack detected: headers size exceedes #{HEADERS_MAX_SIZE} bytes, closing connection with #{remote_desc}"
        close_connection
        # After closing client connection some data can still arrrive to "receive_data()"
        # (explained in EM documentation). By setting @state = :ignore we ensure such
        # remaining data is not processed.
        @state = :ignore
        return false
      end

      # If the parsing has not finished, it is correct in TCP so return false and wait for more data under :headers state.
      return false  unless @parser.finished?

      # At this point we've got a SIP::Request, SIP::Response or :outbound_keepalive symbol.
      @msg = @parser.parsed

      # Clear parsed data from the buffer.
      @buffer.read(@parser_nbytes)

      # Received data is a Outbound keealive.
      if @msg == :outbound_keepalive
        log_system_debug "Outbound keepalive received, replying single CRLF"  if $oversip_debug
        # Reply a single CRLF over the same connection.
        send_data CRLF
        # If TCP then go back to :init state so possible remaining data would be processed.
        @state = :init
        return true
      end

      @parser.post_parsing

      # Here we have received the entire headers of a SIP request or response. Fill some
      # attributes.
      @msg.connection = self
      @msg.transport = self.class.transport
      @msg.source_ip = @remote_ip
      @msg.source_port = @remote_port
      @msg.source_ip_type = @remote_ip_type || self.class.ip_type

      unless valid_message? @parser
        close_connection_after_writing
        @state = :ignore
        return false
      end

      add_via_received_rport if @msg.request?

      unless check_via_branch
        close_connection_after_writing
        @state = :ignore
        return false
      end

      # Examine Content-Length header.
      # In SIP over TCP Content-Length header is mandatory.
      if (@body_length = @msg.content_length)
        # There is body (or should be).
        if @body_length > 0
          @state = :body
          # Return true to continue in get_body() method.
          return true
        # No body.
        else
          # Set :finished state and return true to process the parsed message.
          @state = :finished
          return true
        end
      # No Content-Length, invalid message!
      else
        # Log it and reply a 400 Bad Request (if it's a request).
        # Close the connection, set :ignore state and return false to leave
        # receive_data().
        if @msg.request?
          unless @msg.sip_method == :ACK
            log_system_warn "request body size doesn't match Content-Length => 400"
            @msg.reply 400, "Body size doesn't match Content-Length"
          else
            log_system_warn "ACK body size doesn't match Content-Length, ignoring it"
          end
        else
          log_system_warn "response has not Content-Length header, ignoring it"
        end
        close_connection_after_writing
        @state = :ignore
        return false
      end
    end  # parse_headers

    def get_body
      # Return false until the buffer gets all the body.
      return false if @buffer.size < @body_length

      ### TODO: Creo que es mejor forzarlo a BINARY y no a UTF-8. Aunque IOBuffer ya lo saca siempre en BINARY.
      # ¿Por qué lo forcé a UTF-8?
      # RESPUESTA: Si no lo hago y resulta que el body no es UTF-8 válido, al añadir el body a los headers (que
      # se generan como un string en UTF-8 (aunque contengan símbolos no UTF-8) fallaría. O todo UTF-8 (aunque
      # tenga símbolos inválidos) o todo BINARY.
      @msg.body = @buffer.read(@body_length).force_encoding(::Encoding::UTF_8)
      @state = :finished
      return true
    end


    # Parameters ip and port are just included because they are needed in UDP, so the API remains equal.
    def send_sip_msg msg, ip=nil, port=nil
      if self.error?
        log_system_notice "SIP message could not be sent, connection is closed"
        return false
      end
      send_data msg
      true
    end

  end

end

