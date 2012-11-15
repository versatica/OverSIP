# Ruby built-in libraries.

require "etc"
require "fileutils"
require "socket"
require "timeout"
require "yaml"
require "tempfile"


# Ruby external gems.

require "term/ansicolor"
require "posix_mq"
require "syslog"
# Load EventMachine-LE here to avoid som EM based gem in server.rb to be loaded first
# (and load eventmachine instead of eventmachine-le).
gem "eventmachine-le", ">= 1.1.3"
require "eventmachine-le"


# OverSIP files.

require "oversip/version.rb"
require "oversip/syslog.rb"
require "oversip/logger.rb"
require "oversip/config.rb"
require "oversip/config_validators.rb"
require "oversip/proxies_config.rb"
require "oversip/errors.rb"
require "oversip/launcher.rb"
require "oversip/utils.so"
require "oversip/utils.rb"
require "oversip/posix_mq.rb"
require "oversip/default_server.rb"
require "oversip/system_callbacks.rb"
require "oversip/ruby_ext/process.rb"  # Required here as the Posix message queue is created before loading master_process.rb.



module OverSIP

  class << self
    attr_accessor :pid_file, :master_name, :master_pid, :daemonized,
                  :syslogger_pid, :syslogger_mq_name,
                  :configuration,
                  :proxies,
                  :tls_public_cert, :tls_private_cert,
                  :stud_pids,
                  :is_ready,  # true, false
                  :status  # :loading, :running, :terminating

    def master?
      @master_pid == $$
    end

    def daemonized?
      @daemonized
    end

    def syslogger_ready?
      @syslogger_pid and true
    end
  end

  # Pre-declare internal modules.
  module SIP ; end
  module WebSocket ; end
  module Modules ; end

  # Allow OverSIP::M::MODULE_NAME usage.
  M = Modules

end
