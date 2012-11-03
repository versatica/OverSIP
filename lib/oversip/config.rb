module OverSIP

  module Config

    # Pre-declaration of Validators module (defined in other file).
    module Config::Validators ; end

    extend ::OverSIP::Logger
    extend ::OverSIP::Config::Validators

    DEFAULT_CONFIG_DIR = "/etc/oversip"
    DEFAULT_TLS_DIR = "tls"
    DEFAULT_TLS_CA_DIR = "tls/ca"
    DEFAULT_CONFIG_FILE = "oversip.conf"
    PROXIES_FILE = "proxies.conf"
    SERVER_FILE = "server.rb"

    def self.log_id
      @log_id ||= "Config"
    end


    @configuration = {
      :core => {
        :nameservers              => nil,
        :syslog_facility          => "user",
        :syslog_level             => "info"
      },
      :sip => {
        :sip_udp                  => true,
        :sip_tcp                  => true,
        :sip_tls                  => false,
        :enable_ipv4              => true,
        :listen_ipv4              => nil,
        :enable_ipv6              => true,
        :listen_ipv6              => nil,
        :listen_port              => 5060,
        :listen_port_tls          => 5061,
        :use_tls_tunnel           => false,
        :listen_port_tls_tunnel   => 5062,
        :callback_on_client_tls_handshake => true,
        :local_domains            => nil,
        :tcp_keepalive_interval   => nil,
        :record_route_hostname_tls_ipv4 => nil,
        :record_route_hostname_tls_ipv6 => nil
      },
      :websocket => {
        :sip_ws                   => false,
        :sip_wss                  => false,
        :enable_ipv4              => true,
        :listen_ipv4              => nil,
        :enable_ipv6              => true,
        :listen_ipv6              => nil,
        :listen_port              => 10080,
        :listen_port_tls          => 10443,
        :use_tls_tunnel           => false,
        :listen_port_tls_tunnel   => 10444,
        :callback_on_client_tls_handshake => true,
        :max_ws_message_size      => 65536,
        :ws_keepalive_interval    => nil
      },
      :tls => {
        :public_cert              => nil,
        :private_cert             => nil,
        :ca_dir                   => nil
      },
      :security => {
        :sip_max_body_size                 => 65536,
        :websocket_max_message_size        => 65536,
        :connection_in_inactivity_timeout  => 120,
        :connection_out_inactivity_timeout => 120,
        :anti_slow_attack_timeout    => 4
      }
    }

    CONFIG_VALIDATIONS = {
      :core => {
        :nameservers                     => [ :ipv4, :multi_value ],
        :syslog_facility                 => [
          [ :choices,
            %w{ kern user daemon local0 local1 local2 local3 local4 local5 local6 local7 } ]
        ],
        :syslog_level                    => [
          [ :choices,
            %w{ debug info notice warn error crit } ]
        ],
      },
      :sip => {
        :sip_udp                         => :boolean,
        :sip_tcp                         => :boolean,
        :sip_tls                         => :boolean,
        :enable_ipv4                     => :boolean,
        :listen_ipv4                     => :ipv4,
        :enable_ipv6                     => :boolean,
        :listen_ipv6                     => :ipv6,
        :listen_port                     => :port,
        :listen_port_tls                 => :port,
        :use_tls_tunnel                  => :boolean,
        :listen_port_tls_tunnel          => :port,
        :callback_on_client_tls_handshake => :boolean,
        :local_domains                   => [ :domain, :multi_value ],
        :tcp_keepalive_interval          => [ :fixnum, [ :greater_equal_than, 2 ] ],  # TODO: poner 180
        :record_route_hostname_tls_ipv4  => :domain,
        :record_route_hostname_tls_ipv6  => :domain,
      },
      :websocket => {
        :sip_ws                          => :boolean,
        :sip_wss                         => :boolean,
        :enable_ipv4                     => :boolean,
        :listen_ipv4                     => :ipv4,
        :enable_ipv6                     => :boolean,
        :listen_ipv6                     => :ipv6,
        :listen_port                     => :port,
        :listen_port_tls                 => :port,
        :use_tls_tunnel                  => :boolean,
        :listen_port_tls_tunnel          => :port,
        :callback_on_client_tls_handshake => :boolean,
        :ws_keepalive_interval           => [ :fixnum, [ :greater_equal_than, 180 ] ],
      },
      :tls => {
        :public_cert                     => [ :readable_file, :tls_pem_chain ],
        :private_cert                    => [ :readable_file, :tls_pem_private ],
        :ca_dir                          => :readable_dir
      },
      :security => {
        :sip_max_body_size                 => :fixnum,
        :websocket_max_message_size        => :fixnum,
        :connection_in_inactivity_timeout  => [ :fixnum, [ :greater_equal_than, 2 ] ],
        :connection_out_inactivity_timeout => [ :fixnum, [ :greater_equal_than, 2 ] ],
        :anti_slow_attack_timeout          => :fixnum
      }
    }


    def self.load config_dir=nil, config_file=nil
      @config_dir = (::File.expand_path(config_dir) if config_dir) || DEFAULT_CONFIG_DIR
      @config_file = ::File.join(@config_dir, config_file || DEFAULT_CONFIG_FILE)
      @proxies_file = ::File.join(@config_dir, PROXIES_FILE)
      @server_file = ::File.join(@config_dir, SERVER_FILE)

      # Load the oversip.conf YAML file.
      begin
        conf_yaml = ::YAML.load_file @config_file
      rescue ::Exception => e
        log_system_crit "error loading Main Configuration file '#{@config_file}':"
        ::OverSIP::Launcher.fatal e
      end

      # Load the proxies.conf YAML file.
      begin
        proxies_yaml = ::YAML.load_file @proxies_file
      rescue ::Exception => e
        log_system_crit "error loading Proxies Configuration file '#{@proxies_file}':"
        ::OverSIP::Launcher.fatal e
      end

      # Load the server.rb file.
      begin
        require @server_file
      rescue ::Exception => e
        log_system_crit "error loading Server file '#{@server_file}':"
        ::OverSIP::Launcher.fatal e
      end

      # Process the oversip.conf file.
      begin
        pre_check(conf_yaml)

        CONFIG_VALIDATIONS.each_key do |section|
          CONFIG_VALIDATIONS[section].each do |parameter, validations|
            values = conf_yaml[section.to_s][parameter.to_s] rescue nil
            validations = [ validations ]  unless validations.is_a?(Array)

            if values == nil
              if validations.include? :required
                ::OverSIP::Launcher.fatal "#{section}[#{parameter}] requires a value"
              end
              next
            end

            if values.is_a? ::Array
              unless validations.include? :multi_value
                ::OverSIP::Launcher.fatal "#{section}[#{parameter}] does not allow multiple values"
              end

              if validations.include? :non_empty and values.empty?
                ::OverSIP::Launcher.fatal "#{section}[#{parameter}] does not allow empty values"
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
                  ::OverSIP::Launcher.fatal "#{section}[#{parameter}] has invalid value '#{humanize_value value}' (does not satisfy '#{validation}' validation requirement)"
                end
              end

              @configuration[section][parameter] = ( validations.include?(:multi_value) ? values : values[0] )
            end

          end  # CONFIG_VALIDATIONS[section].each
        end  # CONFIG_VALIDATIONS.each_key

        post_process
        post_check

      rescue ::OverSIP::ConfigurationError => e
        ::OverSIP::Launcher.fatal "configuration error: #{e.message}"
      rescue => e
        ::OverSIP::Launcher.fatal e
      end

      ::OverSIP.configuration = @configuration

      # Process the proxies.conf file.
      begin
        ::OverSIP::ProxiesConfig.load proxies_yaml
      rescue ::OverSIP::ConfigurationError => e
        ::OverSIP::Launcher.fatal "error loading Proxies Configuration file '#{@proxies_file}':  #{e.message}"
      rescue ::Exception => e
        log_system_crit "error loading Proxies Configuration file '#{@proxies_file}':"
        ::OverSIP::Launcher.fatal e
      end
    end


    def self.pre_check conf_yaml
      # If TLS files/directories are given as relative path, convert them into absolute paths.

      tls_public_cert = conf_yaml["tls"]["public_cert"] rescue nil
      tls_private_cert = conf_yaml["tls"]["private_cert"] rescue nil
      tls_ca_dir = conf_yaml["tls"]["ca_dir"] rescue nil

      if tls_public_cert.is_a?(::String) and tls_public_cert[0] != "/"
        conf_yaml["tls"]["public_cert"] = ::File.join(@config_dir, DEFAULT_TLS_DIR, tls_public_cert)
      end

      if tls_private_cert.is_a?(::String) and tls_private_cert[0] != "/"
        conf_yaml["tls"]["private_cert"] = ::File.join(@config_dir, DEFAULT_TLS_DIR, tls_private_cert)
      end

      if tls_ca_dir.is_a?(::String) and tls_ca_dir[0] != "/"
        conf_yaml["tls"]["ca_dir"] = ::File.join(@config_dir, DEFAULT_TLS_DIR, tls_ca_dir)
      end
    end

    def self.post_process
      if @configuration[:tls][:public_cert] and @configuration[:tls][:private_cert]
        @use_tls = true
        # Generate a full PEM file containing both the public and private certificate (for Stud).
        full_cert = ::Tempfile.new("oversip_full_cert_")
        full_cert.puts ::File.read(@configuration[:tls][:public_cert])
        full_cert.puts ::File.read(@configuration[:tls][:private_cert])
        @configuration[:tls][:full_cert] = full_cert.path
        full_cert.close
      else
        @configuration[:sip][:sip_tls] = false
        @configuration[:websocket][:sip_wss] = false
      end

      if @configuration[:sip][:sip_udp] or @configuration[:sip][:sip_tcp]
        @use_sip_udp_or_tcp = true
      else
        @configuration[:sip][:listen_port] = nil
      end

      if @configuration[:sip][:sip_tls] and @use_tls
        @use_sip_tls = true
      else
        @configuration[:sip][:listen_port_tls] = nil
      end

      unless @use_sip_udp_or_tcp or @use_sip_tls
        @configuration[:sip][:listen_ipv4] = nil
        @configuration[:sip][:listen_ipv6] = nil
        @configuration[:sip][:enable_ipv4] = nil
        @configuration[:sip][:enable_ipv6] = nil
      end

      unless @configuration[:sip][:enable_ipv4]
        @configuration[:sip][:listen_ipv4] = nil
      end

      unless @configuration[:sip][:enable_ipv6]
        @configuration[:sip][:listen_ipv6] = nil
      end

      if @configuration[:websocket][:sip_ws]
        @use_sip_ws = true
      else
        @configuration[:websocket][:listen_port] = nil
      end

      if @configuration[:websocket][:sip_wss] and @use_tls
        @use_sip_wss = true
      else
        @configuration[:websocket][:listen_port_tls] = nil
      end

      unless @use_sip_ws or @use_sip_wss
        @configuration[:websocket][:listen_ipv4] = nil
        @configuration[:websocket][:listen_ipv6] = nil
        @configuration[:websocket][:enable_ipv4] = nil
        @configuration[:websocket][:enable_ipv6] = nil
      end

      unless @configuration[:websocket][:enable_ipv4]
        @configuration[:websocket][:listen_ipv4] = nil
      end

      unless @configuration[:websocket][:enable_ipv6]
        @configuration[:websocket][:listen_ipv6] = nil
      end

      if ( @use_sip_udp_or_tcp or @use_sip_tls ) and @configuration[:sip][:listen_ipv4] == nil and @configuration[:sip][:enable_ipv4]
        unless (@configuration[:sip][:listen_ipv4] = discover_local_ip(:ipv4))
          log_system_warn "disabling IPv4 for SIP"
          @configuration[:sip][:listen_ipv4] = nil
          @configuration[:sip][:enable_ipv4] = false
        end
      end

      if ( @use_sip_udp_or_tcp or @use_sip_tls ) and @configuration[:sip][:listen_ipv6] == nil and @configuration[:sip][:enable_ipv6]
        unless (@configuration[:sip][:listen_ipv6] = discover_local_ip(:ipv6))
          log_system_warn "disabling IPv6 for SIP"
          @configuration[:sip][:listen_ipv6] = nil
          @configuration[:sip][:enable_ipv6] = false
        end
      end

      if ( @use_sip_ws or @use_sip_wss ) and @configuration[:websocket][:listen_ipv4] == nil and @configuration[:websocket][:enable_ipv4]
        unless (@configuration[:websocket][:listen_ipv4] = discover_local_ip(:ipv4))
          log_system_warn "disabling IPv4 for WebSocket"
          @configuration[:websocket][:listen_ipv4] = nil
          @configuration[:websocket][:enable_ipv4] = false
        end
      end

      if ( @use_sip_ws or @use_sip_wss ) and @configuration[:websocket][:listen_ipv6] == nil and @configuration[:websocket][:enable_ipv6]
        unless (@configuration[:websocket][:listen_ipv6] = discover_local_ip(:ipv6))
          log_system_warn "disabling IPv6 for WebSocket"
          @configuration[:websocket][:listen_ipv6] = nil
          @configuration[:websocket][:enable_ipv6] = false
        end
      end

      if @configuration[:sip][:local_domains]
        if @configuration[:sip][:local_domains].is_a? ::String
          @configuration[:sip][:local_domains] = [ @configuration[:sip][:local_domains].downcase ]
        end
        @configuration[:sip][:local_domains].each {|local_domain| local_domain.downcase!}
      end
    end  # def self.post_process


    def self.post_check
      binds = { :udp => [], :tcp => [] }

      if @configuration[:sip][:enable_ipv4]
        ipv4 = @configuration[:sip][:listen_ipv4]

        if @configuration[:sip][:sip_udp]
          binds[:udp] << [ ipv4, @configuration[:sip][:listen_port] ]
        end

        if @configuration[:sip][:sip_tcp]
          binds[:tcp] << [ ipv4, @configuration[:sip][:listen_port] ]
        end

        if @configuration[:sip][:sip_tls]
          unless @configuration[:sip][:use_tls_tunnel]
            binds[:tcp] << [ ipv4, @configuration[:sip][:listen_port_tls] ]
          else
            binds[:tcp] << [ "127.0.0.1", @configuration[:sip][:listen_port_tls_tunnel] ]
          end
        end
      end

      if @configuration[:sip][:enable_ipv6]
        ipv6 = @configuration[:sip][:listen_ipv6]

        if @configuration[:sip][:sip_udp]
          binds[:udp] << [ ipv6, @configuration[:sip][:listen_port] ]
        end

        if @configuration[:sip][:sip_tcp]
          binds[:tcp] << [ ipv6, @configuration[:sip][:listen_port] ]
        end

        if @configuration[:sip][:sip_tls]
          unless @configuration[:sip][:use_tls_tunnel]
            binds[:tcp] << [ ipv6, @configuration[:sip][:listen_port_tls] ]
          else
            binds[:tcp] << [ "::1", @configuration[:sip][:listen_port_tls_tunnel] ]
          end
        end
      end

      if @configuration[:websocket][:enable_ipv4]
        ipv4 = @configuration[:websocket][:listen_ipv4]

        if @configuration[:websocket][:sip_ws]
          binds[:tcp] << [ ipv4, @configuration[:websocket][:listen_port] ]
        end

        if @configuration[:websocket][:sip_wss]
          unless @configuration[:sip][:use_tls_tunnel]
            binds[:tcp] << [ ipv4, @configuration[:websocket][:listen_port_tls] ]
          else
            binds[:tcp] << [ "127.0.0.1", @configuration[:websocket][:listen_port_tls_tunnel] ]
          end
        end
      end

      if @configuration[:websocket][:enable_ipv6]
        ipv6 = @configuration[:websocket][:listen_ipv6]

        if @configuration[:websocket][:sip_ws]
          binds[:tcp] << [ ipv6, @configuration[:websocket][:listen_port] ]
        end

        if @configuration[:websocket][:sip_wss]
          unless @configuration[:sip][:use_tls_tunnel]
            binds[:tcp] << [ ipv6, @configuration[:websocket][:listen_port_tls] ]
          else
            binds[:tcp] << [ "::1", @configuration[:websocket][:listen_port_tls_tunnel] ]
          end
        end
      end

      unless @configuration[:sip][:use_tls_tunnel]
        @configuration[:sip][:listen_port_tls_tunnel] = nil
      end

      unless @configuration[:websocket][:use_tls_tunnel]
        @configuration[:websocket][:listen_port_tls_tunnel] = nil
      end

      [:udp, :tcp].each do |transport|
        transport_str = transport.to_s.upcase
        binds[transport].each do |ip, port|
          begin
            unless (ip_type = ::OverSIP::Utils.ip_type(ip))
              raise ::OverSIP::ConfigurationError, "given IP '#{ip}' is not IPv4 nor IPv6"
            end

            case transport
            when :udp
              case ip_type
              when :ipv4
                socket = ::UDPSocket.new ::Socket::AF_INET
              when :ipv6
                socket = ::UDPSocket.new ::Socket::AF_INET6
              end
              socket.bind ip, port
            when :tcp
              socket = ::TCPServer.open ip, port
            end

            socket.close

          rescue ::Errno::EADDRNOTAVAIL
            raise ::OverSIP::ConfigurationError, "cannot bind in #{transport_str} IP '#{ip}', address not available"
          rescue ::Errno::EADDRINUSE
            raise ::OverSIP::ConfigurationError, "#{transport_str} IP '#{ip}' and port #{port} already in use"
          rescue ::Errno::EACCES
            raise ::OverSIP::ConfigurationError, "no permission to bind in #{transport_str} IP '#{ip}' and port #{port}"
          rescue => e
            raise e.class, "error binding in #{transport_str} IP '#{ip}' and port #{port} (#{e.class}: #{e.message})"
          end
        end
      end
    end  # def self.post_check


    def self.print colorize=true
      color = ::Term::ANSIColor  if colorize

      puts
      @configuration.each_key do |section|
        if colorize
          puts "  #{color.bold(section.to_s)}:"
        else
          puts "  #{section.to_s}:"
        end
        @configuration[section].each do |parameter, value|
          humanized_value = humanize_value value
          color_value = case value
            when ::TrueClass
              colorize ? color.bold(color.green(humanized_value)) : humanized_value
            when ::FalseClass
              colorize ? color.bold(color.red(humanized_value)) : humanized_value
            when ::NilClass
              humanized_value
            when ::String, ::Symbol
              colorize ? color.yellow(humanized_value) : humanized_value
            when ::Array
              colorize ? color.yellow(humanized_value) : humanized_value
            when ::Fixnum, ::Float
              colorize ? color.bold(color.blue(humanized_value)) : humanized_value
            else
              humanized_value
            end
          printf("    %-32s:  %s\n", parameter, color_value)
        end
        puts
      end
    end

    def self.humanize_value value
      case value
        when ::TrueClass        ; "yes"
        when ::FalseClass       ; "no"
        when ::NilClass         ; "null"
        when ::String           ; value
        when ::Symbol           ; value.to_s
        when ::Array            ; value.join(", ")
        when ::Fixnum, ::Float  ; value.to_s
        else                    ; value.to_s
        end
    end

    def self.discover_local_ip(type)
      begin
        if type == :ipv4
          socket = ::UDPSocket.new ::Socket::AF_INET
          socket.connect("1.2.3.4", 1)
          ip = socket.local_address.ip_address
          socket.close
          socket = ::UDPSocket.new ::Socket::AF_INET
        elsif type == :ipv6
          socket = ::UDPSocket.new ::Socket::AF_INET6
          socket.connect("2001::1", 1)
          ip = socket.local_address.ip_address
          socket.close
          socket = ::UDPSocket.new ::Socket::AF_INET6
        end
        # Test whether the IP is in fact bindeable (not true for link-scope IPv6 addresses).
        begin
          socket.bind ip, 0
        rescue => e
          log_system_warn "cannot bind in autodiscovered local #{type == :ipv4 ? "IPv4" : "IPv6"} '#{ip}': #{e.message} (#{e.class})"
          return false
        ensure
          socket.close
        end
        # Valid IP, return it.
        return ip
      rescue => e
        log_system_warn "cannot autodiscover local #{type == :ipv4 ? "IPv4" : "IPv6"}: #{e.message} (#{e.class})"
        return false
      end
    end

    def self.system_reload
      log_system_notice "reloading OverSIP..."

      # Load and process the proxies.conf file.
      begin
        proxies_yaml = ::YAML.load_file @proxies_file
        ::OverSIP::ProxiesConfig.load proxies_yaml, reload=true
        log_system_notice "Proxies Configuration file '#{@proxies_file}' reloaded"
      rescue ::OverSIP::ConfigurationError => e
        log_system_crit "error reloading Proxies Configuration file '#{@proxies_file}':  #{e.message}"
      rescue ::Exception => e
        log_system_crit "error reloading Proxies Configuration file '#{@proxies_file}':"
        log_system_crit e
      end

      # Load the server.rb file.
      begin
        ::Kernel.load @server_file
        log_system_notice "Server file '#{@server_file}' reloaded"
      rescue ::Exception => e
        log_system_crit "error reloading Server file '#{@server_file}':"
        log_system_crit e
      end
    end

  end

end
