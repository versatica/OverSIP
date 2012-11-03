module OverSIP

  module Security

    class << self
      attr_reader :sip_max_body_size,
                  :ws_max_message_size,
                  :anti_slow_attack_timeout,
                  :connection_in_inactivity_timeout,
                  :connection_out_inactivity_timeout
    end

    def self.module_init
      conf = ::OverSIP.configuration

      @sip_max_body_size = conf[:security][:sip_max_body_size]
      @ws_max_message_size = conf[:security][:ws_max_message_size]
      @anti_slow_attack_timeout = conf[:security][:anti_slow_attack_timeout]
      @connection_in_inactivity_timeout = conf[:security][:connection_in_inactivity_timeout]
      @connection_out_inactivity_timeout = conf[:security][:connection_out_inactivity_timeout]
    end

  end

end