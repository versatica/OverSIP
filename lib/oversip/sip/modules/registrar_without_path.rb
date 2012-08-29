module OverSIP::SIP

  module Modules
    module RegistrarWithoutPath

      extend ::OverSIP::Logger

      def self.log_id
        @@log_id ||= "RegistrarWithoutPath module"
      end

      def self.add_outbound_to_contact request
        unless request.sip_method == :REGISTER
          raise ::OverSIP::RuntimeError, "request must be a REGISTER"
        end

        if request.contact and request.connection_outbound_flow_token
          log_system_debug "performing Contact mangling (adding ;ov-ob Outbound param) for #{request.log_id}"  if $oversip_debug

          # Add the ;ov-ob param to the Contact URI.
          request.contact.set_param "ov-ob", request.connection_outbound_flow_token
          return true
        else
          return false
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

      def self.remove_outbound_from_contact message
        unless message.is_a? ::OverSIP::SIP::Message
          raise ::OverSIP::RuntimeError, "message must be a OverSIP::SIP::Request or OverSIP::SIP::Response"
        end

        if (contacts = message.headers["Contact"])
          log_system_debug "reverting original Contact value (removing ;ov-ob Outbound param) for response"  if $oversip_debug
          contacts.each do |contact|
            contact.gsub! /;ov-ob=[_\-0-9A-Za-z]+/, ""
          end
          return true
        else
          return false
        end
      end

    end  # module RegistrarWithoutPath
  end  # module Modules

end  # module OverSIP::SIP
