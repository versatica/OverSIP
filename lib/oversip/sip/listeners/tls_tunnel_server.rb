module OverSIP::SIP

  class TlsTunnelServer < TlsTunnelReactor

    attr_reader :outbound_flow_token

    def post_connection
      begin
        # Temporal @remote_ip and @remote_port until the HAProxy protocol line is parsed.
        @remote_port, @remote_ip = ::Socket.unpack_sockaddr_in(get_peername)
      rescue => e
        log_system_error "error obtaining remote IP/port (#{e.class}: #{e.message}), closing connection"
        close_connection
        @state = :ignore
        return
      end

      log_system_debug ("connection from the TLS tunnel " << remote_desc)  if $oversip_debug

      # Create an Outbound (RFC 5626) flow token for this connection.
      @outbound_flow_token = ::OverSIP::SIP::TransportManager.add_outbound_connection self

      # Initialize @cvars.
      @cvars = {}
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
      self.class.connections.delete @connection_id  if @connection_id

      # Remove the Outbound token flow.
      ::OverSIP::SIP::TransportManager.delete_outbound_connection @outbound_flow_token

      @local_closed = true  if cause == ::Errno::ETIMEDOUT

      if $oversip_debug
        log_msg = "connection from the TLS tunnel #{remote_desc} "
        log_msg << ( @local_closed ? "locally closed" : "remotely closed" )
        log_msg << " (cause: #{cause.inspect})"  if cause
        log_system_debug log_msg
      end unless $!.is_a? ::SystemExit
    end

  end

end

