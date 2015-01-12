module OverSIP::SIP

  class Proxy < Client

    # If a SIP response is given then this method may offer other features such as replying 199.
    def drop_response response=nil
      @drop_response = true

      # RFC 6228 (199 response).
      # http://tools.ietf.org/html/rfc6228#section-6
      if response and response.status_code >= 300 and
         @request.sip_method == :INVITE and
         @request.supported and @request.supported.include?("199")

        @request.send :reply_199, response
      end
    end


    def route request, dst_host=nil, dst_port=nil, dst_transport=nil
      unless (@request = request).is_a? ::OverSIP::SIP::Request
        raise ::OverSIP::RuntimeError, "request must be a OverSIP::SIP::Request instance"
      end

      @log_id = "Proxy #{@conf[:name]} #{@request.via_branch_id}"

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
        @client_transaction = (::OverSIP::SIP::ClientTransaction.get_class @request).new self, @request, @conf, @request.route_outbound_flow_token

        if @client_transaction.connection
          add_routing_headers
          @client_transaction.send_request
        else
          unless @request.sip_method == :ACK
            log_system_debug "flow failed"  if $oversip_debug

            run_on_error_cbs 430, "Flow Failed", :flow_failed
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

      response.delete_header_top "Via"

      if @request.server_transaction.valid_response? response.status_code
        if response.status_code < 200 && ! @canceled
          run_on_provisional_response_cbs response
        elsif response.status_code >= 200 && response.status_code <= 299
          run_on_success_response_cbs response
        elsif response.status_code >= 300 && ! @canceled
          if response.status_code == 503
            if @conf[:dns_failover_on_503]
              try_next_target nil, nil, response
              return
            else
              # If the response is 503 convert it into 500 (RFC 3261 16.7).
              response.status_code = 500
              run_on_failure_response_cbs response
            end
          else
            run_on_failure_response_cbs response
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
      run_on_canceled_cbs

      @client_transaction.do_cancel cancel
    end


    # Timer C for INVITE (method called by the client transaction).
    def invite_timeout
      run_on_invite_timeout_cbs

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
      return  if @num_target and @num_target > 1

      add_rr_path = false

      # NOTE: As per RFC 6665 the proxy MUST add Record-Route to in-dialog NOTIFY's.
      if (@request.initial? and @request.record_routing_aware?) or @request.sip_method == :NOTIFY or @conf[:record_route_all]
        do_record_routing = @conf[:do_record_routing]

        # Request has no previous RR/Path and current proxy performs record-routing.
        # So add RR/Path.
        if ! @request.in_rr && do_record_routing
          add_rr_path = true

        # Request has previous RR/Path and current proxy does not perform record-routing.
        # So don't add RR/Path and remove the existing one.
        elsif @request.in_rr && ! do_record_routing
          case @request.in_rr
          when :rr, :outgoing_outbound_rr, :incoming_outbound_rr, :both_outbound_rr
            @request.delete_header_top "Record-Route"
          when :path, :outgoing_outbound_path, :incoming_outbound_path, :both_outbound_path
            @request.delete_header_top "Path"
          end
          @request.in_rr = nil

        # Remaining cases are:
        # - Request has previous RR/Path and current proxy performs record-routing.
        # - Request has no previous RR/Path and current proxy does not perform record-routing.
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
            # The request comes via UDP or via a connection made by the client.
            if @request.connection.class.outbound_listener?
              @request.insert_header "Path", @request.connection.class.record_route
            # The request comes via a TCP/TLS connection made by OverSIP.
            else
              @request.insert_header "Path", @request.connection.record_route
            end
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
            # The request comes via UDP or via a connection made by the client.
            if @request.connection.class.outbound_listener?
              @request.insert_header "Record-Route", @request.connection.class.record_route
            # The request comes via a TCP/TLS connection made by OverSIP.
            else
              @request.insert_header "Record-Route", @request.connection.record_route
            end
          else
            @request.in_rr = :rr
            # The request comes via UDP or via a connection made by the client.
            if @request.connection.class.outbound_listener?
              @request.insert_header "Record-Route", @request.connection.class.record_route
            # The request comes via a TCP/TLS connection made by OverSIP.
            else
              @request.insert_header "Record-Route", @request.connection.record_route
            end
          end

        end
      end

    end  # add_routing_headers


    def no_more_targets status, reason, full_response, code
      # If we have received a [3456]XX response from downstream then run @on_failure_response_cbs.
      if full_response
        run_on_failure_response_cbs full_response
        unless @drop_response
          # If the response is 503 convert it into 500 (RFC 3261 16.7).
          full_response.status_code = 500  if full_response.status_code == 503
          @request.reply_full full_response
        else
          @drop_response = false
        end

      # If not, generate the response according to the given status and reason.
      else
        run_on_error_cbs status, reason, code
        unless @drop_response
          @request.reply status, reason
        else
          @drop_response = false
        end

      end
    end  # no_more_targets


    def do_dns_fail status, reason, code
      run_on_error_cbs status, reason, code

      unless @drop_response
        @request.reply status, reason  unless @request.sip_method == :ACK
      else
        @drop_response = false
      end
    end


  end  # class Proxy

end
