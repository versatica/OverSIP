module OverSIP::SIP

  module Launcher

    extend ::OverSIP::Logger

    IP_TYPE = {
      :ipv4 => "IPv4",
      :ipv6 => "IPv6"
    }


    def self.log_id
      @log_id ||= "SIP launcher"
    end


    def self.run enabled, ip_type, ip, port, transport, virtual_ip=nil, virtual_port=nil
      uri_ip = case ip_type
        when :ipv4 ; ip
        when :ipv6 ; "[#{ip}]"
        end

      if virtual_ip
        uri_virtual_ip = case ip_type
          when :ipv4 ; virtual_ip
          when :ipv6 ; "[#{virtual_ip}]"
          end
      end

      klass = case transport
        when :udp
          case ip_type
            when :ipv4 ; OverSIP::SIP::IPv4UdpServer
            when :ipv6 ; OverSIP::SIP::IPv6UdpServer
            end
        when :tcp
          case ip_type
            when :ipv4 ; OverSIP::SIP::IPv4TcpServer
            when :ipv6 ; OverSIP::SIP::IPv6TcpServer
            end
        when :tls
          case ip_type
            when :ipv4 ; OverSIP::SIP::IPv4TlsServer
            when :ipv6 ; OverSIP::SIP::IPv6TlsServer
            end
        when :tls_tunnel
          case ip_type
            when :ipv4 ; OverSIP::SIP::IPv4TlsTunnelServer
            when :ipv6 ; OverSIP::SIP::IPv6TlsTunnelServer
            end
        end

      klass.ip = virtual_ip || ip
      klass.port = virtual_port || port

      case

        when klass == OverSIP::SIP::IPv4UdpServer
          klass.via_core = "SIP/2.0/UDP #{uri_ip}:#{port}"
          klass.record_route = "<sip:#{uri_ip}:#{port};transport=udp;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
          klass.outbound_record_route_fragment = "@#{uri_ip}:#{port};transport=udp;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
          klass.outbound_path_fragment = "@#{uri_ip}:#{port};transport=udp;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid};ob>"

          if enabled
            EM::open_datagram_socket(ip, port, klass) do |conn|
              klass.connections = conn
            end
          end

        when klass == OverSIP::SIP::IPv6UdpServer
          klass.via_core = "SIP/2.0/UDP #{uri_ip}:#{port}"
          klass.record_route = "<sip:#{uri_ip}:#{port};transport=udp;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
          klass.outbound_record_route_fragment = "@#{uri_ip}:#{port};transport=udp;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
          klass.outbound_path_fragment = "@#{uri_ip}:#{port};transport=udp;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid};ob>"

          if enabled
            EM::open_datagram_socket(ip, port, klass) do |conn|
              klass.connections = conn
            end
          end

        when klass == OverSIP::SIP::IPv4TcpServer
          klass.via_core = "SIP/2.0/TCP #{uri_ip}:#{port}"
          klass.record_route = "<sip:#{uri_ip}:#{port};transport=tcp;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
          klass.outbound_record_route_fragment = "@#{uri_ip}:#{port};transport=tcp;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
          klass.outbound_path_fragment = "@#{uri_ip}:#{port};transport=tcp;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid};ob>"

          if enabled
            EM.start_server(ip, port, klass) do |conn|
              conn.post_connection
              conn.set_comm_inactivity_timeout 3600  # TODO
            end
          end

        when klass == OverSIP::SIP::IPv6TcpServer
          klass.via_core = "SIP/2.0/TCP #{uri_ip}:#{port}"
          klass.record_route = "<sip:#{uri_ip}:#{port};transport=tcp;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
          klass.outbound_record_route_fragment = "@#{uri_ip}:#{port};transport=tcp;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
          klass.outbound_path_fragment = "@#{uri_ip}:#{port};transport=tcp;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid};ob>"

          if enabled
            EM.start_server(ip, port, klass) do |conn|
              conn.post_connection
              conn.set_comm_inactivity_timeout 3600 # TODO
            end
          end

        when klass == OverSIP::SIP::IPv4TlsServer
          klass.via_core = "SIP/2.0/TLS #{uri_ip}:#{port}"
          rr_host = ::OverSIP.configuration[:sip][:record_route_hostname_tls_ipv4] || uri_ip
          klass.record_route = "<sip:#{rr_host}:#{port};transport=tls;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
          klass.outbound_record_route_fragment = "@#{rr_host}:#{port};transport=tls;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
          klass.outbound_path_fragment = "@#{rr_host}:#{port};transport=tls;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid};ob>"

          if enabled
            EM.start_server(ip, port, klass) do |conn|
              conn.post_connection
              conn.set_comm_inactivity_timeout 3600  # TODO
            end
          end

        when klass == OverSIP::SIP::IPv6TlsServer
          klass.via_core = "SIP/2.0/TLS #{uri_ip}:#{port}"
          rr_host = ::OverSIP.configuration[:sip][:record_route_hostname_tls_ipv6] || uri_ip
          klass.record_route = "<sip:#{rr_host}:#{port};transport=tls;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
          klass.outbound_record_route_fragment = "@#{rr_host}:#{port};transport=tls;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
          klass.outbound_path_fragment = "@#{rr_host}:#{port};transport=tls;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid};ob>"

          if enabled
            EM.start_server(ip, port, klass) do |conn|
              conn.post_connection
              conn.set_comm_inactivity_timeout 3600  # TODO
            end
          end

        when klass == OverSIP::SIP::IPv4TlsTunnelServer
          klass.via_core = "SIP/2.0/TLS #{uri_virtual_ip}:#{virtual_port}"
          rr_host = ::OverSIP.configuration[:sip][:record_route_hostname_tls_ipv4] || uri_virtual_ip
          klass.record_route = "<sip:#{rr_host}:#{virtual_port};transport=tls;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
          klass.outbound_record_route_fragment = "@#{rr_host}:#{virtual_port};transport=tls;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
          klass.outbound_path_fragment = "@#{rr_host}:#{virtual_port};transport=tls;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid};ob>"

          if enabled
            EM.start_server(ip, port, klass) do |conn|
              conn.post_connection
              conn.set_comm_inactivity_timeout 3600  # TODO
            end
          end

        when klass == OverSIP::SIP::IPv6TlsTunnelServer
          klass.via_core = "SIP/2.0/TLS #{uri_virtual_ip}:#{virtual_port}"
          rr_host = ::OverSIP.configuration[:sip][:record_route_hostname_tls_ipv6] || uri_virtual_ip
          klass.record_route = "<sip:#{rr_host}:#{virtual_port};transport=tls;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
          klass.outbound_record_route_fragment = "@#{rr_host}:#{virtual_port};transport=tls;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
          klass.outbound_path_fragment = "@#{rr_host}:#{virtual_port};transport=tls;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid};ob>"

          if enabled
            EM.start_server(ip, port, klass) do |conn|
              conn.post_connection
              conn.set_comm_inactivity_timeout 3600  # TODO
            end
          end

        end  # case

      transport_str = case transport
        when :tls_tunnel ; "TLS-Tunnel"
        else             ; transport.to_s.upcase
        end

      if enabled
        log_system_info "SIP #{transport_str} server listening on #{IP_TYPE[ip_type]} #{uri_ip}:#{port}"
      end

    end  # def self.run

  end

end