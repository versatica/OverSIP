module OverSIP::SIP

  module RFC3263

    Target = ::Struct.new(:transport, :ip, :ip_type, :port)

    class Target
      def to_s
        if self[2] == :ipv4
          "#{self[0]}:#{self[1]}:#{self[3]}"
        else
          "#{self[0]}:[#{self[1]}]:#{self[3]}"
        end
      end
    end

    # This is the object returned by Query#resolve.
    class SrvTargets < ::Array

      # Returns a SrvRandomizedTargets instance.
      def randomize
        ordered_targets = SrvRandomizedTargets.allocate

        self.each do |entries|
          if entries.size == 1
            entries[0].targets.each {|e| ordered_targets << e}
          else
            randomize_entries(entries.select {|e| e.weight > 0}, ordered_targets)
            entries.select {|e| e.weight.zero?}.shuffle.each {|e| ordered_targets << e[1]}
          end
        end

        return ordered_targets
      end

      def randomize_entries(entries, ordered_targets)
        total_weight = 0
        entries.each {|e| total_weight += e[0]}
        rnd = rand(total_weight)

        i=0
        entries.each do |entry|
          if rnd < entry.weight
            entry.targets.each {|v| ordered_targets << v}
            entries.delete_at i
            break
          else
            rnd -= entry.weight
            i += 1
          end
        end

        randomize_entries(entries, ordered_targets) unless entries.size.zero?
      end
      private :randomize_entries

    end  # class SrvTargets

    SrvWeightTarget = ::Struct.new(:weight, :targets)

    # This is the object the method SrvTargets#randomize returns.
    class SrvRandomizedTargets < ::Array ; end

    class MultiTargets < ::Array
      attr_accessor :has_srv_weight_targets

      def flatten
        return self  unless @has_srv_weight_targets

        targets = []
        self.each do |entry|
          if entry.is_a? RFC3263::Target
            targets << entry
          # If not, it's a SrvTargets.
          else
            targets.concat entry.randomize
          end
        end
        targets
      end

    end

    # Some constans for efficience.
    UDP = "udp"
    TCP = "tcp"
    TLS = "tls"
    SIP =" sip"
    SIPS = "sips"
    SIP_D2U = "SIP+D2U"
    SIP_D2T = "SIP+D2T"
    SIPS_D2T = "SIPS+D2T"
    TRANSPORT_TO_SERVICE = { :tls=>SIPS_D2T, :tcp=>SIP_D2T, :udp=>SIP_D2U }


    def self.module_init
      nameservers = ::OverSIP.configuration[:core][:nameservers]
      ::EM::Udns.nameservers = nameservers  if nameservers
      @@resolver = ::EM::Udns::Resolver.new
      ::OverSIP::SIP::RFC3263::Query.class_init
    end


    def self.run
      ::EM::Udns.run @@resolver
    end


    def self.resolver
      @@resolver
    end


    class Query
      include ::OverSIP::Logger

      def self.class_init
        @@fiber_pool = ::OverSIP::FiberPool.new 50
      end

      def initialize dns_conf, id, uri_scheme, uri_host, uri_host_type, uri_port=nil, uri_transport=nil
        @id = id
        @uri_scheme = uri_scheme
        @uri_host = uri_host
        @uri_host_type = uri_host_type
        @uri_port = uri_port
        @uri_transport = uri_transport

        @log_id ||= ("RFC3263" << " " << @id)

        @use_dns = dns_conf[:use_dns]
        @transport_preference = dns_conf[:transport_preference]

        @has_sip_ipv4 = dns_conf[:has_sip_ipv4]
        @has_sip_ipv6 = dns_conf[:has_sip_ipv6]
        @has_sip_udp = dns_conf[:has_sip_udp]
        @has_sip_tcp = dns_conf[:has_sip_tcp]
        @has_sip_tls = dns_conf[:has_sip_tls]

        # Just initialize these attributes if URI host is a domain.
        if uri_host_type == :domain
          @ip_type_preference = dns_conf[:ip_type_preference]
          @force_transport_preference = dns_conf[:force_transport_preference]
          @use_naptr = dns_conf[:use_naptr]
          @use_srv = dns_conf[:use_srv]
        end
      end

      def callback &block
        @on_success_block = block
      end

      def errback &block
        @on_error_block = block
      end

      # This method can return:
      # - Target: in case host is a IP.
      # - SrvTargets: in case SRV took place. Then the client must use SrvTargets#randomize
      #   and get a SrvRandomizedTargets (an Array of Target entries).
      # - MultiTargets: so each element can be one of the above elements.
      # - nil: result will be retrieved via callback/errback.
      # - Symbol: there is some error (domain does not exist, no records, IP is IPv6
      #   but we don't support it, invalid transport...).
      def resolve
        if not @use_dns and @uri_host_type == :domain
          return :rfc3263_no_dns
        end

        case @uri_scheme
        when :sip
        when :sips
          # If URI scheme is :sips and we don't support TLS then reject it.
          return :rfc3263_unsupported_scheme  unless @has_sip_tls
        else
          return :rfc3263_unsupported_scheme
        end

        dns_transport = nil
        dns_port = @uri_port

        # dns_transport means the transport type taken from the destination SIP URI.
        # If @uri_scheme is :sips and no @uri_transport is given (or it's :tcp), then
        # dns_transport is :tls.
        # So dns_transport can be :udp, :tcp or :tls, while @uri_transport should not be
        # :tls (according to RFC 3261) in case scheme is :sips, and maybe :udp, :tcp, :sctp
        # or whatever token. In case scheme is :sip then @uri_transport can be :tls so
        # dns_transport would be :tls.

        ### First select @transport.

        # If it's a domain with no port nor ;transport, then
        # transport will be inspected later with NAPTR.
        if not @uri_transport and ( @uri_host_type != :domain or @uri_port )
          case @uri_scheme
          when :sip
            if @has_sip_udp
              dns_transport = :udp
            # In case we don't support UDP then use TCP (why not? local policy).
            elsif @has_sip_tcp
              dns_transport = :tcp
            else
              return :rfc3263_unsupported_transport
            end
          when :sips
            dns_transport = :tls
          end
        end

        # If the URI has ;transport param, then set dns_transport.
        if @uri_transport
          case @uri_transport
          when :udp
            return :rfc3263_unsupported_transport  unless @has_sip_udp
            if @uri_scheme == :sip
              dns_transport = :udp
            # "sips" is not possible in UDP.
            else
              return :rfc3263_wrong_transport
            end
          when :tcp
            case (dns_transport = ( @uri_scheme == :sips ? :tls : :tcp ))
              when :tcp ; return :rfc3263_unsupported_transport  unless @has_sip_tcp
              when :tls ; return :rfc3263_unsupported_transport  unless @has_sip_tls
              end
          when :tls
            return :rfc3263_unsupported_transport  unless @has_sip_tls
            dns_transport = :tls
          else
            return :rfc3263_unsupported_transport
          end
        end

        # If URI host is an IP, no DNS query must be done (so no Ruby Fiber must be created).
        unless @uri_host_type == :domain
          if @uri_host_type == :ipv4 and not @has_sip_ipv4
            return :rfc3263_no_ipv4
          elsif @uri_host_type == :ipv6 and not @has_sip_ipv6
            return :rfc3263_no_ipv6
          end

          dns_port ||= 5061 if dns_transport == :tls
          dns_port ||= case @uri_scheme
            when :sip  ; 5060
            when :sips ; 5061
          end

          return Target.new(dns_transport, @uri_host, @uri_host_type, dns_port)
        end


        # URI host is domain so at least a DNS query must be performed.
        # Let's create/use a Fiber then.
        @@fiber_pool.spawn do

          # If URI port is specified perform DNS A/AAAA (then transport has been
          # already set above).
          if @uri_port
            if (targets = resolve_A_AAAA(dns_transport, @uri_host, dns_port))
              if targets.size == 1
                @on_success_block && @on_success_block.call(targets[0])
              else
                @on_success_block && @on_success_block.call(targets)
              end
            else
              @on_error_block && @on_error_block.call(:rfc3263_domain_not_found)
            end


          # If the URI has no port but has ;transport param, then DNS SRV takes place.
          elsif @uri_transport
            if @use_srv
              if (targets = resolve_SRV(@uri_host, @uri_scheme, dns_transport))
                ### TODO: Esto es nuevo para mejora. Antes devolvía siempre el segundo caso.
                if targets.size == 1
                  @on_success_block && @on_success_block.call(targets[0])
                else
                  @on_success_block && @on_success_block.call(targets)
                end
              else
                @on_error_block && @on_error_block.call(:rfc3263_domain_not_found)
              end

            # If @use_srv is false then perform A/AAAA queries.
            else
              log_system_debug "SRV is disabled, performing A/AAAA queries"  if $oversip_debug

              port = 5061 if dns_transport == :tls
              port ||= case @uri_scheme
                when :sip  ; 5060
                when :sips ; 5061
              end

              if (targets = resolve_A_AAAA(dns_transport, @uri_host, port))
                if targets.size == 1
                  @on_success_block && @on_success_block.call(targets[0])
                else
                  @on_success_block && @on_success_block.call(targets)
                end
              else
                @on_error_block && @on_error_block.call(:rfc3263_domain_not_found)
              end

            end


          # If not, the URI has no port neither ;transport param. NAPTR is required.
          else
            # If @use_naptr is false then NAPTR must not be performed.
            if ! @use_naptr
              if @use_srv
                log_system_debug "NAPTR is disabled, performing SRV queries"  if $oversip_debug
                continue_with_SRV

              # If @use_srv is false then perform A/AAAA queries.
              else
                log_system_debug "NAPTR and SRV are disabled, performing A/AAAA queries"  if $oversip_debug
                case @uri_scheme
                when :sip
                  if @has_sip_udp
                    dns_transport = :udp
                    port = 5060
                  # In case we don't support UDP then use TCP (why not? local policy).
                  elsif @has_sip_tcp
                    dns_transport = :tcp
                    port = 5060
                  else
                    @on_error_block && @on_error_block.call(:rfc3263_unsupported_transport)
                  end
                when :sips
                  dns_transport = :tls
                  port = 5061
                end

                if (targets = resolve_A_AAAA(dns_transport, @uri_host, port))
                  if targets.size == 1
                    @on_success_block && @on_success_block.call(targets[0])
                  else
                    @on_success_block && @on_success_block.call(targets)
                  end
                else
                  @on_error_block && @on_error_block.call(:rfc3263_domain_not_found)
                end

              end

            # There are NAPTR records so inspect them (note that there still could be no valid SIP NAPTR records
            # so SRV should take place).
            elsif (naptrs = sync_resolve_NAPTR(@uri_host))

              # If URI scheme is :sips just SIPS+D2T must be searched.
              naptrs.select! do |naptr|
                naptr.flags.downcase == "s" and
                ( (@has_sip_tls and naptr.service.upcase == SIPS_D2T) or
                  (@uri_scheme == :sip and @has_sip_tcp and naptr.service.upcase == SIP_D2T) or
                  (@uri_scheme == :sip and @has_sip_udp and naptr.service.upcase == SIP_D2U) )
              end

              # There are NAPTR records, but not for SIP (or not for SIPS+D2T in case the URI scheme is :sips).
              # So perform SRV queries.
              if naptrs.empty?
                log_system_debug "cannot get valid NAPTR SIP records, performing SRV queries"  if $oversip_debug
                continue_with_SRV

              # There are NAPTR records for SIP.
              else
                # @force_transport_preference is false so let's use NAPTR preferences.
                unless @force_transport_preference
                  # Order based on RR order and preference (just a bit).
                  ordered_naptrs = naptrs.sort { |x,y| (x.order <=> y.order).nonzero? or y.preference <=> x.preference }

                # @force_transport_preference is true so let's use @transport_preference for ordering the records.
                else
                  ordered_naptrs = []
                  @transport_preference.each do |transport|
                    service = TRANSPORT_TO_SERVICE[transport]
                    ordered_naptrs.concat(naptrs.select { |naptr| naptr.service.upcase == service })
                  end

                end

                srv_targets = MultiTargets.allocate
                ordered_naptrs.each do |naptr|
                  naptr_transport = case naptr.service.upcase
                    when SIPS_D2T ; :tls
                    when SIP_D2T  ; :tcp
                    when SIP_D2U  ; :udp
                    end
                  if (result = resolve_SRV(naptr.replacement, nil, nil, naptr_transport))
                    case result
                    when RFC3263::SrvTargets
                      srv_targets << result
                      srv_targets.has_srv_weight_targets = true
                    # A RFC3263::MultiTargets or an array of RFC3263::Target.
                    when RFC3263::MultiTargets, ::Array
                      srv_targets.concat result
                    end
                  end
                end

                if srv_targets.size == 1
                  @on_success_block && @on_success_block.call(srv_targets[0])
                else
                  @on_success_block && @on_success_block.call(srv_targets)
                end

              end

            # There are not NAPTR records, so try SRV records in preference order.
            else
              log_system_debug "no NAPTR records, performing SRV queries"  if $oversip_debug
              continue_with_SRV

            end

          end

        end

        nil
      end


      def continue_with_SRV
        srv_targets = MultiTargets.allocate
        @transport_preference.each do |transport|
          next if @uri_scheme == :sips and (transport == :udp or transport == :tcp)

          if (result = resolve_SRV(@uri_host, @uri_scheme, transport, transport))
            case result
            when RFC3263::SrvTargets
              srv_targets << result
              srv_targets.has_srv_weight_targets = true
            # A RFC3263::MultiTargets or an array of RFC3263::Target.
            when RFC3263::MultiTargets, ::Array
              srv_targets.concat result
            end
          end
        end

        if srv_targets.size == 1
          @on_success_block && @on_success_block.call(srv_targets[0])

        elsif srv_targets.size > 1
          @on_success_block && @on_success_block.call(srv_targets)

        # If not, make A/AAAA query.
        else
          log_system_debug "no valid SRV targets, performing A/AAAA queries"  if $oversip_debug
          case @uri_scheme
          when :sip
            transport = :udp  if @has_sip_udp
            transport ||= :tcp  if @has_sip_tcp
            unless transport
              @on_error_block && @on_error_block.call(:rfc3263_unsupported_transport)
              return
            end
            port = 5060
          when :sips
            transport = :tls
            port = 5061
          end

          if targets = resolve_A_AAAA(transport, @uri_host, port)
            if targets.size == 1
              @on_success_block && @on_success_block.call(targets[0])
            else
              @on_success_block && @on_success_block.call(targets)
            end
          else
            @on_error_block && @on_error_block.call(:rfc3263_domain_not_found)
          end
        end
      end
      private :continue_with_SRV


      def resolve_A_AAAA transport, domain, port
        ips = {}

        # DNS A.
        if @has_sip_ipv4
          ips[:ipv4] = sync_resolve_A(domain)
        end

        # DNS AAAA.
        if @has_sip_ipv6
          ips[:ipv6] = sync_resolve_AAAA(domain)
        end

        targets = MultiTargets.allocate
        @ip_type_preference.each do |ip_type|
          ips[ip_type].each do |ip|
            targets << RFC3263::Target.new(transport, ip, ip_type, port)
          end if ips[ip_type]
        end

        return case targets.size
          when 0 ; nil
          else   ; targets
          end

      end
      private :resolve_A_AAAA


      def resolve_SRV domain, scheme=nil, transport=nil, naptr_transport=nil
        # If there is not SRV records, perform A/AAAA query for the URI host.
        unless srvs = sync_resolve_SRV(domain, scheme, transport)
          # If the query comes from the NAPTR section don't do A/AAAA.
          return nil  if naptr_transport

          port = 5061 if transport == :tls
          port ||= case scheme
            when :sip  ; 5060
            when :sips ; 5061
          end

          return resolve_A_AAAA(transport, domain, port)

        # There are SRV records, so perform A/AAAA queries for every record.
        else
          srv_targets = SrvTargets.allocate

          srvs.each do |srv|
            srv_targets[srv.priority] ||= []

            if targets = resolve_A_AAAA(naptr_transport || transport, srv.domain, srv.port)
              srv_targets[srv.priority] << SrvWeightTarget.new(srv.weight, targets)
            end
          end

          # Remove multiple array entries with null value and return nil if got SRV RR have
          # domain with no A/AAAA resolution.
          srv_targets.select! {|e| e and e.size > 0}

          return nil if srv_targets.empty?

          if srv_targets.size == 1 and srv_targets[0].size == 1
            return srv_targets[0][0].targets
          else
            return srv_targets
          end
        end
      end
      private :resolve_SRV


      def sync_resolve_NAPTR domain
        f = Fiber.current

        query = RFC3263.resolver.submit_NAPTR domain
        query.callback do |result|
          log_system_debug "DNS NAPTR succeeded for '#{domain}'"  if $oversip_debug
          f.resume result
        end
        query.errback do |result|
          log_system_debug "DNS NAPTR error resolving '#{domain}': #{result}"  if $oversip_debug
          f.resume nil
        end

        Fiber.yield
      end
      private :sync_resolve_NAPTR


      def sync_resolve_SRV domain, service=nil, protocol=nil
        f = Fiber.current

        if service == :sip and protocol == :tls
          service = SIPS
        elsif service
          service = service.to_s
        end

        protocol = case protocol
          when :udp ; UDP
          when :tcp, :tls ; TCP
          end

        query = RFC3263.resolver.submit_SRV domain, service, protocol
        query.callback do |result|
          if service
            log_system_debug "DNS SRV succeeded for domain '#{domain}', service '#{service}' and protocol '#{protocol}'"  if $oversip_debug
          else
            log_system_debug "DNS SRV succeeded for '#{domain}'"  if $oversip_debug
          end
          f.resume result
        end
        query.errback do |result|
          if service
            log_system_debug "DNS SRV error resolving domain '#{domain}', service '#{service}' and protocol '#{protocol}': #{result}"  if $oversip_debug
          else
            log_system_debug "DNS SRV error resolving '#{domain}': #{result}"  if $oversip_debug
          end
          f.resume nil
        end

        Fiber.yield
      end
      private :sync_resolve_SRV


      def sync_resolve_A domain
        f = Fiber.current

        query = RFC3263.resolver.submit_A domain
        query.callback do |result|
          log_system_debug "DNS A succeeded for domain '#{domain}'"  if $oversip_debug
          f.resume result
        end
        query.errback do |result|
          log_system_debug "DNS A error resolving domain '#{domain}': #{result}"  if $oversip_debug
          f.resume nil
        end

        Fiber.yield
      end
      private :sync_resolve_A


      def sync_resolve_AAAA domain
        f = Fiber.current

        query = RFC3263.resolver.submit_AAAA domain
        query.callback do |result|
          log_system_debug "DNS AAAA succeeded for domain '#{domain}'"  if $oversip_debug
          f.resume result
        end
        query.errback do |result|
          log_system_debug "DNS AAAA error resolving domain '#{domain}': #{result}"  if $oversip_debug
          f.resume nil
        end

        Fiber.yield
      end
      private :sync_resolve_AAAA

    end # class Query

  end  # module RFC3263

end

