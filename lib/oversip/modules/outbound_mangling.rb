module OverSIP::Modules

  module OutboundMangling

    extend ::OverSIP::Logger

    @log_id = "OutboundMangling module"

    def self.add_outbound_to_contact proxy
      unless proxy.is_a? ::OverSIP::SIP::Proxy
        raise ::OverSIP::RuntimeError, "proxy must be a OverSIP::SIP::Proxy instance"
      end

      proxy.on_target do |target|
        request = proxy.request
        # Just act in case the request has a single Contact, its connection uses Outbound
        # and  no ;ov-ob param exists in Contact URI.
        if request.contact and request.connection_outbound_flow_token and not request.contact.has_param? "ov-ob"
          log_system_debug "performing Contact mangling (adding ;ov-ob Outbound param) for #{request.log_id}"  if $oversip_debug

          request.contact.set_param "ov-ob", request.connection_outbound_flow_token

          proxy.on_success_response do |response|
            if (contacts = response.headers["Contact"])
              log_system_debug "reverting original Contact value (removing ;ov-ob Outbound param) from response"  if $oversip_debug
              contacts.each { |contact| contact.gsub! /;ov-ob=[_\-0-9A-Za-z]+/, "" }
            end
          end
        end
      end
    end

    def self.extract_outbound_from_ruri request
      # Do nothing if the request already contains a Route header with the Outbound flow token (so
      # the registrar *does* support Path).
      unless request.incoming_outbound_requested?
        if (ov_ob = request.ruri.del_param("ov-ob"))
          log_system_debug "incoming Outbound flow token extracted from ;ov-ob param in RURI for #{request.log_id}"  if $oversip_debug
          request.route_outbound_flow_token = ov_ob
          request.incoming_outbound_requested = true
          return true
        else
          return false
        end

      else
        # If the request already contains a proper Outbound Route header, then at least try to remove
        # the ;ov-ob param from the RURI.
        request.ruri.del_param("ov-ob")
        return false
      end
    end

  end  # module OutboundMangling

end
