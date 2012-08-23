module OverSIP::SIP

  module TransportManager

    extend ::OverSIP::Logger

    @log_id = "TransportManager"
    @outbound_connections = {}


    # Get an existing connection or create a new one (TCP/TLS).
    # For UDP it always return the single UDP reactor instance.
    # client_transaction is passed when creating a new clien transaction. In case the
    # outgoing connection is a TCP/TLS client connection and it's not connected yet,
    # the client transaction is stored in the @pending_client_transactions of the client
    # connection.
    # This method always returns a connection object, never nil or false.
    def self.get_connection klass, ip, port, client_transaction=nil, callback_on_server_tls_handshake=false
      # A normal connection (so we arrive here after RFC 3263 procedures).
      case klass.transport

      # In UDP there is a single connection (the UDP server unique instance).
      when :udp
        conn = klass.connections

      # In TCP/TLS first check if there is an existing connection to the given destination.
      # If not create a new one.
      when :tcp
        case klass.ip_type
          when :ipv4
            conn = klass.connections["#{ip}_#{port}"] || ::EM.oversip_connect_tcp_server(::OverSIP::SIP.local_ipv4, ip, port, ::OverSIP::SIP::IPv4TcpClient, ip, port)

            if conn.is_a? ::OverSIP::SIP::IPv4TcpClient and not conn.connected
              conn.pending_client_transactions << client_transaction
            end
          when :ipv6
            conn = klass.connections["#{::OverSIP::Utils.normalize_ipv6 ip}_#{port}"] || ::EM.oversip_connect_tcp_server(::OverSIP::SIP.local_ipv6, ip, port, ::OverSIP::SIP::IPv6TcpClient, ip, port)

            if conn.is_a? ::OverSIP::SIP::IPv6TcpClient and not conn.connected
              conn.pending_client_transactions << client_transaction
            end
          end

      when :tls
        case klass.ip_type
          when :ipv4
            conn = klass.connections["#{ip}_#{port}"] || ::EM.oversip_connect_tcp_server(::OverSIP::SIP.local_ipv4, ip, port, ::OverSIP::SIP::IPv4TlsClient, ip, port)

            if conn.is_a? ::OverSIP::SIP::IPv4TlsClient and not conn.connected
              conn.callback_on_server_tls_handshake = callback_on_server_tls_handshake
              conn.pending_client_transactions << client_transaction
            end
          when :ipv6
            conn = klass.connections["#{::OverSIP::Utils.normalize_ipv6 ip}_#{port}"] || ::EM.oversip_connect_tcp_server(::OverSIP::SIP.local_ipv6, ip, port, ::OverSIP::SIP::IPv6TlsClient, ip, port)

            if conn.is_a? ::OverSIP::SIP::IPv6TlsClient and not conn.connected
              conn.callback_on_server_tls_handshake = callback_on_server_tls_handshake
              conn.pending_client_transactions << client_transaction
            end
          end
      end

      # NOTE: Should never happen.
      unless conn
        log_system_error "no connection (nil) retrieved from TransportManager.get_connection(), FIXME, it should never occur!!!"
        raise "no connection (nil) retrieved from TransportManager.get_connection(), FIXME, it should never occur!!!"
      end
      conn
    end


    def self.add_connection server, server_class, ip_type, ip, port
      connection_id = case ip_type
        when :ipv4
          "#{ip}_#{port}"
        when :ipv6
          "#{::OverSIP::Utils.normalize_ipv6 ip}_#{port}"
        end

      server_class.connections[connection_id] = server

      # Return the connection_id.
      connection_id
    end


    # Return a SIP server instance. It could return nil (if the requested connection no longer
    # exists) or false (if it's a tampered flow token).
    def self.get_outbound_connection flow_token
      # If the token flow has been generated for UDP it is "_" followed by the Base64
      # encoded representation of "IP_port", so getbyte(0) would return 95.
      if flow_token.getbyte(0) == 95
        # NOTE: Doing Base64.decode64 automatically removes the leading "_".
        # NOTE: Previously when the Outbound flow token was generated, "=" was replaced with "-" so it becomes
        # valid for a SIP URI param (in case of using Contact mangling if the registrar does not support Path).
        ip_type, ip, port = ::OverSIP::Utils.parse_outbound_udp_flow_token(::Base64.decode64 flow_token.gsub(/-/,"="))

        case ip_type
          when :ipv4
            return [ ::OverSIP::SIP::IPv4UdpServer.connections, ip, port ]
          when :ipv6
            return [ ::OverSIP::SIP::IPv6UdpServer.connections, ip, port ]
          else
            log_system_notice "udp flow token does not contain valid IP and port encoded value"
            return false
          end

      # It not, the flow token has been generated for a TCP/TLS/WS/WSS connection so let's lookup
      # it into the Outbound connection collection and return nil for IP and port.
      else
        @outbound_connections[flow_token]
      end
    end


    def self.add_outbound_connection connection
      outbound_flow_token = ::SecureRandom.hex(5)
      @outbound_connections[outbound_flow_token] = connection
      outbound_flow_token
    end


    def self.delete_outbound_connection outbound_flow_token
      @outbound_connections.delete outbound_flow_token
    end

  end  # module TransportManager

end
