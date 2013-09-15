module OverSIP::WebSocket

  module Launcher

    extend ::OverSIP::Logger

    IP_TYPE = {
      :ipv4 => "IPv4",
      :ipv6 => "IPv6"
    }


    @log_id = "WebSocket launcher"


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
        when :ws
          case ip_type
            when :ipv4 ; ::OverSIP::WebSocket::IPv4WsServer
            when :ipv6 ; ::OverSIP::WebSocket::IPv6WsServer
            end
        when :wss
          case ip_type
            when :ipv4 ; ::OverSIP::WebSocket::IPv4WssServer
            when :ipv6 ; ::OverSIP::WebSocket::IPv6WssServer
            end
        when :wss_tunnel
          case ip_type
            when :ipv4 ; ::OverSIP::WebSocket::IPv4WssTunnelServer
            when :ipv6 ; ::OverSIP::WebSocket::IPv6WssTunnelServer
            end
        end

      klass.ip = virtual_ip || ip
      klass.port = virtual_port || port

      case

        when klass == ::OverSIP::WebSocket::IPv4WsServer
          if ::OverSIP.configuration[:websocket][:advertised_ipv4]
            used_uri_host = ::OverSIP.configuration[:websocket][:advertised_ipv4]
          else
            used_uri_host = uri_ip
          end
          klass.via_core = "SIP/2.0/WS #{used_uri_host}:#{port}"
          klass.record_route = "<sip:#{used_uri_host}:#{port};transport=ws;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
          klass.outbound_record_route_fragment = "@#{used_uri_host}:#{port};transport=ws;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
          klass.outbound_path_fragment = "@#{used_uri_host}:#{port};transport=ws;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid};ob>"
          
          if enabled
            ::EM.start_server(ip, port, klass) do |conn|
              conn.post_connection
              conn.set_comm_inactivity_timeout 300
            end
          end

        when klass == ::OverSIP::WebSocket::IPv6WsServer
          if ::OverSIP.configuration[:websocket][:advertised_ipv6]
            used_uri_host = "[#{::OverSIP.configuration[:websocket][:advertised_ipv6]}]"
          else
            used_uri_host = uri_ip
          end
          klass.via_core = "SIP/2.0/WS #{used_uri_host}:#{port}"
          klass.record_route = "<sip:#{used_uri_host}:#{port};transport=ws;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
          klass.outbound_record_route_fragment = "@#{used_uri_host}:#{port};transport=ws;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
          klass.outbound_path_fragment = "@#{used_uri_host}:#{port};transport=ws;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid};ob>"

          if enabled
            ::EM.start_server(ip, port, klass) do |conn|
              conn.post_connection
              conn.set_comm_inactivity_timeout 300
            end
          end

        when klass == ::OverSIP::WebSocket::IPv4WssServer
          if ::OverSIP.configuration[:sip][:record_route_hostname_tls_ipv4]
            used_uri_host = ::OverSIP.configuration[:sip][:record_route_hostname_tls_ipv4]
          elsif ::OverSIP.configuration[:websocket][:advertised_ipv4]
            used_uri_host = ::OverSIP.configuration[:websocket][:advertised_ipv4]
          else
            used_uri_host = uri_ip
          end
          klass.via_core = "SIP/2.0/WS #{used_uri_host}:#{port}"
          klass.record_route = "<sip:#{used_uri_host}:#{port};transport=ws;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
          klass.outbound_record_route_fragment = "@#{used_uri_host}:#{port};transport=ws;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
          klass.outbound_path_fragment = "@#{used_uri_host}:#{port};transport=ws;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid};ob>"

          if enabled
            ::EM.start_server(ip, port, klass) do |conn|
              conn.post_connection
              conn.set_comm_inactivity_timeout 300
            end
          end

        when klass == ::OverSIP::WebSocket::IPv6WssServer
          if ::OverSIP.configuration[:sip][:record_route_hostname_tls_ipv6]
            used_uri_host = ::OverSIP.configuration[:sip][:record_route_hostname_tls_ipv6]
          elsif ::OverSIP.configuration[:websocket][:advertised_ipv6]
            used_uri_host = "[#{::OverSIP.configuration[:websocket][:advertised_ipv6]}]"
          else
            used_uri_host = uri_ip
          end
          klass.via_core = "SIP/2.0/WS #{used_uri_host}:#{port}"
          klass.record_route = "<sip:#{used_uri_host}:#{port};transport=ws;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
          klass.outbound_record_route_fragment = "@#{used_uri_host}:#{port};transport=ws;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
          klass.outbound_path_fragment = "@#{used_uri_host}:#{port};transport=ws;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid};ob>"

          if enabled
            ::EM.start_server(ip, port, klass) do |conn|
              conn.post_connection
              conn.set_comm_inactivity_timeout 300
            end
          end

        when klass == ::OverSIP::WebSocket::IPv4WssTunnelServer
          if ::OverSIP.configuration[:sip][:record_route_hostname_tls_ipv4]
            used_uri_host = ::OverSIP.configuration[:sip][:record_route_hostname_tls_ipv4]
          elsif ::OverSIP.configuration[:websocket][:advertised_ipv4]
            used_uri_host = ::OverSIP.configuration[:websocket][:advertised_ipv4]
          else
            used_uri_host = uri_virtual_ip
          end
          klass.via_core = "SIP/2.0/WSS #{used_uri_host}:#{virtual_port}"
          klass.record_route = "<sip:#{used_uri_host}:#{virtual_port};transport=wss;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
          klass.outbound_record_route_fragment = "@#{used_uri_host}:#{virtual_port};transport=wss;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
          klass.outbound_path_fragment = "@#{used_uri_host}:#{virtual_port};transport=wss;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid};ob>"

          if enabled
            ::EM.start_server(ip, port, klass) do |conn|
              conn.post_connection
              conn.set_comm_inactivity_timeout 300
            end
          end

        when klass == ::OverSIP::WebSocket::IPv6WssTunnelServer
          if ::OverSIP.configuration[:sip][:record_route_hostname_tls_ipv6]
            used_uri_host = ::OverSIP.configuration[:sip][:record_route_hostname_tls_ipv6]
          elsif ::OverSIP.configuration[:websocket][:advertised_ipv6]
            used_uri_host = "[#{::OverSIP.configuration[:websocket][:advertised_ipv6]}]"
          else
            used_uri_host = uri_virtual_ip
          end
          klass.via_core = "SIP/2.0/WSS #{used_uri_host}:#{virtual_port}"
          klass.record_route = "<sip:#{used_uri_host}:#{virtual_port};transport=wss;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
          klass.outbound_record_route_fragment = "@#{used_uri_host}:#{virtual_port};transport=wss;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid}>"
          klass.outbound_path_fragment = "@#{used_uri_host}:#{virtual_port};transport=wss;lr;ovid=#{OverSIP::SIP::Tags.value_for_route_ovid};ob>"
          
          if enabled
            ::EM.start_server(ip, port, klass) do |conn|
              conn.post_connection
              conn.set_comm_inactivity_timeout 300
            end
          end

        end  # case

      transport_str = case transport
        when :tls_tunnel ; "TLS-Tunnel"
        else             ; transport.to_s.upcase
        end

      if enabled
        log_system_info "WebSocket #{transport_str} server listening on #{IP_TYPE[ip_type]} #{uri_ip}:#{port} provides '#{::OverSIP::WebSocket::WS_SIP_PROTOCOL}' WS subprotocol"
      end

    end  # def self.run

  end

end