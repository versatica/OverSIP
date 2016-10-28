#
# OverSIP
# Copyright (c) 2012-2014 Iñaki Baz Castillo <ibc@aliax.net>
# MIT License
#

# Ruby built-in libraries.

require "rbconfig"
require "etc"
require "fileutils"
require "socket"
require "timeout"
require "yaml"
require "tempfile"
require "base64"
require "digest/md5"
require "digest/sha1"
require "securerandom"
require "fiber"
require "openssl"


# Ruby external gems.

require "syslog"
gem "eventmachine", "~> 1.2.0"
require "eventmachine"
gem "iobuffer", "= 1.1.2"
require "iobuffer"
gem "em-udns", "= 0.3.6"
require "em-udns"
gem "escape_utils", "= 1.0.1"
require "escape_utils"
gem "term-ansicolor", "= 1.3.0"
require "term/ansicolor"
gem "posix-spawn", "= 0.3.9"
require "posix-spawn"
gem "em-synchrony", "= 1.0.3"
require "em-synchrony"


# OverSIP files.

require "oversip/version.rb"
require "oversip/syslog.rb"
require "oversip/logger.rb"
require "oversip/config.rb"
require "oversip/config_validators.rb"
require "oversip/proxies_config.rb"
require "oversip/errors.rb"
require "oversip/launcher.rb"
require "oversip/utils.#{RbConfig::CONFIG["DLEXT"]}"
require "oversip/utils.rb"
require "oversip/default_server.rb"
require "oversip/system_callbacks.rb"

require "oversip/sip/sip.rb"
require "oversip/sip/sip_parser.#{RbConfig::CONFIG["DLEXT"]}"
require "oversip/sip/constants.rb"
require "oversip/sip/core.rb"
require "oversip/sip/message.rb"
require "oversip/sip/request.rb"
require "oversip/sip/response.rb"
require "oversip/sip/uri.rb"
require "oversip/sip/name_addr.rb"
require "oversip/sip/message_processor.rb"
require "oversip/sip/listeners.rb"
require "oversip/sip/launcher.rb"
require "oversip/sip/server_transaction.rb"
require "oversip/sip/client_transaction.rb"
require "oversip/sip/transport_manager.rb"
require "oversip/sip/timers.rb"
require "oversip/sip/tags.rb"
require "oversip/sip/rfc3263.rb"
require "oversip/sip/client.rb"
require "oversip/sip/proxy.rb"
require "oversip/sip/uac.rb"
require "oversip/sip/uac_request.rb"

require "oversip/websocket/websocket.rb"
require "oversip/websocket/ws_http_parser.#{RbConfig::CONFIG["DLEXT"]}"
require "oversip/websocket/constants.rb"
require "oversip/websocket/http_request.rb"
require "oversip/websocket/listeners.rb"
require "oversip/websocket/launcher.rb"
require "oversip/websocket/ws_framing_utils.#{RbConfig::CONFIG["DLEXT"]}"
require "oversip/websocket/ws_framing.rb"
require "oversip/websocket/ws_sip_app.rb"

require "oversip/fiber_pool.rb"
require "oversip/tls.rb"
require "oversip/stun.#{RbConfig::CONFIG["DLEXT"]}"

require "oversip/modules/user_assertion.rb"
require "oversip/modules/outbound_mangling.rb"

require "oversip/ruby_ext/eventmachine.rb"


module OverSIP

  class << self
    attr_accessor :pid_file, :master_name, :pid, :daemonized,
                  :configuration,
                  :proxies,
                  :tls_public_cert, :tls_private_cert,
                  :stud_pids,
                  :is_ready,  # true, false
                  :status,  # :loading, :running, :terminating
                  :root_fiber

    def daemonized?
      @daemonized
    end

  end

  # Pre-declare internal modules.
  module SIP ; end
  module WebSocket ; end
  module Modules ; end

  # Allow OverSIP::M::MODULE_NAME usage.
  M = Modules

end
