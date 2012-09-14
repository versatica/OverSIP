module OverSIP::SIP

  class Uac

    include ::OverSIP::Logger

    def initialize proxy_profile=:default_proxy
      unless (@proxy_conf = ::OverSIP.proxies[proxy_profile.to_sym])
        raise ::OverSIP::RuntimeError, "proxy '#{proxy_profile}' is not defined in Proxies Configuration file"
      end
    end


    def on_provisional_response &block
      @on_provisional_response_block = block
    end

    def on_success_response &block
      @on_success_response_block = block
    end

    def on_failure_response &block
      @on_failure_response_block = block
    end

    def on_invite_timeout &block
      @on_invite_timeout_block = block
    end

    def on_error &block
      @on_error_block = block
    end

    def on_target &block
      @on_target_block = block
    end

    # It must only be called within the on_target() callback. By calling this method,
    # the request sending is aborted, no more DNS targets are tryed, a local 403 response
    # is generated and on_error() callback is called with status 403.
    def abort_sending
      @aborted = true
    end
    alias :abort_routing :abort_sending

    # Manually insert the last target into the blacklist. Optionally a timeout value can be given
    # (otherwise the proxy blacklist_time is used). The timeout must be between 2 and 300 seconds.
    # NOTE: It requires that the Proxy has :use_blacklist set.
    def add_to_blacklist timeout=nil
      if @proxy_conf[:use_blacklist]
        if timeout
          timeout = timeout.to_i
          if timeout < 2 or timeout > 300
            raise ::OverSIP::RuntimeError, "timeout must be between a and 300 seconds"
          end
        else
          timeout = @proxy_conf[:blacklist_time]
        end

        blacklist_entry = @current_target.to_s
        @proxy_conf[:blacklist][blacklist_entry] = [403, "Destination Blacklisted", nil, :destination_blacklisted]
        ::EM.add_timer(timeout) { @proxy_conf[:blacklist].delete blacklist_entry }
      else
        raise ::OverSIP::RuntimeError, "the blacklist is not enabled for this proxy profile"
      end
    end

    def send request, dst_host=nil, dst_port=nil, dst_transport=nil
      unless (@request = request).is_a? ::OverSIP::SIP::UacRequest or @request.is_a? ::OverSIP::SIP::Request
        raise ::OverSIP::RuntimeError, "request must be a OverSIP::SIP::UacRequest or OverSIP::SIP::Request instance"
      end

      # The destination of the request is taken from:
      # - dst_xxx fields if given.
      # - The request.ruri if it is an OverSIP::SIP::Uri or OverSIP::SIP::NameAddr.
      # Otherwise raise an exception.
      unless dst_host or request.ruri.is_a?(::OverSIP::SIP::Uri) or request.ruri.is_a?(::OverSIP::SIP::NameAddr)
        raise ::OverSIP::RuntimeError, "if dst_host is not given then request.ruri must be an OverSIP::SIP::Uri or OverSIP::SIP::NameAddr instance"
      end

      @log_id = "UAC (proxy #{@proxy_conf[:name]})"

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
      if dst_host_type == :domain and @proxy_conf[:use_dns_cache]
        dns_cache_entry = "#{dst_host}|#{dst_port}|#{dst_transport}|#{dst_scheme}"
        if (result = @proxy_conf[:dns_cache][dns_cache_entry])
          log_system_debug "destination found in the DNS cache"  if $oversip_debug
          if result.is_a? ::Symbol
            rfc3263_failed result
          else
            rfc3263_succeeded result
          end
          return
        end
      else
        dns_cache_entry = nil
      end

      # Perform RFC 3261 procedures.
      dns_query = ::OverSIP::SIP::RFC3263::Query.new @proxy_conf, "UAC", dst_scheme, dst_host, dst_host_type, dst_port, dst_transport
      case result = dns_query.resolve

      # Async result so DNS took place.
      when nil
        # Async success.
        dns_query.callback do |result|
          # Store the result in the DNS cache.
          if dns_cache_entry
            @proxy_conf[:dns_cache][dns_cache_entry] = result
            ::EM.add_timer(@proxy_conf[:dns_cache_time]) { @proxy_conf[:dns_cache].delete dns_cache_entry }
          end
          rfc3263_succeeded result
        end
        # Async error.
        dns_query.errback do |result|
          # Store the result in the DNS cache.
          if dns_cache_entry
            @proxy_conf[:dns_cache][dns_cache_entry] = result
            ::EM.add_timer(@proxy_conf[:dns_cache_time]) { @proxy_conf[:dns_cache].delete dns_cache_entry }
          end
          rfc3263_failed result
        end
      # Instant error.
      when ::Symbol
        # Store the result in the DNS cache.
        if dns_cache_entry
          @proxy_conf[:dns_cache][dns_cache_entry] = result
          ::EM.add_timer(@proxy_conf[:dns_cache_time]) { @proxy_conf[:dns_cache].delete dns_cache_entry }
        end
        rfc3263_failed result
      # Instant success so it's not a domain (no DNS performed).
      else
        rfc3263_succeeded result
      end

    end  # def send
    alias :route :send


    def receive_response response
      log_system_debug "received response #{response.status_code}"  if $oversip_debug

      if response.status_code < 200
        @on_provisional_response_block && @on_provisional_response_block.call(response)
      elsif response.status_code >= 200 && response.status_code <= 299
        @on_success_response_block && @on_success_response_block.call(response)
      elsif response.status_code >= 300
        if response.status_code == 503
          if @proxy_conf[:dns_failover_on_503]
            try_next_target nil, nil, response
            return
          else
            @on_failure_response_block && @on_failure_response_block.call(response)
          end
        else
          @on_failure_response_block && @on_failure_response_block.call(response)
        end
      end
    end


    def client_timeout
      # Store the target and error in the blacklist.
      if @proxy_conf[:use_blacklist]
        blacklist_entry = @current_target.to_s
        @proxy_conf[:blacklist][blacklist_entry] = [408, "Client Timeout", nil, :client_timeout]
        ::EM.add_timer(@proxy_conf[:blacklist_time]) { @proxy_conf[:blacklist].delete blacklist_entry }
      end

      try_next_target 408, "Client Timeout", nil, :client_timeout
    end


    def connection_failed
      # Store the target and error in the blacklist.
      if @proxy_conf[:use_blacklist]
        blacklist_entry = @current_target.to_s
        @proxy_conf[:blacklist][blacklist_entry] = [500, "Connection Error", nil, :connection_error]
        ::EM.add_timer(@proxy_conf[:blacklist_time]) { @proxy_conf[:blacklist].delete blacklist_entry }
      end

      try_next_target 500, "Connection Error", nil, :connection_error
    end


    def tls_validation_failed
      # Store the target and error in the blacklist.
      if @proxy_conf[:use_blacklist]
        blacklist_entry = @current_target.to_s
        @proxy_conf[:blacklist][blacklist_entry] = [500, "TLS Validation Failed", nil, :tls_validation_failed]
        ::EM.add_timer(@proxy_conf[:blacklist_time]) { @proxy_conf[:blacklist].delete blacklist_entry }
      end

      try_next_target 500, "TLS Validation Failed", nil, :tls_validation_failed
    end


    # Timer C for INVITE.
    def invite_timeout
      @on_invite_timeout_block && @on_invite_timeout_block.call
    end


    private


    def rfc3263_succeeded result
      # After RFC 3263 (DNS) resolution we get N targets.
      @num_target = 0  # First target is 0 (rather than 1).
      @target = @targets = nil  # Avoid conflicts if same Uac is used for serial forking to a new destination.

      case result

      when RFC3263::Target
        @target = result  # Single Target.

      when RFC3263::SrvTargets
        log_system_debug "DNS result has multiple values, randomizing"  if $oversip_debug
        @targets = result.randomize  # Array of Targets.

      # This can contain Target and SrvTargets entries.
      when RFC3263::MultiTargets
        log_system_debug "DNS result has multiple values, randomizing"  if $oversip_debug
        @targets = result.flatten  # Array of Targets.

      end

      try_next_target
    end  # rfc3263_succeeded


    def try_next_target status=nil, reason=nil, full_response=nil, code=nil
      # Single target.
      if @target and @num_target == 0
        @current_target = @target
        log_system_debug "trying single target: #{@current_target}"  if $oversip_debug
        @num_target = 1
        use_target @current_target

      # Multiple targets (so @targets is set).
      elsif @targets and @num_target < @targets.size
        @current_target = @targets[@num_target]
        log_system_debug "trying target #{@num_target+1} of #{@targets.size}: #{@current_target}"  if $oversip_debug
        @num_target += 1
        use_target @current_target

      # No more targets.
      else
        # If we have received a [3456]XX response from downstream then run @on_failure_block.
        if full_response
          @on_failure_response_block && @on_failure_response_block.call(full_response)

        # If not, generate the response according to the given status and reason.
        else
          @on_error_block && @on_error_block.call(status, reason, code)

        end
      end
    end  # try_next_target


    def use_target target
      # Lookup the target in the blacklist.
      if @proxy_conf[:use_blacklist] and (blacklist_entry = @proxy_conf[:blacklist][target.to_s])
        log_system_notice "destination found in the blacklist"  if $oversip_debug
        try_next_target blacklist_entry[0], blacklist_entry[1], blacklist_entry[2], blacklist_entry[3]
        return
      end

      # Call the on_target() callback if set by the user.
      @on_target_block && @on_target_block.call(target.ip_type, target.ip, target.port, target.transport)

      # If the user has called to uac.abort_sending() then stop next targets
      # and call to on_error() callback.
      if @aborted
        log_system_notice "sending aborted for target #{target}"
        @aborted = @target = @targets = nil
        try_next_target 403, "Destination Aborted", nil, :destination_aborted
        return
      end

      @client_transaction = (::OverSIP::SIP::ClientTransaction.get_class @request).new self, @request, @proxy_conf, target.transport, target.ip, target.ip_type, target.port
      @client_transaction.send_request
    end


    def rfc3263_failed error
      case error
      when :rfc3263_domain_not_found
        log_system_debug "no resolution"  if $oversip_debug
        status = 404
        reason = "No DNS Resolution"
        code = :no_dns_resolution
      when :rfc3263_unsupported_scheme
        log_system_debug "unsupported URI scheme"  if $oversip_debug
        status = 416
        reason = "Unsupported URI scheme"
        code = :unsupported_uri_scheme
      when :rfc3263_unsupported_transport
        log_system_debug "unsupported transport"  if $oversip_debug
        status = 478
        reason = "Unsupported Transport"
        code = :unsupported_transport
      when :rfc3263_no_ipv4
        log_system_debug "destination requires unsupported IPv4"  if $oversip_debug
        status = 478
        reason = "Destination Requires Unsupported IPv4"
        code = :no_ipv4
      when :rfc3263_no_ipv6
        log_system_debug "destination requires unsupported IPv6"  if $oversip_debug
        status = 478
        reason = "Destination Requires Unsupported IPv6"
        code = :no_ipv6
      when :rfc3263_no_dns
        log_system_debug "destination requires unsupported DNS query"  if $oversip_debug
        status = 478
        reason = "Destination Requires Unsupported DNS Query"
        code = :no_dns
      end

      @on_error_block && @on_error_block.call(status, reason, code)
    end  # def rfc3263_failed

  end  # class Uac

end