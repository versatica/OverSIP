module OverSIP

  # Logging client module. Any class desiring to log messages must include (or extend) this module.
  # In order to identify itself in the logs, the class can define log_id() method or set @log_id
  # attribute.
  module Logger

    def self.load_methods
      ::Syslog.close  if ::Syslog.opened?

      syslog_options = ::Syslog::LOG_PID | ::Syslog::LOG_NDELAY
      syslog_facility = ::OverSIP::Syslog::SYSLOG_FACILITY_MAPPING[::OverSIP.configuration[:core][:syslog_facility]] rescue ::Syslog::LOG_DAEMON
      ::Syslog.open(::OverSIP.master_name, syslog_options, syslog_facility)

      begin
        @@threshold = ::OverSIP::Syslog::SYSLOG_SEVERITY_MAPPING[::OverSIP.configuration[:core][:syslog_level]]
      rescue
        @@threshold = 0  # debug.
      end

      $oversip_debug = ( @@threshold == 0 ? true : false )

      ::OverSIP::Syslog::SYSLOG_SEVERITY_MAPPING.each do |level_str, level_value|
        method_str = "
          def log_system_#{level_str}(msg)
        "

        method_str << "
          return false if @@threshold > #{level_value}

          ::OverSIP::Syslog.log #{level_value}, msg, log_id, false
        "

        if not ::OverSIP.daemonized?
          if %w{debug info notice}.include? level_str
            method_str << "
              puts ::OverSIP::Logger.fg_system_msg2str('#{level_str}', msg, log_id)
              "
          else
            method_str << "
              $stderr.puts ::OverSIP::Logger.fg_system_msg2str('#{level_str}', msg, log_id)
            "
          end
        end

        method_str << "end"

        self.module_eval method_str


        # User logs.
        method_str = "
          def log_#{level_str}(msg)
            return false if @@threshold > #{level_value}

            ::OverSIP::Syslog.log #{level_value}, msg, log_id, true
          end
        "

        self.module_eval method_str

      end  # .each
    end

    def self.fg_system_msg2str(level_str, msg, log_id)
      case msg
      when ::String
        "#{level_str.upcase}: <#{log_id}> " << msg
      when ::Exception
        "#{level_str.upcase}: <#{log_id}> #{msg.message} (#{msg.class })\n#{(msg.backtrace || [])[0..3].join("\n")}"
      else
        "#{level_str.upcase}: <#{log_id}> " << msg.inspect
      end
    end

    # Default logging identifier is the class name. If log_id() method is redefined by the
    # class including this module, or it sets @log_id, then such a value takes preference.
    def log_id
      @log_id ||= (self.is_a?(::Module) ? self.name.split("::").last : self.class.name)
    end

  end  # module Logger

end
