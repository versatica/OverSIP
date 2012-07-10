# Ruby built-in libraries.

require "syslog"


# Ruby external gems.

gem "eventmachine-le", ">= 1.1.0"
require "eventmachine-le"

gem "em-posixmq", ">= 0.2.3"
require "em-posixmq"

# OverSIP libraries.
# (not required to be loaded as needed ones have been already
# loaded before forking).



module OverSIP

  module SysLoggerProcess

    SYSLOG_FACILITY_MAPPING = {
      "kern"    => Syslog::LOG_KERN,
      "user"    => Syslog::LOG_USER,
      "daemon"  => Syslog::LOG_DAEMON,
      "local0"  => Syslog::LOG_LOCAL0,
      "local1"  => Syslog::LOG_LOCAL1,
      "local2"  => Syslog::LOG_LOCAL2,
      "local3"  => Syslog::LOG_LOCAL3,
      "local4"  => Syslog::LOG_LOCAL4,
      "local5"  => Syslog::LOG_LOCAL5,
      "local6"  => Syslog::LOG_LOCAL6,
      "local7"  => Syslog::LOG_LOCAL7
    }

    class SysLoggerWatcher < ::EM::PosixMQ::Watcher

      def receive_message string, priority
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

    end  # class SysLoggerWatcher

    def self.run options={}
      $0 = ::OverSIP.master_name + "_syslogger"

      syslog_options = ::Syslog::LOG_PID | ::Syslog::LOG_NDELAY
      syslog_facility = SYSLOG_FACILITY_MAPPING[::OverSIP.configuration[:core][:syslog_facility]]
      ::Syslog.open(::OverSIP.master_name, syslog_options, syslog_facility)

      ppid = ::Process.ppid

      at_exit do
        ::Syslog.notice sprintf("%7s %s", "INFO:", "<syslogger> syslogger process terminated")
        exit!
      end

      EM.run do
        begin
          syslogger_mq = ::POSIX_MQ.new ::OverSIP.syslogger_mq_name, ::IO::RDONLY | ::IO::NONBLOCK
          ::EM::PosixMQ.run syslogger_mq, SysLoggerWatcher

          # Change process permissions if requested.
          ::OverSIP::Launcher.set_user_group(options[:user], options[:group])

        rescue => e
          ::Syslog.crit sprintf("%7s %s", "CRIT:", "<syslogger> #{e.class}: #{e}")
          ::Syslog.crit sprintf("%7s %s", "CRIT:", "<syslogger> syslogger process terminated")
          exit! 1
        end

        # Periodically check that master process remains alive and
        # die otherwise.
        ::EM.add_periodic_timer(1) do
          if ::Process.ppid != ppid
            # Wait 0.5 seconds. Maybe the master process has been killed properly and just now
            # it's sending us the QUIT signal.
            ::EM.add_timer(0.5) do
              ::Syslog.crit sprintf("%7s %s", "CRIT:", "<syslogger> master process died, syslogger process terminated")
              exit! 1
            end
          end
        end

        ::EM.error_handler do |e|
          ::Syslog.crit sprintf("%7s %s", "CRIT:", "<syslogger> error raised during event loop and rescued by EM.error_handler: #{e.message} (#{e.class})\n#{(e.backtrace || [])[0..3].join("\n")}")
        end

        ::Syslog.info sprintf("%7s %s", "INFO:", "<syslogger> syslogger process (PID #{$$}) ready")
      end
    end

  end  # module SysLoggerProcess

end
