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

    def self.log level_value, msg, log_id, user
      user = user ? " [user] " : " "

      msg = case msg
      when ::String
        "<#{log_id}>#{user}#{msg}"
      when ::Exception
        "<#{log_id}>#{user}#{msg.message} (#{msg.class })\n#{(msg.backtrace || [])[0..3].join("\n")}"
      else
        "<#{log_id}>#{user}#{msg.inspect}"
      end

      msg = msg.gsub(/%/,"%%").gsub(/\x00/,"")

      case level_value
      when 0
        ::Syslog.debug sprintf("%7s %s", "DEBUG:", msg)
      when 1
        ::Syslog.info sprintf("%7s %s", "INFO:", msg)
      when 2
        ::Syslog.notice sprintf("%7s %s", "NOTICE:", msg)
      when 3
        ::Syslog.warning sprintf("%7s %s", "WARN:", msg)
      when 4
        ::Syslog.err sprintf("%7s %s", "ERROR:", msg)
      when 5
        ::Syslog.crit sprintf("%7s %s", "CRIT:", msg)
      when 6
        ::Syslog.alert sprintf("%7s %s", "ALERT:", msg)
      when 7
        ::Syslog.emerg sprintf("%7s %s", "EMERG:", msg)
      else  # Shouldn't occur.
        ::Syslog.err sprintf("%7s %s", "UNKNOWN:", msg)
      end
    end

  end

end
