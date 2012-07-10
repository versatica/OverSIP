module OverSIP::WebSocket

  class TlsServer < TcpServer

    TLS_HANDSHAKE_MAX_TIME = 8


    def post_init
      @client_pems = []
      @client_last_pem = false

      start_tls({
        :verify_peer => true,
        :cert_chain_file => ::OverSIP.tls_public_cert,
        :private_key_file => ::OverSIP.tls_private_cert
      })

      # If the remote client does never send us a TLS certificate
      # after the TCP connection we would leak by storing more and
      # more messages in @pending_messages array.
      @timer_tls_handshake = ::EM::Timer.new(TLS_HANDSHAKE_MAX_TIME) do
        unless @connected
          log_system_notice "TLS handshake not performed within #{TLS_HANDSHAKE_MAX_TIME} seconds, closing the connection"
          close_connection
        end
      end
    end


    def ssl_verify_peer pem
      # TODO: Dirty workaround for bug https://github.com/eventmachine/eventmachine/issues/194.
      return true  if @client_last_pem == pem

      @client_last_pem = pem
      @client_pems << pem

      log_system_debug "received certificate num #{@client_pems.size} from client"  if $oversip_debug

      # Validation must be done in ssl_handshake_completed after receiving all the certs, so return true.
      return true
    end


    def ssl_handshake_completed
      log_system_info "TLS connection established from " << remote_desc

      # TODO: What to do it falidation fails? always do validation?

      validated, cert, tls_error, tls_error_string = ::OverSIP::TLS.validate @client_pems.pop, @client_pems
      if validated
        log_system_info "client provides a valid TLS certificate"
      else
        log_system_notice "client's TLS certificate validation failed (TLS error: #{tls_error.inspect}, description: #{tls_error_string.inspect})"
      end

      # @connected in TlsServer means "TLS connection" rather than
      # just "TCP connection".
      @connected = true
      @timer_tls_handshake.cancel  if @timer_tls_handshake
    end


    def unbind cause=nil
      super
      @timer_tls_handshake.cancel  if @timer_tls_handshake
    end

  end
end
