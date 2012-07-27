require "./lib/oversip/version"

Gem::Specification.new do |spec|
  spec.name = "oversip"
  spec.version = OverSIP::VERSION
  spec.date = Time.now
  spec.authors = [OverSIP::AUTHOR]
  spec.email = OverSIP::AUTHOR_EMAIL
  spec.summary = "the SIP dreams factory"
  spec.homepage = "http://www.oversip.net"
  spec.description = "OverSIP is an async SIP server. Built on top of Ruby EventMachine
    library it follows the Reactor Pattern, allowing thousands of concurrent connections and requests
    handled by a single processor in a never-blocking fashion. It supports SIP over UDP, TCP, TLS and
    WebSocket transports, full RFC 3263 (async DNS resolution), Outbound (RFC 5626) and more features."
  spec.required_ruby_version = "~> 1.9.2"

  spec.add_dependency "eventmachine-le", ">= 1.1.2"
  spec.add_dependency "iobuffer", ">= 1.1.2"
  spec.add_dependency "em-posixmq", ">= 0.2.3"
  spec.add_dependency "em-udns", ">= 0.3.6"
  spec.add_dependency "escape_utils", ">= 0.2.4"
  spec.add_dependency "term-ansicolor"
  spec.add_dependency "posix-spawn", ">= 0.3.6"

  spec.add_development_dependency "rake", "~> 0.9.2"

  spec.files = Dir.glob %w{
    lib/oversip.rb
    lib/oversip/*.rb
    lib/oversip/ruby_ext/*.rb

    lib/oversip/sip/*.rb
    lib/oversip/sip/listeners/*.rb
    lib/oversip/sip/grammar/*.rb
    lib/oversip/sip/modules/*.rb

    lib/oversip/websocket/*.rb
    lib/oversip/websocket/listeners/*.rb
    lib/oversip/websocket/ws_apps/*.rb

    ext/common/*.h

    ext/sip_parser/extconf.rb
    ext/sip_parser/*.h
    ext/sip_parser/*.c

    ext/stun/extconf.rb
    ext/stun/*.h
    ext/stun/*.c

    ext/utils/extconf.rb
    ext/utils/*.h
    ext/utils/*.c

    ext/websocket_http_parser/extconf.rb
    ext/websocket_http_parser/*.h
    ext/websocket_http_parser/*.c

    ext/websocket_framing_utils/extconf.rb
    ext/websocket_framing_utils/*.h
    ext/websocket_framing_utils/*.c

    ext/stud/extconf.rb

    thirdparty/stud/stud.tar.gz

    etc/*
    etc/tls/*
    etc/tls/ca/*
    etc/tls/utils/*

    Rakefile
    README.md
    AUTHORS
    LICENSE
  }

  spec.extensions = %w{
    ext/sip_parser/extconf.rb
    ext/stun/extconf.rb
    ext/utils/extconf.rb
    ext/websocket_http_parser/extconf.rb
    ext/websocket_framing_utils/extconf.rb
    ext/stud/extconf.rb
  }

  spec.executables = ["oversip"]

  spec.test_files = Dir.glob %w{
    test/oversip_test_helper.rb
    test/test_*.rb
  }

  spec.has_rdoc = false
end
