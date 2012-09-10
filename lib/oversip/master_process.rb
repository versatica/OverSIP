# Ruby built-in libraries.

require "base64"
require "digest/md5"
require "digest/sha1"
require "securerandom"
require "fiber"
require "openssl"


# Ruby external gems.

gem "iobuffer", ">= 1.1.2"
require "iobuffer"
gem "em-udns", ">= 0.3.6"
require "em-udns"
gem "escape_utils", ">= 0.2.4"
require "escape_utils"
gem "posix-spawn", ">= 0.3.6"
require "posix-spawn"
gem "em-synchrony", ">=1.0.2"
require "em-synchrony"


# OverSIP files.

require "oversip/sip/sip.rb"
require "oversip/sip/sip_parser.so"
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
require "oversip/sip/proxy.rb"
require "oversip/sip/uac.rb"
require "oversip/sip/uac_request.rb"

require "oversip/websocket/websocket.rb"
require "oversip/websocket/ws_http_parser.so"
require "oversip/websocket/constants.rb"
require "oversip/websocket/http_request.rb"
require "oversip/websocket/listeners.rb"
require "oversip/websocket/launcher.rb"
require "oversip/websocket/ws_framing_utils.so"
require "oversip/websocket/ws_framing.rb"
require "oversip/websocket/ws_sip_app.rb"

require "oversip/fiber_pool.rb"
require "oversip/tls.rb"
require "oversip/stun.so"

require "oversip/modules/user_assertion.rb"
require "oversip/modules/outbound_mangling.rb"

require "oversip/ruby_ext/eventmachine.rb"
