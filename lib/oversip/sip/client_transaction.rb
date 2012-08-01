module OverSIP::SIP

  class ClientTransaction

    include ::OverSIP::Logger

    def self.get_class request
      case request.sip_method
      when :INVITE  ; ::OverSIP::SIP::InviteClientTransaction
      when :ACK     ; ::OverSIP::SIP::Ack2xxForwarder
      else          ; ::OverSIP::SIP::NonInviteClientTransaction
      end
    end

    attr_reader :core, :request, :state, :connection

    # In case _transport_ is a String, it's an Outbound flow token.
    def initialize core, request, transaction_conf, transport, ip=nil, ip_type=nil, port=nil
      @core = core
      @request = request
      @transaction_conf = transaction_conf || {}
      @transaction_id = ::SecureRandom.hex(4) << @request.antiloop_id

      # A client transaction for using an existing Outbound connection.
      if transport.is_a? String
        @connection, @ip, @port = ::OverSIP::SIP::TransportManager.get_outbound_connection transport
        if @connection
          @server_klass = @connection.class
          @transport = @server_klass.transport
        end

      # A client transaction based on procedures of RFC 3263. The connection could exist (so reuse it)
      # or not (so try to create it).
      else
        @transport = transport
        @ip = ip
        @ip_type = ip_type
        @port = port

        @server_klass = case @transport
          when :udp
            case @ip_type
              when :ipv4 ; ::OverSIP::SIP::IPv4UdpServer
              when :ipv6 ; ::OverSIP::SIP::IPv6UdpServer
            end
          when :tcp
            case @ip_type
              when :ipv4 ; ::OverSIP::SIP::IPv4TcpServer
              when :ipv6 ; ::OverSIP::SIP::IPv6TcpServer
            end
          when :tls
            case @ip_type
              when :ipv4 ; ::OverSIP::SIP::IPv4TlsServer
              when :ipv6 ; ::OverSIP::SIP::IPv6TlsServer
            end
          end

        @connection = ::OverSIP::SIP::TransportManager.get_connection @server_klass, @ip, @port, self, transaction_conf[:tls_validation]
      end

      # Ensure the request has Content-Length. Add it otherwise.
      if @request.body
        @request.headers["Content-Length"] = [ @request.body.bytesize.to_s ]
      else
        @request.headers["Content-Length"] = HDR_ARRAY_CONTENT_LENGTH_0
      end

    end # def initialize

  end  # class ClientTransaction


  class InviteClientTransaction < ClientTransaction

    def initialize core, request, transaction_conf, transport, ip=nil, ip_type=nil, port=nil
      super
      @log_id = "ICT #{@transaction_id}"

      # Can be :calling, :proceeding, :completed, :accepted or :terminated.
      @state = :calling
    end

    def send_request
      @client_transactions = @server_klass.invite_client_transactions
      # Store the new client transaction.
      @client_transactions[@transaction_id] = self

      @top_via = "#{@server_klass.via_core};branch=z9hG4bK#{@transaction_id};rport"
      @request.insert_header "Via", @top_via

      case @request.in_rr
      # Add a second Record-Route just in case there is transport change.
      when :rr
        unless @request.connection.is_a?(@server_klass)
          @out_rr = :rr
          @request.insert_header "Record-Route", @server_klass.record_route
        end
      # When there is outgoing Outbound always add a second Record-Route header.
      when :outgoing_outbound_rr
        @out_rr = :rr
        @request.insert_header "Record-Route", @server_klass.record_route
      # When there is incoming Outbound always add a second Record-Route header containing the flow token.
      when :incoming_outbound_rr
        @out_rr = :rr
        @request.insert_header "Record-Route", "<sip:" << @request.route_outbound_flow_token << @server_klass.outbound_record_route_fragment
      # When there is both incoming and outgoing Outbound always add a second Record-Route header containing the flow token.
      when :both_outbound_rr
        @out_rr = :rr
        @request.insert_header "Record-Route", "<sip:" << @request.route_outbound_flow_token << @server_klass.outbound_record_route_fragment
      end

      @request_leg_b = @request.to_s

      # NOTE: This cannot return false as the connection has been retrieved from the corresponding hash,
      # and when a connection is terminated its value is automatically deleted from such hash.
      @connection.send_sip_msg @request_leg_b, @ip, @port

      @request.delete_header_top "Via"
      if @out_rr == :rr
        @request.delete_header_top "Record-Route"
      end

      start_timer_A  if @transport == :udp
      start_timer_B
      start_timer_C

      true
    end

    def start_timer_A
      @timer_A_interval = TIMER_A
      @timer_A = ::EM::PeriodicTimer.new(@timer_A_interval) do
        log_system_debug "timer A expires, retransmitting request"  if $oversip_debug
        retransmit_request
        @timer_A_interval = @timer_A.interval = 2*@timer_A_interval
      end
    end

    def start_timer_B
      @timer_B = ::EM::Timer.new(@transaction_conf[:timer_B] || TIMER_B) do
        log_system_debug "timer B expires, transaction timeout"  if $oversip_debug
        @timer_A.cancel  if @timer_A
        @timer_C.cancel
        terminate_transaction
        @core.client_timeout
      end
    end

    def start_timer_C
      @timer_C = ::EM::Timer.new(@transaction_conf[:timer_C] || TIMER_C) do
        log_system_debug "timer C expires, transaction timeout"  if $oversip_debug
        @timer_A.cancel  if @timer_A
        @timer_B.cancel
        do_cancel
        @core.invite_timeout
      end
    end

    def start_timer_D
      ::EM.add_timer(TIMER_D_UDP) do
        log_system_debug "timer D expires, transaction terminated"  if $oversip_debug
        terminate_transaction
      end
    end

    def start_timer_M
      ::EM.add_timer(TIMER_M) do
        log_system_debug "timer M expires, transaction terminated"  if $oversip_debug
        terminate_transaction
      end
    end

    # Terminate current transaction and delete from the list of transactions.
    def terminate_transaction
      @state = :terminated
      @client_transactions.delete(@transaction_id)
    end

    def retransmit_request
      @connection.send_sip_msg @request_leg_b, @ip, @port
    end

    def receive_response response
      # Set the request attribute to the response so we can access the related outgoing request.
      response.request = @request

      # Set server transaction variables to the response.
      response.tvars = @request.tvars

      # Set original request's connection variables to the response.
      response.cvars = @request.cvars

      # Provisional response
      if response.status_code < 200
        case @state
        when :calling
          @state = :proceeding
          @timer_A.cancel  if @timer_A
          @timer_B.cancel
          @core.receive_response(response) unless response.status_code == 100
          # RFC 3261 - 9.1 states that a CANCEL must be sent after receiving a 1XX response.
          send_cancel if @cancel
          return true
        when :proceeding
          @core.receive_response(response) unless response.status_code == 100
          return true
        else
          log_system_notice "received a provisional response #{response.status_code} while in #{@state} state"
          return false
        end

      # [3456]XX final response.
      elsif response.status_code >= 300
        case @state
        when :calling, :proceeding
          @state = :completed
          @timer_A.cancel  if @timer_A
          @timer_B.cancel
          @timer_C.cancel
          if @transport == :udp
            start_timer_D
          else
            terminate_transaction
          end
          send_ack(response)
          @core.receive_response(response)
          return true
        when :completed
          send_ack(response)
          return false
        when :accepted
          log_system_notice "received a [3456]XX response while in accepted state, ignoring it"
          return false
        end

      # 2XX final response.
      else
        case @state
        when :calling, :proceeding
          @state = :accepted
          @timer_A.cancel  if @timer_A
          @timer_B.cancel
          @timer_C.cancel
          start_timer_M
          @core.receive_response(response)
          return true
        when :accepted
          @core.receive_response(response)
          return true
        when :completed
          ### NOTE: It could be accepted and bypassed to the UAC, but makes no sense.
          log_system_notice "received 2XX response while in completed state, ignoring it"
          return false
        end

      end
    end

    def connection_failed
      # This avoid the case in which the TCP connection timeout raises after the transaction timeout.
      # Neither we react if the transaction has been canceled and the CANCEL cannot be sent due to
      # TCP disconnection.
      return unless @state == :calling or not @cancel

      @timer_A.cancel  if @timer_A
      @timer_B.cancel
      @timer_C.cancel
      terminate_transaction

      @core.connection_failed
    end

    def tls_validation_failed
      return unless @state == :calling or not @cancel

      @timer_A.cancel  if @timer_A
      @timer_B.cancel
      @timer_C.cancel
      terminate_transaction

      @core.tls_validation_failed
    end

    def send_ack response
      unless @ack
        @ack = "ACK #{@request.ruri} SIP/2.0\r\n"
        @ack << "Via: #{@top_via}\r\n"

        @request.hdr_route.each do |route|
          @ack << "Route: " << route << "\r\n"
        end  if @request.hdr_route

        @ack << "From: " << @request.hdr_from << "\r\n"
        @ack << "To: " << @request.hdr_to
        unless @request.to_tag
          @ack << ";tag=#{response.to_tag}"  if response.to_tag
        end
        @ack << "\r\n"

        @ack << "Call-ID: " << @request.call_id << "\r\n"
        @ack << "CSeq: " << @request.cseq.to_s << " ACK\r\n"
        @ack << "Content-Length: 0\r\n"
        @ack << HDR_USER_AGENT << "\r\n"
        @ack << "\r\n"
      end

      log_system_debug "sending ACK for [3456]XX response"  if $oversip_debug
      @connection.send_sip_msg @ack, @ip, @port
    end

    # It receives the received CANCEL request as parameter so it can check the existence of
    # Reason header and act according (RFC 3326).
    # This method is also called (without argument) when Timer C expires (INVITE).
    def do_cancel cancel=nil
      return if @cancel

      @cancel = "CANCEL #{@request.ruri} SIP/2.0\r\n"
      @cancel << "Via: #{@top_via}\r\n"

      @request.hdr_route.each do |route|
        @cancel << "Route: " << route << "\r\n"
      end  if @request.hdr_route

      # RFC 3326. Copy Reason headers if present in the received CANCEL.
      cancel.header_all("Reason").each do |reason|
        @cancel << "Reason: " << reason << "\r\n"
      end  if cancel

      @cancel << "From: " << @request.hdr_from << "\r\n"
      @cancel << "To: " << @request.hdr_to << "\r\n"
      @cancel << "Call-ID: " << @request.call_id << "\r\n"
      @cancel << "CSeq: " << @request.cseq.to_s << " CANCEL\r\n"
      @cancel << "Content-Length: 0\r\n"
      @cancel << HDR_USER_AGENT << "\r\n"
      @cancel << "\r\n"

      # Just send the ACK inmediately if the branch has replied a 1XX response.
      send_cancel  if @state == :proceeding
    end

    def send_cancel
      log_system_debug "sending CANCEL"  if $oversip_debug

      @connection.send_sip_msg @cancel, @ip, @port

      start_timer_E_cancel  if @transport == :udp
      start_timer_F_cancel
    end

    def start_timer_E_cancel
      @timer_E_cancel_interval = TIMER_E
      @timer_E_cancel = ::EM::PeriodicTimer.new(@timer_E_cancel_interval) do
        log_system_debug "timer E expires, retransmitting CANCEL"  if $oversip_debug
        retransmit_cancel
        @timer_E_cancel_interval = @timer_E_cancel.interval = [2*@timer_E_cancel_interval, T2].min
      end
    end

    def start_timer_F_cancel
      @timer_F_cancel = ::EM::Timer.new(@transaction_conf[:timer_F] || TIMER_F) do
        unless @state == :terminated
          log_system_debug "timer F expires, CANCEL timeout, transaction terminated"  if $oversip_debug
          @timer_E_cancel.cancel  if @timer_E_cancel
          terminate_transaction
        end
      end
    end

    def retransmit_cancel
      @connection.send_sip_msg @cancel, @ip, @port
    end

    def receive_response_to_cancel(response)
      unless @state == :terminated
        log_system_debug "our CANCEL got a #{response.status_code} response, transaction terminated"  if $oversip_debug

        @timer_E_cancel.cancel  if @timer_E_cancel
        @timer_F_cancel.cancel
        # We MUST ensure that we end the client transaction, so after sending a CANCEL and get a response
        # for it, ensure the transaction is terminated after a while.
        ::EM.add_timer(4) { terminate_transaction }
      end
    end

  end  # class InviteClientTransaction


  class NonInviteClientTransaction < ClientTransaction

    def initialize core, request, transaction_conf, transport, ip=nil, ip_type=nil, port=nil
      super
      @log_id = "NICT #{@transaction_id}"

      # Can be :trying, :proceeding, :completed or :terminated.
      @state = :trying
    end

    def send_request
      @client_transactions = @server_klass.non_invite_client_transactions
      # Store the new client transaction.
      @client_transactions[@transaction_id] = self

      @top_via = "#{@server_klass.via_core};branch=z9hG4bK#{@transaction_id};rport"
      @request.insert_header "Via", @top_via

      case @request.in_rr
      # Add a second Record-Route just in case there is transport change.
      when :rr
        unless @request.connection.is_a?(@server_klass)
          @out_rr = :rr
          @request.insert_header "Record-Route", @server_klass.record_route
        end
      # When there is outgoing Outbound always add a second Record-Route header.
      when :outgoing_outbound_rr
        @out_rr = :rr
        @request.insert_header "Record-Route", @server_klass.record_route
      # When there is incoming Outbound always add a second Record-Route header containing the flow token.
      when :incoming_outbound_rr
        @out_rr = :rr
        @request.insert_header "Record-Route", "<sip:" << @request.route_outbound_flow_token << @server_klass.outbound_record_route_fragment
      # When there is both outgoing/incoming Outbound always add a second Record-Route header containing the flow token.
      when :both_outbound_rr
        @out_rr = :rr
        @request.insert_header "Record-Route", "<sip:" << @request.route_outbound_flow_token << @server_klass.outbound_record_route_fragment
      # Add a second Path just in case there is transport change.
      when :path
        unless @request.connection.is_a?(@server_klass)
          @out_rr = :path
          @request.insert_header "Path", @server_klass.record_route
        end
      # When there is outgoing Outbound always add a second Path header.
      when :outgoing_outbound_path
        @out_rr = :path
        @request.insert_header "Path", @server_klass.record_route
      # When there is incoming Outbound always add a second Path header containing the flow token.
      when :incoming_outbound_path
        @out_rr = :path
        @request.insert_header "Path", "<sip:" << @request.route_outbound_flow_token << @server_klass.outbound_path_fragment
      # When there is both outgoing/incoming Outbound always add a second Path header containing the flow token.
      when :both_outbound_path
        @out_rr = :rr
        @request.insert_header "Path", "<sip:" << @request.route_outbound_flow_token << @server_klass.outbound_path_fragment
      end

      @request_leg_b = @request.to_s

      @connection.send_sip_msg @request_leg_b, @ip, @port

      @request.delete_header_top "Via"
      case @out_rr
      when :rr
        @request.delete_header_top "Record-Route"
      when :path
        @request.delete_header_top "Path"
      end

      start_timer_E  if @transport == :udp
      start_timer_F

      true
    end

    def start_timer_E
      @timer_E_interval = TIMER_E
      @timer_E = ::EM::PeriodicTimer.new(@timer_E_interval) do
        log_system_debug "timer E expires, retransmitting request"  if $oversip_debug
        retransmit_request
        if @state == :trying
          @timer_E_interval = @timer_E.interval = [2*@timer_E_interval, T2].min
        else
          @timer_E_interval = @timer_E.interval = T2
        end
      end
    end

    def start_timer_F
      @timer_F = ::EM::Timer.new(@transaction_conf[:timer_F] || TIMER_F) do
        log_system_debug "timer F expires, transaction timeout"  if $oversip_debug
        @timer_E.cancel  if @timer_E
        terminate_transaction
        @core.client_timeout
      end
    end

    def start_timer_K
      ::EM.add_timer(TIMER_K_UDP) do
        log_system_debug "timer K expires, transaction terminated"  if $oversip_debug
        terminate_transaction
      end
    end

    # Terminate current transaction and delete from the list of transactions.
    def terminate_transaction
      @state = :terminated
      @client_transactions.delete(@transaction_id)
    end

    def retransmit_request
      @connection.send_sip_msg @request_leg_b, @ip, @port
    end

    def receive_response response
      # Set the request attribute to the response so we can access the related outgoing request.
      response.request = @request

      # Set server transaction variables to the response.
      response.tvars = @request.tvars

      # Set original request's connection variables to the response.
      response.cvars = @request.cvars

      # Provisional response
      if response.status_code < 200
        case @state
        when :trying
          @state = :proceeding
          @core.receive_response(response) unless response.status_code == 100
          return true
        when :proceeding
          @core.receive_response(response) unless response.status_code == 100
          return true
        else
          log_system_notice "received a provisional response #{response.status_code} while in #{@state} state"
          return false
        end

      # [23456]XX final response.
      elsif response.status_code >= 200
        case @state
        when :trying, :proceeding
          @state = :completed
          @timer_F.cancel
          @timer_E.cancel  if @timer_E
          if @transport == :udp
            start_timer_K
          else
            terminate_transaction
          end
          @core.receive_response(response)
          return true
        else
          log_system_notice "received a final response #{response.status_code} while in #{@state} state"
          return false
        end

      end
    end

    def connection_failed
      @timer_F.cancel
      @timer_E.cancel  if @timer_E
      terminate_transaction

      @core.connection_failed
    end

    def tls_validation_failed
      @timer_F.cancel
      @timer_E.cancel  if @timer_E
      terminate_transaction

      @core.tls_validation_failed
    end

  end  # class NonInviteClientTransaction


  class Ack2xxForwarder < ClientTransaction

    def initialize core, request, transaction_conf, transport, ip=nil, ip_type=nil, port=nil
      super
      @log_id = "ICT #{@transaction_id}"
    end

    def send_request
      @request.insert_header "Via", "#{@server_klass.via_core};branch=z9hG4bK#{@transaction_id}"

      @connection.send_sip_msg @request.to_s, @ip, @port

      true
    end

    def connection_failed
      # Do nothing.
    end

    def tls_validation_failed
      # Do nothing.
    end

  end  # class Ack2xxForwarder

end