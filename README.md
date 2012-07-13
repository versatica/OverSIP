<a style="color: red" href="http://www.oversip.net"><img src="https://github.com/versatica/OverSIP/wiki/oversip-banner.png"/></a>

**WEB UNDER CONSTRUCTION:** The code is stable and working. This web page and documentation is not... please wait a bit.

OverSIP is an async SIP proxy/server programmable in Ruby language.

Some features of OverSIP are:
* SIP transports: UDP, TCP, TLS and WebSocket.
* Full IPv4 and IPv6 support.
* RFC 3263: SIP DNS mechanism (NAPTR, SRV, A, AAAA) for failover and load balancing based on DNS.
* RFC 5626: OverSIP is a perfect Outbound EDGE proxy, including an integrated STUN server.
* Fully programmable in Ruby language (make SIP easy).
* Fast and efficient: OverSIP core is coded in C language.

OverSIP is build on top of EventMachine async library which follows the Reactor Pattern design, allowing thousands of concurrent connections and requests in a never-blocking fashion.