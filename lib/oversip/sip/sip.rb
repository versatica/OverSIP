module OverSIP::SIP

  def self.module_init
    conf = ::OverSIP.configuration

    @local_ipv4 = conf[:sip][:listen_ipv4]
    @local_ipv6 = conf[:sip][:listen_ipv6]

    @tcp_keepalive_interval = conf[:sip][:tcp_keepalive_interval]

    @local_aliases = {}

    sip_local_domains = conf[:sip][:local_domains] || []
    sip_local_ips = []
    sip_local_ips << conf[:sip][:listen_ipv4]  if conf[:sip][:enable_ipv4]
    sip_local_ips << "[#{OverSIP::Utils.normalize_ipv6(conf[:sip][:listen_ipv6])}]"  if conf[:sip][:enable_ipv6]
    sip_local_ports = [ conf[:sip][:listen_port], conf[:sip][:listen_port_tls] ].compact
    sip_local_domains.each do |domain|
      @local_aliases[domain] = true
      sip_local_ports.each do |port|
        @local_aliases["#{domain}:#{port}"] = true
      end
    end
    sip_local_ips.each do |ip|
      sip_local_ports.each do |port|
        @local_aliases["#{ip}:#{port}"] = true
      end
    end
    sip_local_ips.each do |ip|
      @local_aliases[ip] = true  if conf[:sip][:listen_port] == 5060 or conf[:sip][:listen_port_tls] == 5061
    end

    ws_local_domains = conf[:sip][:local_domains] || []
    ws_local_ips = []
    ws_local_ips << conf[:websocket][:listen_ipv4]  if conf[:websocket][:enable_ipv4]
    ws_local_ips << "[#{OverSIP::Utils.normalize_ipv6(conf[:websocket][:listen_ipv6])}]"  if conf[:websocket][:enable_ipv6]
    ws_local_ports = [ conf[:websocket][:listen_port], conf[:websocket][:listen_port_tls] ].compact
    ws_local_domains.each do |domain|
      @local_aliases[domain] = true
      ws_local_ports.each do |port|
        @local_aliases["#{domain}:#{port}"] = true
      end
    end
    ws_local_ips.each do |ip|
      ws_local_ports.each do |port|
        @local_aliases["#{ip}:#{port}"] = true
      end
    end
    ws_local_ips.each do |ip|
      @local_aliases[ip] = true  if conf[:websocket][:listen_port] == 80 or conf[:websocket][:listen_port_tls] == 443
    end

    @callback_on_client_tls_handshake = conf[:sip][:callback_on_client_tls_handshake]
  end

  def self.local_aliases
    @local_aliases
  end

  def self.tcp_keepalive_interval
    @tcp_keepalive_interval
  end

  def self.local_ipv4
    @local_ipv4
  end

  def self.local_ipv6
    @local_ipv6
  end

  def self.callback_on_client_tls_handshake
    @callback_on_client_tls_handshake
  end

end
