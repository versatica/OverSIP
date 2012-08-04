module OverSIP

  module Syslog

    SYSLOG_FACILITY_MAPPING = {
      "kern"    => ::Syslog::LOG_KERN,
      "user"    => ::Syslog::LOG_USER,
      "daemon"  => ::Syslog::LOG_DAEMON,
      "local0"  => ::Syslog::LOG_LOCAL0,
      "local1"  => ::Syslog::LOG_LOCAL1,
      "local2"  => ::Syslog::LOG_LOCAL2,
      "local3"  => ::Syslog::LOG_LOCAL3,
      "local4"  => ::Syslog::LOG_LOCAL4,
      "local5"  => ::Syslog::LOG_LOCAL5,
      "local6"  => ::Syslog::LOG_LOCAL6,
      "local7"  => ::Syslog::LOG_LOCAL7
    }

    SYSLOG_SEVERITY_MAPPING = {
      "debug"  => 0,
      "info"   => 1,
      "notice" => 2,
      "warn"   => 3,
      "error"  => 4,
      "crit"   => 5,
      "alert"  => 6,
      "emerg"  => 7
    }

    def self.log string
      level = string.getbyte 0
      msg   = string[1..-1].gsub(/%/,"%%").gsub(/\x00/,"")

      case level
      when 48  # "0" =>DEBUG
        ::Syslog.debug sprintf("%7s %s", "DEBUG:", msg)
      when 49  # "1" => INFO
        ::Syslog.info sprintf("%7s %s", "INFO:", msg)
      when 50  # "2" => NOTICE
        ::Syslog.notice sprintf("%7s %s", "NOTICE:", msg)
      when 51  # "3" => WARN
        ::Syslog.warning sprintf("%7s %s", "WARN:", msg)
      when 52  # "4" => ERR
        ::Syslog.err sprintf("%7s %s", "ERROR:", msg)
      when 53  # "5" => CRIT
        ::Syslog.crit sprintf("%7s %s", "CRIT:", msg)
      when 54  # "6" => ALERT
        ::Syslog.alert sprintf("%7s %s", "ALERT:", msg)
      when 55  # "7" => EMERG
        ::Syslog.emerg sprintf("%7s %s", "EMERG:", msg)
      else  # Shouldn't occur.
        ::Syslog.err sprintf("%7s %s", "UNKNOWN:", msg)
      end
    end

  end

end
