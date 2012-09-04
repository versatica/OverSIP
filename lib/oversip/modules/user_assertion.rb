module OverSIP::Modules

  module UserAssertion

    extend ::OverSIP::Logger

    @log_id = "UserAssertion module"

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
      return request.cvars[:asserted_user]  if request.cvars[:asserted_user]
      # Don't do this stuf in case of P-Preferred-Identity header is present.
      return false  if request.headers["P-Preferred-Identity"]

      log_system_debug "user #{request.from.uri} asserted to connection"  if $oversip_debug
      # Store the request From URI as "asserted_user" for this connection.
      request.cvars[:asserted_user] = request.from.uri
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

      request.cvars.delete :asserted_user
      true
    end

    def self.add_pai request
      # Add P-Asserted-Identity if the user has previously been asserted but JUST
      # in case it matches request From URI !
      # NOTE: If the connection is not asserted (it's null) then it will not match this
      # comparisson, so OK.
      if request.cvars[:asserted_user] == request.from.uri
        # Don't add P-Asserted-Identity if the request contains P-Preferred-Identity header.
        unless request.headers["P-Preferred-Identity"]
          log_system_debug "user asserted, adding P-Asserted-Identity for #{request.log_id}"  if $oversip_debug
          request.set_header "P-Asserted-Identity", "<" << request.cvars[:asserted_user] << ">"
          return true
        else
          # Remove posible P-Asserted-Identity header!
          log_system_debug "user asserted but P-Preferred-Identity header present, P-Asserted-Identity not added for #{request.log_id}"  if $oversip_debug
          request.headers.delete "P-Asserted-Identity"
          return nil
        end

      # Otherwise ensure the request has no spoofed P-Asserted-Identity headers!
      else
        request.headers.delete "P-Asserted-Identity"
        return false

      end
    end

  end  # module UserAssertion

end
