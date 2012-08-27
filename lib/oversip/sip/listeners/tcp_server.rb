module OverSIP::SIP

  class TcpServer < TcpConnection

    attr_reader :outbound_flow_token

    def post_connection
      begin
        @remote_port, @remote_ip = ::Socket.unpack_sockaddr_in(get_peername)
      rescue => e
        log_system_error "error obtaining remote IP/port (#{e.class}: #{e.message}), closing connection"
        close_connection
        @state = :ignore
        return
      end

      @connection_id = ::OverSIP::SIP::TransportManager.add_connection self, self.class, self.class.ip_type, @remote_ip, @remote_port

      # Create an Outbound (RFC 5626) flow token for this connection.
      @outbound_flow_token = ::OverSIP::SIP::TransportManager.add_outbound_connection self

      ### Testing TCP keepalive.
      # https://github.com/bklang/eventmachine/commit/74c65a56c733bc1b6f092e32a9f0d722501ade46
      # http://tldp.org/HOWTO/html_single/TCP-Keepalive-HOWTO/
      if ::OverSIP::SIP.tcp_keepalive_interval
        set_sock_opt Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, true
        set_sock_opt Socket::SOL_TCP, Socket::TCP_KEEPIDLE, ::OverSIP::SIP.tcp_keepalive_interval  # First TCP ping.
        set_sock_opt Socket::SOL_TCP, Socket::TCP_KEEPINTVL, ::OverSIP::SIP.tcp_keepalive_interval  # Interval between TCP pings.
      end

      log_system_info "connection opened from " << remote_desc
    end

    def remote_desc force=nil
      if force
        @remote_desc = case @remote_ip_type
          when :ipv4  ; "#{@remote_ip}:#{@remote_port.to_s}"
          when :ipv6  ; "[#{@remote_ip}]:#{@remote_port.to_s}"
          end
      else
        @remote_desc ||= case self.class.ip_type
          when :ipv4  ; "#{@remote_ip}:#{@remote_port.to_s}"
          when :ipv6  ; "[#{@remote_ip}]:#{@remote_port.to_s}"
          end
      end
    end


    def unbind cause=nil
      @state = :ignore

      # Remove the connection.
      self.class.connections.delete @connection_id

      # Remove the Outbound token flow.
      ::OverSIP::SIP::TransportManager.delete_outbound_connection @outbound_flow_token

      @local_closed = true  if cause == ::Errno::ETIMEDOUT

      if $oversip_debug
        log_msg = "connection from #{remote_desc} "
        log_msg << ( @local_closed ? "locally closed" : "remotely closed" )
        log_msg << " (cause: #{cause.inspect})"  if cause
        log_system_debug log_msg
      end unless $!
    end

  end

end

