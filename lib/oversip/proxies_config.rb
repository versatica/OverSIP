module OverSIP

  module ProxiesConfig

    extend ::OverSIP::Logger
    extend ::OverSIP::Config::Validators

    def self.log_id
      @log_id ||= "ProxiesConfig"
    end

    @proxy_configuration = {
      :do_record_routing          => true,
      :use_dns                    => true,
      :use_dns_cache              => true,
      :dns_cache_time             => 300,
      :use_naptr                  => true,
      :use_srv                    => true,
      :transport_preference       => ["tls", "tcp", "udp"],
      :force_transport_preference => false,
      :ip_type_preference         => ["ipv6", "ipv4"],
      :dns_failover_on_503        => true,
      :timer_B                    => 32,
      :timer_C                    => 120,
      :timer_F                    => 32,
      :callback_on_server_tls_handshake => true
    }

    PROXY_CONFIG_VALIDATIONS = {
      :do_record_routing          => :boolean,
      :use_dns                    => :boolean, 
      :use_dns_cache              => :boolean,
      :dns_cache_time             => [ :fixnum, [ :greater_equal_than, 300 ] ],
      :use_naptr                  => :boolean,
      :use_srv                    => :boolean,
      :transport_preference       => [ [ :choices, %w{tls tcp udp}], :multi_value, :non_empty ],
      :force_transport_preference => :boolean,
      :ip_type_preference         => [ [ :choices, %w{ipv4 ipv6}], :multi_value, :non_empty ],
      :dns_failover_on_503        => :boolean,
      :timer_B                    => [ :fixnum, [ :greater_equal_than, 2 ], [ :minor_equal_than, 64 ] ],
      :timer_C                    => [ :fixnum, [ :greater_equal_than, 8 ], [ :minor_equal_than, 180 ] ],
      :timer_F                    => [ :fixnum, [ :greater_equal_than, 2 ], [ :minor_equal_than, 64 ] ],
      :callback_on_server_tls_handshake => :boolean
    }

    def self.load proxies_yaml, reload=false
      begin
        unless proxies_yaml.is_a? ::Hash
          raise "invalid proxies configuration file, it is not a collection"
        end

        proxies = {}

        proxies_yaml.each do |proxy, conf|
          unless proxy.is_a? ::String
            raise "proxy name is not a string (#{proxy.inspect})"
          end

          proxies[proxy.to_sym] = @proxy_configuration.dup
          proxies[proxy.to_sym].each do |parameter, default_value|
            proxies[proxy.to_sym][parameter] = default_value.clone rescue default_value
          end

          PROXY_CONFIG_VALIDATIONS.each do |parameter, validations|
            values = proxies_yaml[proxy][parameter.to_s]
            validations = [ validations ]  unless validations.is_a?(::Array)

            if values == nil
              if validations.include? :required
                raise "#{proxy}[#{parameter}] requires a value"
              end
              next
            end

            if values.is_a? ::Array
              unless validations.include? :multi_value
                raise "#{proxy}[#{parameter}] does not allow multiple values"
              end

              if validations.include? :non_empty and values.empty?
                raise "#{proxy}[#{parameter}] does not allow empty values"
              end
            end

            values = ( values.is_a?(::Array) ? values : [ values ] )

            values.each do |value|
              validations.each do |validation|

                if validation.is_a? ::Symbol
                  args = []
                elsif validation.is_a? ::Array
                  args = validation[1..-1]
                  validation = validation[0]
                end

                next if [:required, :multi_value, :non_empty].include? validation

                unless send validation, value, *args
                  raise "#{proxy}[#{parameter}] has invalid value '#{::OverSIP::Config.humanize_value value}' (does not satisfy '#{validation}' validation requirement)"
                end
              end

              proxies[proxy.to_sym][parameter] = ( validations.include?(:multi_value) ? values : values[0] )
            end

          end  # PROXY_CONFIG_VALIDATIONS[section].each
        end  # proxies_yaml.each

      rescue ::Exception => e
        unless reload
          ::OverSIP::Launcher.fatal e.message
        else
          raise ::OverSIP::ConfigurationError, e.message
        end
      end

      @proxies = proxies
      post_process

      ::OverSIP.proxies = @proxies
    end


    def self.post_process
      @proxies.each_key do |proxy|
        # Add a string parameter with the proxy name itself.
        @proxies[proxy][:name] = proxy.to_s

        # If use_srv is not set then ensure use_naptr is also not set.
        @proxies[proxy][:use_naptr] = false  unless @proxies[proxy][:use_srv]

        # Convert transport values into Symbols.
        @proxies[proxy][:transport_preference] = @proxies[proxy][:transport_preference].map do |transport|
          transport.to_sym
        end

        # Ensure there are not duplicate transports.
        @proxies[proxy][:transport_preference].uniq!

        # Remove transports that are not supported.
        @proxies[proxy][:transport_preference].delete :tls  unless ::OverSIP.configuration[:sip][:sip_tls]
        @proxies[proxy][:transport_preference].delete :tcp  unless ::OverSIP.configuration[:sip][:sip_tcp]
        @proxies[proxy][:transport_preference].delete :udp  unless ::OverSIP.configuration[:sip][:sip_udp]

        # Convert IP type values into Symbols.
        @proxies[proxy][:ip_type_preference] = @proxies[proxy][:ip_type_preference].map do |ip_type|
          ip_type.to_sym
        end

        # Ensure there are not duplicate IP types.
        @proxies[proxy][:ip_type_preference].uniq!

        # Remove IP types that are not supported.
        @proxies[proxy][:ip_type_preference].delete :ipv4  unless ::OverSIP.configuration[:sip][:listen_ipv4]
        @proxies[proxy][:ip_type_preference].delete :ipv6  unless ::OverSIP.configuration[:sip][:listen_ipv6]

        # Add new parameters for fast access.
        @proxies[proxy][:has_sip_ipv4] = @proxies[proxy][:ip_type_preference].include?(:ipv4)
        @proxies[proxy][:has_sip_ipv6] = @proxies[proxy][:ip_type_preference].include?(:ipv6)
        @proxies[proxy][:has_sip_udp] = @proxies[proxy][:transport_preference].include?(:udp)
        @proxies[proxy][:has_sip_tcp] = @proxies[proxy][:transport_preference].include?(:tcp)
        @proxies[proxy][:has_sip_tls] = @proxies[proxy][:transport_preference].include?(:tls)

        # Add a hash for the DNS cache.
        @proxies[proxy][:dns_cache] = {}  if @proxies[proxy][:use_dns_cache]
      end
    end

  end

end 