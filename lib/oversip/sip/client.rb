module OverSIP::SIP

  class Client

    include ::OverSIP::Logger

    attr_reader :current_target

    def initialize proxy_profile=:default_proxy
      unless (@conf = ::OverSIP.proxies[proxy_profile.to_sym])
        raise ::OverSIP::RuntimeError, "proxy profile '#{proxy_profile}' is not defined"
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

    def on_canceled &block
      @on_canceled_block = block
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

    # By calling this method the request routing is aborted, no more DNS targets are tryed,
    # a local 403 response is generated and on_error() callback is called with status 403.
    def abort_routing
      @aborted = true
    end

    # Manually insert the last target into the blacklist. Optionally a timeout value can be given
    # (otherwise the proxy blacklist_time is used). The timeout must be between 2 and 3000 seconds.
    # Also the SIP code and reason can be passed.
    def add_target_to_blacklist timeout=nil, status_code=403, reason_phrase="Destination Blacklisted"
      return false  unless @current_target

      if timeout
        timeout = timeout.to_i
        if timeout < 2 or timeout > 3000
          raise ::OverSIP::RuntimeError, "timeout must be between a and 3000 seconds"
        end
      else
        timeout = @conf[:blacklist_time]
      end

      blacklist_entry = @current_target.to_s
      @conf[:blacklist][blacklist_entry] = [status_code, reason_phrase, nil, :destination_blacklisted]
      ::EM.add_timer(timeout) { @conf[:blacklist].delete blacklist_entry }
    end


    ### Methods called by the client transaction.

    def client_timeout
      # Store the target and error in the blacklist.
      if @conf[:use_blacklist]
        blacklist_entry = @current_target.to_s
        @conf[:blacklist][blacklist_entry] = [408, "Client Timeout", nil, :client_timeout]
        ::EM.add_timer(@conf[:blacklist_time]) { @conf[:blacklist].delete blacklist_entry }
      end

      try_next_target 408, "Client Timeout", nil, :client_timeout
    end

    def connection_failed
      # Store the target and error in the blacklist.
      if @conf[:use_blacklist]
        blacklist_entry = @current_target.to_s
        @conf[:blacklist][blacklist_entry] = [500, "Connection Error", nil, :connection_error]
        ::EM.add_timer(@conf[:blacklist_time]) { @conf[:blacklist].delete blacklist_entry }
      end

      try_next_target 500, "Connection Error", nil, :connection_error
    end

    def tls_validation_failed
      # Store the target and error in the blacklist.
      if @conf[:use_blacklist]
        blacklist_entry = @current_target.to_s
        @conf[:blacklist][blacklist_entry] = [500, "TLS Validation Failed", nil, :tls_validation_failed]
        ::EM.add_timer(@conf[:blacklist_time]) { @conf[:blacklist].delete blacklist_entry }
      end

      try_next_target 500, "TLS Validation Failed", nil, :tls_validation_failed
    end

    # Timer C for INVITE.
    def invite_timeout
      @on_invite_timeout_block && @on_invite_timeout_block.call
    end



    private


    def add_routing_headers
    end


    # Check the given URI into the DNS cache.
    # - If the cache is not enabled it returns nil.
    # - If present it returns true.
    # - If not it returns dns_cache_key (String).
    def check_dns_cache dst_scheme, dst_host, dst_host_type, dst_port, dst_transport
      if dst_host_type == :domain and @conf[:use_dns_cache]
        dns_cache_key = "#{dst_scheme}|#{dst_host}|#{dst_port}|#{dst_transport}"
        if (result = @conf[:dns_cache][dns_cache_key])
          log_system_debug "destination found in the DNS cache"  if $oversip_debug
          if result.is_a? ::Symbol
            rfc3263_failed result
          else
            rfc3263_succeeded result
          end
          return true
        else
          return dns_cache_key
        end
      else
        return nil
      end
    end


    def do_dns dns_cache_key, id, dst_scheme, dst_host, dst_host_type, dst_port, dst_transport
      # Perform RFC 3261 procedures.
      dns_query = ::OverSIP::SIP::RFC3263::Query.new @conf, id, dst_scheme, dst_host, dst_host_type, dst_port, dst_transport
      case result = dns_query.resolve

      # Async result so DNS took place.
      when nil
        # Async success.
        dns_query.callback do |result|
          # Store the result in the DNS cache.
          if dns_cache_key
            @conf[:dns_cache][dns_cache_key] = result
            ::EM.add_timer(@conf[:dns_cache_time]) { @conf[:dns_cache].delete dns_cache_key }
          end
          rfc3263_succeeded result
        end
        # Async error.
        dns_query.errback do |result|
          # Store the result in the DNS cache.
          if dns_cache_key
            @conf[:dns_cache][dns_cache_key] = result
            ::EM.add_timer(@conf[:dns_cache_time]) { @conf[:dns_cache].delete dns_cache_key }
          end
          rfc3263_failed result
        end
      # Instant error.
      when ::Symbol
        # Store the result in the DNS cache.
        if dns_cache_key
          @conf[:dns_cache][dns_cache_key] = result
          ::EM.add_timer(@conf[:dns_cache_time]) { @conf[:dns_cache].delete dns_cache_key }
        end
        rfc3263_failed result
      # Instant success so it's not a domain (no DNS performed).
      else
        rfc3263_succeeded result
      end
    end


    def rfc3263_succeeded result
      # After RFC 3263 (DNS) resolution we get N targets.
      @num_target = 0  # First target is 0 (rather than 1).
      @target = @targets = nil  # Avoid conflicts if same Proxy is used for serial forking to a new destination.

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
        no_more_targets status, reason, full_response, code
      end
    end  # try_next_target


    def use_target target
      # Lookup the target in the blacklist.
      if @conf[:blacklist].any? and (blacklist_entry = @conf[:blacklist][target.to_s])
        log_system_notice "destination found in the blacklist"  if $oversip_debug
        try_next_target blacklist_entry[0], blacklist_entry[1], blacklist_entry[2], blacklist_entry[3]
        return
      end

      # Call the on_target() callback if set by the user.
      @on_target_block && @on_target_block.call(target)

      # If the user has called to proxy.abort_routing() then stop next targets
      # and call to on_error() callback.
      if @aborted
        log_system_notice "routing aborted for target #{target}"
        @aborted = @target = @targets = nil
        try_next_target 403, "Destination Aborted", nil, :destination_aborted
        return
      end

      @client_transaction = (::OverSIP::SIP::ClientTransaction.get_class @request).new self, @request, @conf, target.transport, target.ip, target.ip_type, target.port
      add_routing_headers
      @client_transaction.send_request
    end


    def no_more_targets status, reason, full_response, code
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

      do_dns_fail status, reason, code
    end  # def rfc3263_failed


    def do_dns_fail status, reason, code
      @on_error_block && @on_error_block.call(status, reason, code)
    end

  end  # class Client

end