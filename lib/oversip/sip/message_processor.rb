module OverSIP::SIP

  module MessageProcessor

    # Constants for efficiency.
    MSG_TYPE = {
      ::OverSIP::SIP::Request   => "SIP request",
      ::OverSIP::SIP::Response  => "SIP response",
      :outbound_keepalive       => "Outbound keepalive"
    }


    def valid_message? parser
      if header = parser.missing_core_header?
        log_system_notice "ignoring #{MSG_TYPE[@msg.class]} missing #{header} header"
        return false
      elsif header = parser.duplicated_core_header?
        log_system_notice "ignoring #{MSG_TYPE[@msg.class]} with duplicated #{header} header"
        return false
      end
      return true
    end
    private :valid_message?


    # Via ;received and ;rport stuff.
    def add_via_received_rport
      # - If ;rport is present ;received MUST also be set (RFC 3581).
      # - If not add ;received according to RFC 3261 rules.
      if @msg.via_rport?
        via_received = @msg.source_ip
        @msg.via_rport = @msg.source_port
      else
        via_received = (::OverSIP::Utils.compare_ips(@msg.via_sent_by_host, @msg.source_ip) ? nil : @msg.source_ip)
      end

      if via_received
        via_params = ";branch=" << @msg.via_branch  if @msg.via_branch
        via_params << ";received=" << via_received  if via_received
        via_params << ";rport=" << @msg.via_rport.to_s  if @msg.via_rport
        via_params << ";alias"  if @msg.via_alias?

        if @msg.via_params
          @msg.via_params.each { |k,v| via_params << ( v ? ";#{k}=#{v}" : ";#{k}" ) }
        end

        @msg.hdr_via[0] = "#{@msg.via_core_value}#{via_params}"
      end
    end
    private :add_via_received_rport


    # Reject the message in case it doesn't contain a Via branch compliant with RFC 3261
    def check_via_branch
      if @msg.via_branch_rfc3261
        @msg.via_branch_id = @msg.via_branch[7..-1]  # The branch without "z9hG4bK".
        return true
      end

      if @msg.is_a? Request
        unless @msg.sip_method == :ACK
          log_system_notice "request doesn't contain a RFC 3261 Via branch => 400"
          @msg.reply 400, "Via branch non RFC 3261 compliant"
        else
          log_system_notice "ACK doesn't contain a RFC 3261 Via branch, ignoring it"
        end
      else
        log_system_notice "response doesn't contain a RFC 3261 Via branch, ignoring it"
      end
      false
    end
    private :check_via_branch


    def process_request
      # Run the user provided OverSIP::SipEvents.on_request() callback (unless the request
      # it's a retransmission, a CANCEL or an ACK for a final non-2XX response).
      unless check_transaction
        # Create the antiloop identifier for this request.
        @msg.antiloop_id = ::OverSIP::SIP::Tags.create_antiloop_id(@msg)

        # Check loops.
        if @msg.antiloop_id == @msg.via_branch_id[-32..-1]
          @msg.reply 482, "Loop Detected"
          return
        end

        # Initialize some attributes for the request.
        @msg.tvars = {}
        @msg.cvars = @msg.connection.cvars

        # Run OverSIP::SipEvents.on_request within a fiber.
        ::Fiber.new do
          begin
            ::OverSIP::SipEvents.on_request @msg
          rescue ::Exception => e
            log_system_error "error calling OverSIP::SipEvents.on_request() => 500:"
            log_system_error e
            @msg.reply 500, "Internal Error", ["Content-Type: text/plain"], "#{e.class}: #{e.message}"
          end
        end.resume
      end
    end
    private :process_request


    # Process a received response.
    def process_response
      case @msg.sip_method
      when :INVITE
        ### TODO: Esto va a petar cuando tenga una clase que hereda de, p.ej, IPv4TcpServer que se llame xxxClient,
        # ya que en ella no existirá @invite_client_transactions. Tengo que hacer que su @invite_client_transactions
        # se rellene al de la clase padre al hacer el load de las clases.
        if client_transaction = @msg.connection.class.invite_client_transactions[@msg.via_branch_id]
          client_transaction.receive_response(@msg)
          return
        end
      when :ACK
      when :CANCEL
        if client_transaction = @msg.connection.class.invite_client_transactions[@msg.via_branch_id]
          client_transaction.receive_response_to_cancel(@msg)
          return
        end
      else
        if client_transaction = @msg.connection.class.non_invite_client_transactions[@msg.via_branch_id]
          client_transaction.receive_response(@msg)
          return
        end
      end
      log_system_debug "ignoring a response non matching a client transaction (#{@msg.sip_method} #{@msg.status_code})"  if $oversip_debug
    end
    private :process_response


    # Check transaction.
    def check_transaction
      case @msg.sip_method

      when :INVITE
        if server_transaction = @msg.connection.class.invite_server_transactions[@msg.via_branch_id]
          # If the retranmission arrives via a different connection (for TCP/TLS) then use
          # the new one.
          if @msg.connection == server_transaction.request.connection
            log_system_debug "INVITE retransmission received"  if $oversip_debug
          else
            log_system_debug "INVITE retransmission received via other connection, updating server transaction"  if $oversip_debug
            server_transaction.request.connection = @msg.connection
          end
          server_transaction.retransmit_last_response
          return true
        end

      when :ACK
        # If there is associated INVITE transaction (so it has been rejected)
        # pass ACK to the transaction.
        if server_transaction = @msg.connection.class.invite_server_transactions[@msg.via_branch_id]
          server_transaction.receive_ack
          return true
        # Absorb ACK for statelessly generated final responses by us.
        elsif OverSIP::SIP::Tags.check_totag_for_sl_reply(@msg.to_tag)
          log_system_debug "absorving ACK for a stateless final response"  if $oversip_debug
          return true
        else
          log_system_debug "passing ACK to the core"  if $oversip_debug
          return false
        end

      when :CANCEL
        if server_transaction = @msg.connection.class.invite_server_transactions[@msg.via_branch_id]
          case state = server_transaction.state
          when :proceeding
            log_system_debug "CANCEL matches an INVITE server transaction in proceeding state => 200"  if $oversip_debug
            @msg.reply 200, "Cancelled"
            server_transaction.receive_cancel(@msg)
          else
            log_system_debug "CANCEL matches an INVITE server transaction in #{state} state => 200"  if $oversip_debug
            @msg.reply 200, "Cancelled"
          end
        else
          log_system_debug "CANCEL does not match an INVITE server transaction => 481"  if $oversip_debug
          @msg.reply 481
        end
        return true

      else
        if server_transaction = @msg.connection.class.non_invite_server_transactions[@msg.via_branch_id]
          # If the retranmission arrives via a different connection (for TCP/TLS) then use
          # the new one.
          if @msg.connection == server_transaction.request.connection
            log_system_debug "#{server_transaction.request.sip_method} retransmission received"  if $oversip_debug
          else
            log_system_debug "#{server_transaction.request.sip_method} retransmission received via other connection, updating server transaction"  if $oversip_debug
            server_transaction.request.connection = @msg.connection
          end
          server_transaction.retransmit_last_response
          return true
        end

      end
    end  # def check_transaction
    private :check_transaction

  end

end