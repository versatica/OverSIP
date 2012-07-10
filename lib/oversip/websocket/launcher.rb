module OverSIP::WebSocket

  module Launcher

    extend OverSIP::Logger

    IP_TYPE = {
      :ipv4 => "IPv4",
      :ipv6 => "IPv6"
    }


    def self.log_id
      @log_id ||= "WebSocket launcher"
    end


    def self.run enabled, ip_type, ip, port, transport, ws_protocol, virtual_ip=nil, virtual_port=nil
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
        when :tcp
          case ip_type
            when :ipv4 ; OverSIP::WebSocket::IPv4TcpServer
            when :ipv6 ; OverSIP::WebSocket::IPv6TcpServer
            end
        when :tls
          case ip_type
            when :ipv4 ; OverSIP::WebSocket::IPv4TlsServer
            when :ipv6 ; OverSIP::WebSocket::IPv6TlsServer
            end
        when :tls_tunnel
          case ip_type
            when :ipv4 ; OverSIP::WebSocket::IPv4TlsTunnelServer
            when :ipv6 ; OverSIP::WebSocket::IPv6TlsTunnelServer
            end
        end

      case ws_protocol

      when OverSIP::WebSocket::WS_SIP_PROTOCOL

        ws_app_klass = case transport
          when :tcp
            case ip_type
              when :ipv4 ; OverSIP::WebSocket::IPv4WsSipApp
              when :ipv6 ; OverSIP::WebSocket::IPv6WsSipApp
              end
          when :tls, :tls_tunnel
            case ip_type
              when :ipv4 ; OverSIP::WebSocket::IPv4WssSipApp
              when :ipv6 ; OverSIP::WebSocket::IPv6WssSipApp
              end
          end

        ws_app_klass.ip = virtual_ip || ip
        ws_app_klass.port = virtual_port || port

        case

          when klass == OverSIP::WebSocket::IPv4TcpServer
            ws_app_klass.via_core = "SIP/2.0/WS #{uri_ip}:#{port}"
            ws_app_klass.record_route = "<sip:#{uri_ip}:#{port};transport=ws;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
            ws_app_klass.outbound_record_route_fragment = "@#{uri_ip}:#{port};transport=ws;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
            ws_app_klass.outbound_path_fragment = "@#{uri_ip}:#{port};transport=ws;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid};ob>"

            if enabled
              EM.start_server(ip, port, klass) do |conn|
                conn.ws_protocol = ws_protocol
                conn.ws_app_klass = ws_app_klass
                conn.post_connection
                conn.set_comm_inactivity_timeout 3600  # TODO
              end
            end

          when klass == OverSIP::WebSocket::IPv6TcpServer
            ws_app_klass.via_core = "SIP/2.0/WS #{uri_ip}:#{port}"
            ws_app_klass.record_route = "<sip:#{uri_ip}:#{port};transport=ws;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
            ws_app_klass.outbound_record_route_fragment = "@#{uri_ip}:#{port};transport=ws;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
            ws_app_klass.outbound_path_fragment = "@#{uri_ip}:#{port};transport=ws;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid};ob>"

            if enabled
              EM.start_server(ip, port, klass) do |conn|
                conn.ws_protocol = ws_protocol
                conn.ws_app_klass = ws_app_klass
                conn.post_connection
                conn.set_comm_inactivity_timeout 3600  # TODO
              end
            end

          when klass == OverSIP::WebSocket::IPv4TlsServer
            ws_app_klass.via_core = "SIP/2.0/WSS #{uri_ip}:#{port}"
            rr_host = ::OverSIP.configuration[:sip][:record_route_hostname_tls_ipv4] || uri_ip
            ws_app_klass.record_route = "<sip:#{rr_host}:#{port};transport=wss;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
            ws_app_klass.outbound_record_route_fragment = "@#{rr_host}:#{port};transport=wss;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
            ws_app_klass.outbound_path_fragment = "@#{rr_host}:#{port};transport=wss;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid};ob>"

            if enabled
              EM.start_server(ip, port, klass) do |conn|
                conn.ws_protocol = ws_protocol
                conn.ws_app_klass = ws_app_klass
                conn.post_connection
                conn.set_comm_inactivity_timeout 3600  # TODO
              end
            end

          when klass == OverSIP::WebSocket::IPv6TlsServer
            ws_app_klass.via_core = "SIP/2.0/WSS #{uri_ip}:#{port}"
            rr_host = ::OverSIP.configuration[:sip][:record_route_hostname_tls_ipv6] || uri_ip
            ws_app_klass.record_route = "<sips:#{rr_host}:#{port};transport=ws;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
            ws_app_klass.outbound_record_route_fragment = "@#{rr_host}:#{port};transport=wss;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
            ws_app_klass.outbound_path_fragment = "@#{rr_host}:#{port};transport=wss;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid};ob>"

            if enabled
              EM.start_server(ip, port, klass) do |conn|
                conn.ws_protocol = ws_protocol
                conn.ws_app_klass = ws_app_klass
                conn.post_connection
                conn.set_comm_inactivity_timeout 3600  # TODO
              end
            end

          when klass == OverSIP::WebSocket::IPv4TlsTunnelServer
            ws_app_klass.via_core = "SIP/2.0/WSS #{uri_virtual_ip}:#{virtual_port}"
            rr_host = ::OverSIP.configuration[:sip][:record_route_hostname_tls_ipv4] || uri_virtual_ip
            ws_app_klass.record_route = "<sip:#{rr_host}:#{virtual_port};transport=wss;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
            ws_app_klass.outbound_record_route_fragment = "@#{rr_host}:#{virtual_port};transport=wss;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
            ws_app_klass.outbound_path_fragment = "@#{rr_host}:#{virtual_port};transport=wss;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid};ob>"

            if enabled
              EM.start_server(ip, port, klass) do |conn|
                conn.ws_protocol = ws_protocol
                conn.ws_app_klass = ws_app_klass
                conn.post_connection
                conn.set_comm_inactivity_timeout 3600  # TODO
              end
            end

          when klass == OverSIP::WebSocket::IPv6TlsTunnelServer
            ws_app_klass.via_core = "SIP/2.0/WSS #{uri_virtual_ip}:#{virtual_port}"
            rr_host = ::OverSIP.configuration[:sip][:record_route_hostname_tls_ipv6] || uri_virtual_ip
            ws_app_klass.record_route = "<sip:#{rr_host}:#{virtual_port};transport=wss;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
            ws_app_klass.outbound_record_route_fragment = "@#{rr_host}:#{virtual_port};transport=wss;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
            ws_app_klass.outbound_path_fragment = "@#{rr_host}:#{virtual_port};transport=wss;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid};ob>"

            if enabled
              EM.start_server(ip, port, klass) do |conn|
                conn.ws_protocol = ws_protocol
                conn.ws_app_klass = ws_app_klass
                conn.post_connection
                conn.set_comm_inactivity_timeout 3600  # TODO
              end
            end

          end  # case


      when OverSIP::WebSocket::WS_AUTOBAHN_PROTOCOL

        ws_app_klass = case transport
          when :tcp
            case ip_type
              when :ipv4 ; OverSIP::WebSocket::WsAutobahnApp
              end
          when :tls
            case ip_type
              when :ipv4 ; OverSIP::WebSocket::WsAutobahnApp
              end
          end

        EM.start_server(ip, port, klass) do |conn|
          conn.ws_protocol = ws_protocol
          conn.ws_app_klass = ws_app_klass
          conn.post_connection
          conn.set_comm_inactivity_timeout 60
        end


      else
        fatal "unknown WebSocket protocol: #{ws_protocol}"

      end  # case

      transport_str = case transport
        when :tls_tunnel ; "TLS-Tunnel"
        else             ; transport.to_s.upcase
        end

      if enabled
        log_system_info "WebSocket #{transport_str} server listening on #{IP_TYPE[ip_type]} #{uri_ip}:#{port} provides '#{ws_protocol}' WS subprotocol"
      end

    end  # def self.run

  end

end