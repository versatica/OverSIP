module OverSIP::SIP

  class Uac < Client


    def route request, dst_host=nil, dst_port=nil, dst_transport=nil
      unless (@request = request).is_a? ::OverSIP::SIP::UacRequest or @request.is_a? ::OverSIP::SIP::Request
        raise ::OverSIP::RuntimeError, "request must be a OverSIP::SIP::UacRequest or OverSIP::SIP::Request instance"
      end

      # The destination of the request is taken from:
      # - dst_xxx fields if given.
      # - The request.ruri (which is an OverSIP::SIP::Uri or OverSIP::SIP::NameAddr).
      # Otherwise raise an exception.

      @log_id = "UAC (proxy #{@conf[:name]})"

      # Force the destination.
      if dst_host
        dst_scheme = :sip
        dst_host_type = ::OverSIP::Utils.ip_type(dst_host) || :domain

      # Or use the Request URI.
      else
        dst_scheme = request.ruri.scheme
        dst_host = request.ruri.host
        dst_host_type = request.ruri.host_type
        dst_port = request.ruri.port
        dst_transport = request.ruri.transport_param
      end

      # If the destination uri_host is an IPv6 reference, convert it to real IPv6.
      if dst_host_type == :ipv6_reference
        dst_host = ::OverSIP::Utils.normalize_ipv6(dst_host, true)
        dst_host_type = :ipv6
      end

      # Loockup in the DNS cache of this proxy.
      result = check_dns_cache dst_scheme, dst_host, dst_host_type, dst_port, dst_transport

      case result
      when true
        return
      else  # It can be String or nil, so use it as dns_cache_key param.
        # Perform RFC 3263 procedures.
        do_dns result, @request.via_branch_id, dst_scheme, dst_host, dst_host_type, dst_port, dst_transport
      end

    end  # def route


    def receive_response response
      log_system_debug "received response #{response.status_code}"  if $oversip_debug

      if response.status_code < 200
        run_on_provisional_response_cbs response
      elsif response.status_code >= 200 && response.status_code <= 299
        run_on_success_response_cbs response
      elsif response.status_code >= 300
        if response.status_code == 503
          if @conf[:dns_failover_on_503]
            try_next_target nil, nil, response
            return
          else
            run_on_failure_response_cbs response
          end
        else
          run_on_failure_response_cbs response
        end
      end
    end



    private


    def no_more_targets status, reason, full_response, code
      # If we have received a [3456]XX response from downstream then run @on_failure_response_cbs.
      if full_response
        run_on_failure_response_cbs full_response
      # If not, generate the response according to the given status and reason.
      else
        run_on_error_cbs status, reason, code
      end
    end

  end  # class Uac

end