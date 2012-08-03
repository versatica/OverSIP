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


# OverSIP files.

require "oversip/version.rb"
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




module OverSIP

  class << self
    attr_accessor :pid_file, :master_name, :master_pid, :daemonized,
                  :syslogger_pid, :syslogger_mq_name,
                  :configuration,
                  :proxies,
                  :tls, :tls_public_cert, :tls_private_cert, :tls_proxy_ipv4, :tls_proxy_ipv6,
                  :stud_pids

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

end
