CHANGELOG
=========


Version devel (not yet released)
--------------------------------------



Version 1.4.0 (released in 2013-09-15)
--------------------------------------

- [(7befa37)](https://github.com/versatica/OverSIP/commit/7befa378d535bb5822dc7260516eaae8158fb9f6) RFC 6228 (199 response) implemented in `Proxy#drop_response(response)`. The method now allows passing the `OverSIP::SIP::Response` instance to drop and, in case it is a [3456]XX response and the received request includes "Supported: 199" then a 199 response is sent upstream.

- [(1159607)](https://github.com/versatica/OverSIP/commit/1159607ef524c8bba012fb19f60153d52b7d23f3) New `OverSIP::SIP::Request#ruri=(uri)` method which replaces the Request URI of the request by passing an `OverSIP::SIP::Uri` instance or a string. Also allow passing a URI as string to `UacRequest.initialize` and route based on it (if no `dst_host` param is given to the `Uac` instance routing such a request). New class methods `OverSIP::SIP::Uri.parse(string)` and `OverSIP::SIP::NameAddr.parse(string)` which generate instances of those classes.

- [(a2971fc)](https://github.com/versatica/OverSIP/commit/a2971fcc5c2e4fd4ed816d555b59442a64d22c33) New `OverSIP::ParsingError` exception which is raised when invalid data is passed to `OverSIP::SIP::Uri.parse(uri)` or `OverSIP::SIP::NameAddr.parse(name_addr)`.

- [(2689e02)](https://github.com/versatica/OverSIP/commit/2689e02d4358daf12eac76264a0e2cac96fcb665) `OverSIP::SIP::Proxy` and `OverSIP::SIP::Uac` instances now allow setting multiple callbacks (for events like `on_success_response`) and all of them will be executed sequentially.

- [(4b7c47f)](https://github.com/versatica/OverSIP/commit/4b7c47fd27e5186c71541952a1bb28af35cfcaa5) New method `OverSIP::SIP::Uri#has_param?(param)`.

- [(774de3b)](https://github.com/versatica/OverSIP/commit/774de3b537fb6afdc71adb1047184cf0785c495c) New instance methods `clear_on_xxxxxx()` and `clear_callbacks()` to clear existing callbacks in `OverSIP::SIP::Proxy` and `OverSIP::SIP::Uac`.

- [(e58974f)](https://github.com/versatica/OverSIP/commit/e58974feea8cd7962ea3efa8d8476f4bd54e52f9) New design of `OverSIP::Modules::OutboundMangling` module: `add_outbound_to_contact()` now requires passing an `OverSIP::SIP::Proxy` as argument rather than a request, and it internally adds the callback to the 2XX response (for reverting the custom ;ov-ob param) so `remove_outbound_from_contact()` is no longer required and has been removed.

- [(31114a0)](https://github.com/versatica/OverSIP/commit/31114a091c9649574af0710f23e459f0bd488757) Added `OverSIP::SIP::Uri#clear_params()` which removes all the params from the URI.

- [(c610d90)](https://github.com/versatica/OverSIP/commit/c610d90b326174b37368f11b27d40c839d76de9d) Add `advertised_ipv4` and `advertised_ipv6` configuration options for running OverSIP in NAT'ed boxes.


Version 1.3.8 (released in 2013-05-16)
--------------------------------------

- [(04b0882)](https://github.com/versatica/OverSIP/commit/04b088259f0881f5a09af9ebef9ce6e5387c4c02) `request.fix_nat()` works now for initial requests regardless `request.loose_route()` is not called (thanks to Vlad Paiu for reporting).


Version 1.3.7 (released in 2013-01-28)
--------------------------------------

- [(ac18ff2)](https://github.com/versatica/OverSIP/commit/ac18ff28e2eaebfd9b3b0f69893e84adb5be04fb) Added `OverSIP.root_fiber` attribute which stores the root `Fiber`.


Version 1.3.6 (released in 2013-01-03)
--------------------------------------

- [(0a858b1)](https://github.com/versatica/OverSIP/commit/0a858b11bb1351b85690f8a5aabbf7d467ed8792) Encode the body in UTF-8 also when received via WebSocket.

- `s/2012/2013/g`.


Version 1.3.5 (released in 2012-12-17)
--------------------------------------

- [(6ee6b8c)](https://github.com/versatica/OverSIP/commit/6ee6b8c808e24ad9680291e67ff85ca30889cb2f) Fixed a bug in name_addr.rb that prevents the NameAddr to be printed until some URI field is modified.

- [(9b20db3)](https://github.com/versatica/OverSIP/commit/9b20db392711e89ae3971945bcd2916df18f3907) Add via_branch_id attr reader to UacRequest to avoid a bug in `OverSIP::SIP::Uac#route()` method.



Version 1.3.3 (released in 2012-11-15)
--------------------------------------

- [(d9eee0d)](https://github.com/versatica/OverSIP/commit/d9eee0dbe0f7e0b9a9d8527ca9c57dc67cda0a8c) Improved OverSIP security limits (Posix Message Queue) for Debian/Ubuntu (fixes [bug #27](https://github.com/versatica/OverSIP/issues/27)).

- [(834462a)](https://github.com/versatica/OverSIP/commit/834462ab8481dd9855c501fe52247a28f3700bef) Use C binary syntax 0x1 instead of 0b00000001 (fixes [bug #23](https://github.com/versatica/OverSIP/issues/23) and [bug #29](https://github.com/versatica/OverSIP/issues/29)).



Version 1.3.2 (released in 2012-11-03)
--------------------------------------

- [(3d7fa9e)](https://github.com/versatica/OverSIP/commit/3d7fa9e4440968b7c13fe4c65b764ed71d084ec8) Fixed a bug that writes an empty Record-Route header when an INVITE asking for incoming Outbound support comes from a TCP connection initiated by OverSIP.


Version 1.3.1 (released in 2012-10-04)
--------------------------------------

- [(042fdaf)](https://github.com/versatica/OverSIP/commit/042fdaf17bfeddf22ffa80637b0e0fb387a77bff) Fixed an important bug in record-routing mechanism that makes OverSIP not to add Record-Route/Path headers.


Version 1.3.0 (released in 2012-10-04)
--------------------------------------

- [(6afa5a6)](https://github.com/versatica/OverSIP/commit/6afa5a6c2572aea4b78a3aba2fc5d2f0d81d96ce) All the callbacks in `server.rb` are now executed within a new [Fiber](http://www.ruby-doc.org/core-1.9.3/Fiber.html) allowing synchronous style coding by using [em-synchrony](https://github.com/igrigorik/em-synchrony) libraries.

- [(b950bba)](https://github.com/versatica/OverSIP/commit/b950bba6aa8d7e3e28d69f7fb3d850a4719e02ba) New class `OverSIP::SIP::Uac`that allows OverSIP behaving as a UAC for generating and sending SIP requests. New class `OverSIP::SIP::UacRequest` for generating requests to be sent via `OverSIP::SIP::Uac#route` method (also allows sending a received `OverSIP::SIP::Request` instance).

- New methods `initialize()`, `sip?`, `tel?` and `get_param()` for `OverSIP::SIP::Uri` class ([doc](http://www.oversip.net/documentation/1.3.x/api/sip/uri/)).

- New class `OverSIP::SIP::Client`, parent class of `OverSIP::SIP::Proxy` and `OverSIP::SIP::Uac`. New method `add_target_to_blacklist()` ([doc](http://www.oversip.net/documentation/1.3.x/api/sip/client/)).

- `OverSIP::SIP::Client#on_error()` method is now called with a third argument: a Ruby symbol trat represents the exact (internal) error code.

- `OverSIP::SIP::Client#on_target()` callback is now called with a single parameter: the instance of `OverSIP::SIP::RFC3263::Target` (API change).

- [(7e9733e)](https://github.com/versatica/OverSIP/commit/7e9733e95f04158bb69ed13130984e335c80c73c) New feature: automatic blacklists. When a destination (target) fails due to timeout, connection error or TLS validation error, the target is added to a temporal blacklist and future requests to same target are not attempted until the entry in the blacklist expires.


Version 1.2.0 (released in 2012-09-04)
--------------------------------------

- [(c921687)](https://github.com/versatica/OverSIP/commit/c9216872ccd43c3977b8816551f33d9d0c178899) Added `on_target()` and `abort_routing()` methods for `Proxy` class.

- [(7e54d1c)](https://github.com/versatica/OverSIP/commit/7e54d1c89351e0517bc12d543e577dff46f251a4) Don't raise an exception if the received STUN request contains an invalid IP family (vulnerability!).

- [(f7eefd6)](https://github.com/versatica/OverSIP/commit/f7eefd6d8e02d30e61fd219f4426e6e63ea7f2a8) If request.from or request.to (`NameAddr` instances) are modified before routing the request, changes are applied for the outgoing request and reverted when sending responses upstream.

- [(0f9d3ec)](https://github.com/versatica/OverSIP/commit/0f9d3ec9da96c51197535bcd5f0c65e5749ec855) If request.contact `NameAddr` fields are modified then changes are applied in the forwarded request.

- [(df1389e)](https://github.com/versatica/OverSIP/commit/df1389eda22806dc48f6595cc3e6460c58391411) Added `SystemCallbacks` module for 3rd party modules to set custom callbacks when OverSIP is started, reloaded (HUP signal) or stopped.

- [(9d310d6)](https://github.com/versatica/OverSIP/commit/9d310d6678ee79c47d17b5aab010a49b8683c3da) Added `OverSIP::SIP::Uri#aor()`method which returns "sip:user@domain" for a SIP/SIPS URI (no port or params) and "tel:number" for a TEL URI (no params).

- [(56e099b)](https://github.com/versatica/OverSIP/commit/56e099bb0500e6cda221750ade7848fda614b522) Added a new method `OverSIP::SystemEvents.on_initialize()` useful for 3rd party modules configuration by the user.

- [(aac4bad)](https://github.com/versatica/OverSIP/commit/aac4badafd924cdbd3344a6636fa9588d0b84c79) `OverSIP::SIP::Modules::RegistrarWithoutPath` renamed to `OverSIP::SIP::Modules::OutboundMangling`.

- [(ce48977)](https://github.com/versatica/OverSIP/commit/ce48977ca786def6d9c9f8af8d743da7c105dcf6) `OverSIP::SIP::Modules::Core` moved to `OverSIP::SIP::Core`.

- [(98e5308)](https://github.com/versatica/OverSIP/commit/98e530869e57150778327b29e5a977b2f6985f8d)` OverSIP::SIP::Modules` moved to `OverSIP::Modules`.


Version 1.1.2 (released in 2012-08-28)
--------------------------------------

- [(d91d2e4)](https://github.com/versatica/OverSIP/commit/d91d2e4899a777dd7dd101e83fe36a1bca744398) Require EventMachine-LE >= 1.1.3 which includes the `:use_tls` option for selecting TLSv1 or SSLv23 (fixes [#12](https://github.com/versatica/OverSIP/issues/12)).
