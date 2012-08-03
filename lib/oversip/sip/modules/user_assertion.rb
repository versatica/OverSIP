module OverSIP::SIP

  module Modules
    module UserAssertion

      extend ::OverSIP::Logger

      def self.log_id
        @@log_id ||= "UserAssertion module"
      end

      def self.assert_connection message
        case message
        when ::OverSIP::SIP::Request
          request = message
        when ::OverSIP::SIP::Response
          request = message.request
        else
          raise ::OverSIP::RuntimeError, "message must be a OverSIP::SIP::Request or OverSIP::SIP::Response"
        end

        # Don't do this stuf for UDP or for outbound connections.
        return false  unless request.connection.class.reliable_transport_listener?
        # Return if already set.
        return request.connection.asserted_user  if request.connection.asserted_user
        # Don't do this stuf in case of P-Preferred-Identity header is present.
        return false  if request.headers["P-Preferred-Identity"]

        log_system_debug "user #{request.from.uri} asserted to connection"  if $oversip_debug
        # Store the request From URI as "asserted_user" for this connection.
        request.connection.asserted_user = request.from.uri
      end

      def self.revoke_assertion message
        case message
        when ::OverSIP::SIP::Request
          request = message
        when ::OverSIP::SIP::Response
          request = message.request
        else
          raise ::OverSIP::RuntimeError, "message must be a OverSIP::SIP::Request or OverSIP::SIP::Response"
        end

        request.connection.asserted_user = false
        true
      end

      def self.add_pai request
        # Add P-Asserted-Identity if the user has previously been asserted but JUST
        # in case it matches request From URI !
        # NOTE: If the connection is not asserted (it's null) then it will not match this
        # comparisson, so OK.
        if request.connection.asserted_user == request.from.uri
          # Don't add P-Asserted-Identity if the request contains P-Preferred-Identity header.
          unless request.headers["P-Preferred-Identity"]
            log_system_debug "user asserted, adding P-Asserted-Identity for #{request.log_id}"  if $oversip_debug
            request.set_header "P-Asserted-Identity", "<" << request.connection.asserted_user << ">"
            return true
          else
            # Remove posible P-Asserted-Identity header!
            log_system_debug "user asserted but P-Preferred-Identity header present, P-Asserted-Identity not added for #{request.log_id}"  if $oversip_debug
            request.headers.delete "P-Asserted-Identity"
          end

        # Otherwise ensure the request has no spoofed P-Asserted-Identity headers!
        else
          request.headers.delete "P-Asserted-Identity"
          return false

        end
      end

    end  # module UserAssertion
  end  # module Modules

end  # module OverSIP::SIP


module OverSIP::SIP
  class Request
    def asserted_user?
      true  if self.connection.asserted_user
    end

    def asserted_user
      self.connection.asserted_user
    end
  end

  class Response
    def asserted_user?
      true  if self.request.connection.asserted_user
    end

    def asserted_user
      self.request.connection.asserted_user
    end
  end

  class TcpServer
    attr_accessor :asserted_user
  end

  class TlsServer
    attr_accessor :asserted_user
  end

  class TlsTunnelServer
    attr_accessor :asserted_user
  end

  # This is never used since it's not a reliable connection, but it's required not to fail.
  class UdpReactor
    attr_accessor :asserted_user
  end
end  # OverSIP::SIP


module OverSIP::WebSocket
  class WsSipApp
    attr_accessor :asserted_user
  end
end  # OverSIP::WebSocket
