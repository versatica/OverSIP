module OverSIP::SIP

  class TlsClient < TcpClient

    TLS_HANDSHAKE_MAX_TIME = 4


    attr_writer :tls_validation


    def initialize ip, port
      super
      @pending_messages = []
    end


    def connection_completed
      @server_pems = []
      @server_last_pem = false

      start_tls({
        :verify_peer => @tls_validation,
        :cert_chain_file => ::OverSIP.tls_public_cert,
        :private_key_file => ::OverSIP.tls_private_cert
      })

      # If the remote server does never send us a TLS certificate
      # after the TCP connection we would leak by storing more and
      # more messages in @pending_messages array.
      @timer_tls_handshake = ::EM::Timer.new(TLS_HANDSHAKE_MAX_TIME) do
        unless @connected
          log_system_notice "TLS handshake not performed within #{TLS_HANDSHAKE_MAX_TIME} seconds, closing the connection"
          close_connection
        end
      end
    end


    # Called for every certificate provided by the peer.
    # This is just called in case @tls_validation is true.
    def ssl_verify_peer pem
      # TODO: Dirty workaround for bug https://github.com/eventmachine/eventmachine/issues/194.
      return true  if @server_last_pem == pem

      @server_last_pem = pem
      @server_pems << pem

      log_system_debug "received certificate num #{@server_pems.size} from server"  if $oversip_debug

      # Validation must be done in ssl_handshake_completed after receiving all the certs, so return true.
      return true
    end


    # This is called after all the calls to ssl_verify_peer().
    def ssl_handshake_completed
      log_system_info "TLS connection established to " << remote_desc

      # @connected in TlsClient means "TLS connection" rather than
      # just "TCP connection".
      @connected = true
      @timer_tls_handshake.cancel  if @timer_tls_handshake

      if @tls_validation
        validated, cert, tls_error, tls_error_string = ::OverSIP::TLS.validate @server_pems.pop, @server_pems
        if validated
          log_system_info "server provides a valid TLS certificate"
          sip_identities = ::OverSIP::TLS.get_sip_identities(cert)
          log_system_debug "SIP identities in peer cert: #{sip_identities.keys}"  if $oversip_debug
        else
          log_system_notice "server's TLS certificate validation failed (TLS error: #{tls_error.inspect}, description: #{tls_error_string.inspect})"
          @pending_client_transactions.each do |client_transaction|
            client_transaction.tls_validation_failed
          end
          @pending_client_transactions.clear
          @pending_messages.clear
          close_connection
          @state = :ignore
          return
        end
      end

      @pending_client_transactions.clear
      @pending_messages.each do |msg|
        send_data msg
      end
      @pending_messages.clear
    end

    def unbind cause=nil
      super
      @timer_tls_handshake.cancel  if @timer_tls_handshake
      @pending_messages.clear
    end

    # In TLS client, we must wait until ssl_handshake_completed is
    # completed before sending data. If not, data will be sent in
    # plain TCP.
    #   http://dev.sipdoc.net/issues/457
    def send_sip_msg msg, ip=nil, port=nil
      if self.error?
        log_system_notice "SIP message could not be sent, connection is closed"
        return false
      end

      if @connected
        send_data msg
      else
        log_system_debug "TLS handshake not completed yet, waiting before sending the message"  if $oversip_debug
        @pending_messages << msg
      end
      true
    end

  end

end
