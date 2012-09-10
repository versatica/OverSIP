module OverSIP::WebSocket

  class WssServer < WsServer

    TLS_HANDSHAKE_MAX_TIME = 4


    def post_init
      @client_pems = []
      @client_last_pem = false

      start_tls({
        :verify_peer => true,
        :cert_chain_file => ::OverSIP.tls_public_cert,
        :private_key_file => ::OverSIP.tls_private_cert,
        :use_tls => false  # USE SSL instead of TLS. TODO: yes?
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
      log_system_debug ("TLS connection established from " << remote_desc)  if $oversip_debug

      # @connected in WssServer means "TLS connection" rather than
      # just "TCP connection".
      @connected = true
      @timer_tls_handshake.cancel  if @timer_tls_handshake

      if ::OverSIP::WebSocket.callback_on_client_tls_handshake
        # Set the state to :waiting_for_on_client_tls_handshake so data received after TLS handshake but before
        # user callback validation is just stored.
        @state = :waiting_for_on_client_tls_handshake

        # Run OverSIP::WebSocketEvents.on_client_tls_handshake.
        ::Fiber.new do
          begin
            log_system_debug "running OverSIP::SipWebSocketEvents.on_client_tls_handshake()..."  if $oversip_debug
            ::OverSIP::WebSocketEvents.on_client_tls_handshake self, @client_pems
            # If the user of the peer has not closed the connection then continue.
            unless @local_closed or error?
              @state = :init
              # Call process_received_data() to process possible data received in the meanwhile.
              process_received_data
            else
              log_system_debug "connection closed during OverSIP::SipWebSocketEvents.on_client_tls_handshake(), aborting"  if $oversip_debug
            end

          rescue ::Exception => e
            log_system_error "error calling OverSIP::WebSocketEvents.on_client_tls_handshake():"
            log_system_error e
            close_connection
          end
        end.resume
      end
    end


    def unbind cause=nil
      @timer_tls_handshake.cancel  if @timer_tls_handshake
      super
    end

  end
end
