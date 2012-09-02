CHANGELOG
=========


Version 1.2.0 (dev)
-------------------

- Added `on_target()` and `abort_routing()` methods for `Proxy` class [(c178899)](https://github.com/versatica/OverSIP/commit/c9216872ccd43c3977b8816551f33d9d0c178899).

- Don't raise an exception if the received STUN request contains an invalid IP family (vulnerability!) [(6f251a4)](https://github.com/versatica/OverSIP/commit/7e54d1c89351e0517bc12d543e577dff46f251a4).

- If request.from or request.to (`NameAddr` instances) are modified before routing the request, changes are applied for the outgoing request and reverted when sending responses upstream [(ea7f2a8)](https://github.com/versatica/OverSIP/commit/f7eefd6d8e02d30e61fd219f4426e6e63ea7f2a8).

- If request.contact `NameAddr` fields are modified then changes are applied in the forwarded request [(49ec855)](https://github.com/versatica/OverSIP/commit/0f9d3ec9da96c51197535bcd5f0c65e5749ec855).

- Added `SystemCallbacks` module for 3rd party modules to set custom callbacks when OverSIP is started, reloaded (HUP signal) or stopped [(8391411)](https://github.com/versatica/OverSIP/commit/df1389eda22806dc48f6595cc3e6460c58391411).

- Added /etc/oversip/modules_conf/ for 3rd party OverSIP modules user configuration [(fb1cdec)](https://github.com/versatica/OverSIP/commit/0da18d477cbfce251fd8f004f1c6a2b22fb1cdec) (feature [#15](https://github.com/versatica/OverSIP/issues/15)).

- Added `OverSIP::SIP::Uri#aor()`method which returns "sip(s):user@domain" for a SIP URI (no port or params) and "tel:number" for a TEL URI (no params) [(683c3da)](https://github.com/versatica/OverSIP/commit/9d310d6678ee79c47d17b5aab010a49b8683c3da).


Version 1.1.2
-------------

- Require EventMachine-LE >= 1.1.3 which includes the `:use_tls` option for selecting TLSv1 or SSLv23 [(a744398)](https://github.com/versatica/OverSIP/commit/d91d2e4899a777dd7dd101e83fe36a1bca744398) (fixes [#12](https://github.com/versatica/OverSIP/issues/12)).
