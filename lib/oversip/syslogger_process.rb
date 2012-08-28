# Ruby external gems.

gem "eventmachine-le", ">= 1.1.3"
require "eventmachine-le"
gem "em-posixmq", ">= 0.2.3"
require "em-posixmq"


# OverSIP libraries.
# (not required to be loaded as needed ones have been already
# loaded before forking).



module OverSIP

  module SysLoggerProcess

    class SysLoggerWatcher < ::EM::PosixMQ::Watcher

      def receive_message string, priority
        ::OverSIP::Syslog.log string
      end

    end  # class SysLoggerWatcher

    def self.run options={}
      $0 = ::OverSIP.master_name + "_syslogger"

      # Close Ruby Syslog open in the main process before forking.
      ::Syslog.close

      # Run a new Ruby Syslog.
      syslog_options = ::Syslog::LOG_PID | ::Syslog::LOG_NDELAY
      syslog_facility = ::OverSIP::Syslog::SYSLOG_FACILITY_MAPPING[::OverSIP.configuration[:core][:syslog_facility]]
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

        rescue ::Exception => e
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
