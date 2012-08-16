module OverSIP::SIP

  class Proxy

    include ::OverSIP::Logger

    def initialize proxy_name=:default_proxy
      unless (@proxy_conf = ::OverSIP.proxies[proxy_name.to_sym])
        raise ::OverSIP::RuntimeError, "proxy '#{proxy_name}' is not defined in Proxies Configuration file"
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

    # If called, current response within the called callback won't be forwarded.
    def drop_response
      @drop_response = true
    end


    def route request, dst_host=nil, dst_port=nil, dst_transport=nil
      unless (@request = request).is_a? ::OverSIP::SIP::Request
        raise ::OverSIP::RuntimeError, "request must be a OverSIP::SIP::Request instance"
      end

      @log_id = "Proxy #{@proxy_conf[:name]} #{@request.via_branch_id}"

      # Create the server transaction if it doesn't exist yet.
      @server_transaction = @request.server_transaction or case @request.sip_method
        # Here it can arrive an INVITE, ACK-for-2XX and any method but CANCEL.
        when :INVITE
          InviteServerTransaction.new @request
        when :ACK
        else
          NonInviteServerTransaction.new @request
        end
      @request.server_transaction ||= @server_transaction

      # Set this core layer to the server transaction.
      @request.server_transaction.core = self  if @request.server_transaction

      # NOTE: Routing can be based on incoming request for an Outbound (RFC 5626) connection
      # or based on normal RFC 3263 procedures.

      # If it's an incoming Outbound connection get the associated connection (but if dst_host is
      # set then don't honor the Outbound connection).

      if @request.incoming_outbound_requested? and not dst_host
        @client_transaction = (::OverSIP::SIP::ClientTransaction.get_class @request).new self, @request, @proxy_conf, @request.route_outbound_flow_token

        if @client_transaction.connection
          add_routing_headers
          @client_transaction.send_request
        else
          unless @request.sip_method == :ACK
            log_system_debug "flow failed"  if $oversip_debug

            @on_error_block && @on_error_block.call(430, "Flow Failed")
            unless @drop_response
              @request.reply 430, "Flow Failed"
            else
              @drop_response = false
            end
          else
            log_system_debug "flow failed for received ACK"  if $oversip_debug
          end
        end

        return
      end


      # If it's not an incoming Outbound connection (or explicit destination is set),
      # let's perform RFC 3263 procedures.

      # Check the request destination.
      # If a destination is given use it. If not route based on request headers.

      # Force the destination.
      if dst_host
        dst_scheme = :sip
        dst_host_type = ::OverSIP::Utils.ip_type(dst_host) || :domain

      # Or use top Route header.
      elsif @request.routes
        top_route = @request.routes[0]
        dst_scheme = top_route.scheme
        dst_host = top_route.host
        dst_host_type = top_route.host_type
        dst_port = top_route.port
        dst_transport = top_route.transport_param

      # Or use the Request URI.
      else
        dst_scheme = @request.ruri.scheme
        dst_host = @request.ruri.host
        dst_host_type = @request.ruri.host_type
        dst_port = @request.ruri.port
        dst_transport = @request.ruri.transport_param
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
      dns_query = ::OverSIP::SIP::RFC3263::Query.new @proxy_conf, @request.via_branch_id, dst_scheme, dst_host, dst_host_type, dst_port, dst_transport
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

    end  # def route


    def receive_response response
      log_system_debug "received response #{response.status_code}"  if $oversip_debug

      response.delete_header_top "Via"

      if @request.server_transaction.valid_response? response.status_code
        if response.status_code < 200 && ! @canceled
          @on_provisional_response_block && @on_provisional_response_block.call(response)
        elsif response.status_code >= 200 && response.status_code <= 299
          @on_success_response_block && @on_success_response_block.call(response)
        elsif response.status_code >= 300 && ! @canceled
          if response.status_code == 503
            if @proxy_conf[:dns_failover_on_503]
              try_next_target nil, nil, response
              return
            else
              # If the response is 503 convert it into 500 (RFC 3261 16.7).
              response.status_code = 500
              @on_failure_response_block && @on_failure_response_block.call(response)
            end
          else
            @on_failure_response_block && @on_failure_response_block.call(response)
          end
        end
      end

      unless @drop_response
        @request.reply_full response
      else
        @drop_response = false
      end
    end


    # Since we don't implement parallel forking, directly send our CANCEL downstream.
    def receive_cancel cancel
      log_system_debug "server transaction canceled, cancelling pending client transaction"  if $oversip_debug

      @canceled = true
      @on_canceled_block && @on_canceled_block.call

      @client_transaction.do_cancel cancel
    end


    def client_timeout
      try_next_target 408, "Client Timeout"
    end


    def connection_failed
      try_next_target 500, "Connection Error"
    end


    def tls_validation_failed
      try_next_target 500, "TLS Validation Failed"
    end


    # Timer C for INVITE.
    def invite_timeout
      @on_invite_timeout_block && @on_invite_timeout_block.call

      unless @drop_response
        @request.reply 408, "INVITE Timeout"
      end
      @drop_response = true  # Ignore the possible 487 got from the callee.
    end


    private


    def add_routing_headers
      # Don't add routing headers again if we are in DNS failover within the same Proxy instance.
      # But we must run this method if it's an incoming request asking for Outbound usage (in this
      # case @num_target is nil so the method continues).
      return  if @num_target and @num_target > 0

      add_rr_path = false

      # NOTE: As per RFC 6665 the proxy MUST add Record-Route to in-dialog NOTIFY's.
      if (@request.initial? and @request.loose_record_aware?) or @request.sip_method == :NOTIFY
        do_loose_routing = @proxy_conf[:do_loose_routing]

        # Request has no previous RR/Path and current proxy performs loose-routing.
        # So add RR/Path.
        if ! @request.in_rr && do_loose_routing
          add_rr_path = true

        # Request has previous RR/Path and current proxy does not perform loose-routing.
        # So don't add RR/Path and remove the existing one.
        elsif @request.in_rr && ! do_loose_routing
          case @request.in_rr
          when :rr, :outgoing_outbound_rr, :incoming_outbound_rr, :both_outbound_rr
            @request.delete_header_top "Record-Route"
          when :path, :outgoing_outbound_path, :incoming_outbound_path, :both_outbound_path
            @request.delete_header_top "Path"
          end
          @request.in_rr = nil

        # Remaining cases are:
        # - Request has previous RR/Path and current proxy performs loose-routing.
        # - Request has no previous RR/Path and current proxy does not perform loose-routing.
        # So don't add RR/Path.
        end
      end

      unless @request.proxied
        # Indicate that this request has been proxied (at least once).
        @request.proxied = true

        # Set the Max-Forwards header.
        @request.headers["Max-Forwards"] = [ @request.new_max_forwards.to_s ]  if @request.new_max_forwards
      end

      # Add Record-Route or Path header.
      # Here we only arrive if @request.loose_record_aware?.
      if add_rr_path
        case @request.sip_method

        # Path header (RFC 3327) for REGISTER.
        when :REGISTER
          if @request.outgoing_outbound_requested?
            if @request.incoming_outbound_requested?
              @request.in_rr = :both_outbound_path
            else
              @request.in_rr = :outgoing_outbound_path
            end
            @request.insert_header "Path", "<sip:" << @request.connection_outbound_flow_token << @request.connection.class.outbound_path_fragment
          elsif @request.incoming_outbound_requested?
            @request.in_rr = :incoming_outbound_path
            @request.insert_header "Path", @request.connection.class.record_route
          else
            @request.in_rr = :path
            @request.insert_header "Path", @request.connection.class.record_route
          end

        # Record-Route for INVITE, SUBSCRIBE, REFER and in-dialog NOTIFY.
        else
          if @request.outgoing_outbound_requested?
            if @request.incoming_outbound_requested?
              @request.in_rr = :both_outbound_rr
            else
              @request.in_rr = :outgoing_outbound_rr
            end
            @request.insert_header "Record-Route", "<sip:" << @request.connection_outbound_flow_token << @request.connection.class.outbound_record_route_fragment
          elsif @request.incoming_outbound_requested?
            @request.in_rr = :incoming_outbound_rr
            @request.insert_header "Record-Route", @request.connection.class.record_route
          else
            @request.in_rr = :rr
            @request.insert_header "Record-Route", @request.connection.class.record_route
          end

        end
      end

    end  # add_routing_headers


    def rfc3263_succeeded result
      #log_system_debug "RFC3263 result: #{result.class}: #{result.inspect}"  if $oversip_debug

      # After RFC 3263 (DNS) resolution we get N targets.
      @num_target = 0  # First target is 0 (rather than 1).

      case result

      when RFC3263::Target
        @target = result  # Single Target.

      when RFC3263::SrvTargets
        log_system_debug "result is srv targets => randomizing:"  if $oversip_debug
        @targets = result.randomize  # Array of Targets.

      # This can contain Target and SrvTargets entries.
      when RFC3263::MultiTargets
        log_system_debug "result is MultiTargets => flatting:"  if $oversip_debug
        @targets = result.flatten  # Array of Targets.

      # NOTE: Should never happen.
      else
        raise "rfc3263_succeeded returns a #{result.class}: #{result.inspect}"

      end

      try_next_target
    end  # rfc3263_succeeded


    def try_next_target status=nil, reason=nil, full_response=nil
      # Single target.
      if @target and @num_target == 0
        log_system_debug "using single target: #{@target}"  if $oversip_debug
        use_target @target
        @num_target = 1

      # Multiple targets (so @targets is set).
      elsif @targets and @num_target < @targets.size
        log_system_debug "using target #{@num_target+1} of #{@targets.size}: #{@targets[@num_target]}"  if $oversip_debug
        use_target @targets[@num_target]
        @num_target += 1

      # No more targets.
      else
        # If we have received a [3456]XX response from downstream then run @on_failure_block.
        if full_response
          @on_failure_response_block && @on_failure_response_block.call(full_response)
          unless @drop_response
            # If the response is 503 convert it into 500 (RFC 3261 16.7).
            full_response.status_code = 500  if full_response.status_code == 503
            @request.reply_full full_response
          else
            @drop_response = false
          end

        # If not, generate the response according to the given status and reason.
        else
          @on_error_block && @on_error_block.call(status, reason)
          unless @drop_response
            @request.reply status, reason
          else
            @drop_response = false
          end

        end
      end
    end  # try_next_target


    def use_target target
      @client_transaction = (::OverSIP::SIP::ClientTransaction.get_class @request).new self, @request, @proxy_conf, target.transport, target.ip, target.ip_type, target.port
      add_routing_headers
      @client_transaction.send_request
    end


    def rfc3263_failed error
      case error
        when :rfc3263_domain_not_found
          log_system_debug "no resolution"  if $oversip_debug
          status = 404
          reason = "No DNS Resolution"
        when :rfc3263_unsupported_scheme
          log_system_debug "unsupported URI scheme"  if $oversip_debug
          status = 416
          reason = "Unsupported URI scheme"
        when :rfc3263_unsupported_transport
          log_system_debug "unsupported transport"  if $oversip_debug
          status = 478
          reason = "Unsupported Transport"
        when :rfc3263_wrong_transport
          log_system_debug "wrong URI transport"  if $oversip_debug
          status = 478
          reason = "Wrong URI Transport"
        when :rfc3263_no_ipv4
          log_system_debug "destination requires unsupported IPv4"  if $oversip_debug
          status = 478
          reason = "Destination Requires Unsupported IPv4"
        when :rfc3263_no_ipv6
          log_system_debug "destination requires unsupported IPv6"  if $oversip_debug
          status = 478
          reason = "Destination Requires Unsupported IPv6"
        when :rfc3263_no_dns
          log_system_debug "destination requires unsupported DNS query"  if $oversip_debug
          status = 478
          reason = "Destination Requires Unsupported DNS Query"
        end

        @on_error_block && @on_error_block.call(status, reason)
        unless @drop_response
          @request.reply status, reason  unless @request.sip_method == :ACK
        else
          @drop_response = false
        end
    end  # def rfc3263_failed

  end  # class Proxy

end