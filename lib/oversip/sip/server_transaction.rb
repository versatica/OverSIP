module OverSIP::SIP

  class ServerTransaction

    include ::OverSIP::Logger

    attr_reader :request
    attr_accessor :last_response, :core
    attr_reader :state

    def initialize request
      @request = request
      @request.server_transaction = self
      @transaction_id = request.via_branch_id
    end

    def retransmit_last_response
      @request.send_response @last_response  if @last_response
    end

  end  # class ServerTransaction


  class InviteServerTransaction < ServerTransaction

    def initialize request
      super
      @request.connection.class.invite_server_transactions[@transaction_id] = self

      @log_id = "IST #{@transaction_id}"
      # Can be :proceeding, :completed, :confirmed, :accepted or :terminated.
      @state = :proceeding

      # NOTE: This is a timer of INVITE client transactions, but we also need it here to avoid
      # that an INVITE server transaction never ends.
      start_timer_C2

      @request.reply 100
    end

    def start_timer_G
      @timer_G_interval = TIMER_G
      @timer_G = ::EM::PeriodicTimer.new(@timer_G_interval) do
        log_system_debug "timer G expires, retransmitting last response"  if $oversip_debug
        retransmit_last_response
        @timer_G_interval = @timer_G.interval = [2*@timer_G_interval, T2].min
      end
    end

    def start_timer_H
      @timer_H = ::EM::Timer.new(TIMER_H) do
        log_system_debug "timer H expires and no ACK received, transaction terminated"  if $oversip_debug
        terminate_transaction
        @timer_G.cancel  if @timer_G
      end
    end

    def start_timer_I
      ::EM.add_timer(TIMER_I_UDP) do
        log_system_debug "timer I expires, transaction terminated"  if $oversip_debug
        terminate_transaction
      end
    end

    # RFC 6026.
    def start_timer_L
      ::EM.add_timer(TIMER_L) do
        log_system_debug "timer L expires, transaction terminated"  if $oversip_debug
        terminate_transaction
      end
    end

    # Timer to delete the transaction if final response is never sent by the TU.
    def start_timer_C2
      @timer_C2 = ::EM::Timer.new(TIMER_C2) do
        log_system_debug "no final response within #{TIMER_C2} seconds, transaction terminated"  if $oversip_debug
        terminate_transaction
      end
    end

    # This method is called by SipReactor#check_transaction upon receipt of an ACK
    # matching an INVITE transaction (so it has been rejected with [3456]XX).
    def receive_ack
      case @state
      when :proceeding
        log_system_debug "ACK received during proceeding state, ignoring it"  if $oversip_debug
      when :completed
        log_system_debug "ACK received during completed state, now confirmed"  if $oversip_debug
        @state = :confirmed
        @timer_G.cancel  if @timer_G
        @timer_H.cancel
        if @request.transport == :udp
          start_timer_I
        else
          terminate_transaction
        end
      else
        log_system_debug "ACK received during #{@state} state, ignoring it"  if $oversip_debug
      end
    end

    # This method is called by SipReactor#check_transaction upon receipt of an CANCEL
    # matching an INVITE transaction.
    def receive_cancel cancel
      @core.receive_cancel(cancel)  if @core
    end

    # Terminate current transaction and delete from the list of transactions.
    def terminate_transaction
      @state = :terminated
      @request.connection.class.invite_server_transactions.delete(@transaction_id)
    end

    def receive_response status_code
      # Provisional response
      if status_code < 200
        case @state
        when :proceeding
          return true
        else
          log_system_notice "attempt to send a provisional response while in #{@state} state"
          return false
        end

      # 2XX final response.
      elsif status_code >= 200 and status_code < 300
        case @state
        when :proceeding
          @state = :accepted
          @timer_C2.cancel
          start_timer_L
          return true
        when :accepted
          return true
        else
          log_system_notice "attempt to send a final 2XX response while in #{@state} state"
          return false
        end

      # [3456]XX final response.
      else
        case @state
        when :proceeding
          @state = :completed
          @timer_C2.cancel
          start_timer_G if @request.transport == :udp
          start_timer_H
          return true
        else
          log_system_notice "attempt to send a final #{status_code} response while in #{@state} state"
          return false
        end
      end
    end

    def valid_response? status_code
      # Provisional response
      if status_code < 200
        case @state
        when :proceeding
          return true
        else
          return false
        end

      # 2XX final response.
      elsif status_code >= 200 and status_code < 300
        case @state
        when :proceeding
          return true
        when :accepted
          return true
        else
          return false
        end

        # [3456]XX final response.
      else
        case @state
        when :proceeding
          return true
        else
          return false
        end
      end
    end

  end  # class InviteServerTransaction


  class NonInviteServerTransaction < ServerTransaction

    def initialize request
      super
      @request.connection.class.non_invite_server_transactions[@transaction_id] = self

      @log_id = "NIST #{@transaction_id}"
      # Can be :trying, :proceeding, :completed or :terminated.
      @state = :trying

      start_timer_INT1
    end

    # RFC 4320 - Section 4.1.
    def start_timer_INT1
      @timer_INT1 = ::EM::Timer.new(INT1) do
        unless @last_response
          log_system_debug "no final response within #{INT1} seconds => 100"  if $oversip_debug
          @request.reply 100, "I'm alive"
        end
        start_timer_INT2
      end
    end

    # RFC 4320 - Section 4.2.
    def start_timer_INT2
      @timer_INT2 = ::EM::Timer.new(INT2) do
        log_system_debug "no final response within #{INT1+INT2} seconds, transaction terminated"  if $oversip_debug
        terminate_transaction
      end
    end

    def start_timer_J
      ::EM.add_timer(TIMER_J_UDP) do
        log_system_debug "timer J expires, transaction terminated"  if $oversip_debug
        terminate_transaction
      end
    end

    # Terminate current transaction and delete from the list of transactions.
    def terminate_transaction
      @state = :terminated
      @request.connection.class.non_invite_server_transactions.delete(@transaction_id)
    end

    def receive_response(status_code)
      # Provisional response
      if status_code < 200
        case @state
        when :trying
          @state = :proceeding
          return true
        when :proceeding
          return true
        when :completed, :terminated
          log_system_notice "attempt to send a provisional response while in #{@state} state"
          return false
        end

      # Final response.
      else
        case @state
        when :trying, :proceeding
          @timer_INT1.cancel
          @timer_INT2.cancel  if @timer_INT2
          @state = :completed
          if @request.transport == :udp
            start_timer_J
          else
            terminate_transaction
          end
          return true
        when :completed, :terminated
          log_system_notice "attempt to send a final response while in #{@state} state"
          return false
        end
      end
    end

    def valid_response? status_code
      # Provisional response
      if status_code < 200
        case @state
        when :trying
          return true
        when :proceeding
          return true
        when :completed, :terminated
          return false
        end

      # Final response.
      else
        case @state
        when :trying, :proceeding
          return true
        when :completed, :terminated
          return false
        end
      end
    end

  end  # class NonInviteServerTransaction

end