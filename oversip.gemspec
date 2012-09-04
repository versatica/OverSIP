require "./lib/oversip/version"

::Gem::Specification.new do |spec|
  spec.name = "oversip"
  spec.version = ::OverSIP::VERSION
  spec.date = ::Time.now
  spec.authors = [::OverSIP::AUTHOR]
  spec.email = [::OverSIP::AUTHOR_EMAIL]
  spec.homepage = ::OverSIP::HOMEPAGE
  spec.summary = "OverSIP (the SIP framework you dreamed about)"
  spec.description = <<-_END_
OverSIP is an async SIP proxy/server programmable in Ruby language. Some features of OverSIP are:
- SIP transports: UDP, TCP, TLS and WebSocket.
- Full IPv4 and IPv6 support.
- RFC 3263: SIP DNS mechanism (NAPTR, SRV, A, AAAA) for failover and load balancing based on DNS.
- RFC 5626: OverSIP is a perfect Outbound Edge Proxy, including an integrated STUN server.
- Fully programmable in Ruby language (make SIP easy).
- Fast and efficient: OverSIP core is coded in C language.
OverSIP is build on top of EventMachine-LE async library which follows the Reactor Design Pattern, allowing thousands of concurrent connections and requests in a never-blocking fashion.
_END_

  spec.required_ruby_version = ">= 1.9.2"
  spec.add_dependency "eventmachine-le", ">= 1.1.3"
  spec.add_dependency "iobuffer", ">= 1.1.2"
  spec.add_dependency "em-posixmq", ">= 0.2.3"
  spec.add_dependency "em-udns", ">= 0.3.6"
  spec.add_dependency "escape_utils", ">= 0.2.4"
  spec.add_dependency "term-ansicolor"
  spec.add_dependency "posix-spawn", ">= 0.3.6"
  spec.add_development_dependency "rake", "~> 0.9.2"

  spec.files = ::Dir.glob %w{
    lib/oversip.rb
    lib/oversip/*.rb
    lib/oversip/ruby_ext/*.rb

    lib/oversip/sip/*.rb
    lib/oversip/sip/listeners/*.rb
    lib/oversip/sip/grammar/*.rb

    lib/oversip/websocket/*.rb
    lib/oversip/websocket/listeners/*.rb

    lib/oversip/modules/*.rb

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

  spec.test_files = ::Dir.glob %w{
    test/oversip_test_helper.rb
    test/test_*.rb
  }

  spec.has_rdoc = false
end
