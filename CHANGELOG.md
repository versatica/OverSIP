CHANGELOG
=========


Version 1.1.3.beta1
-------------------

2012-08-29

- Don't raise an exception if the received STUN request contains an invalid IP family (vulnerability!).
  [Commit](https://github.com/versatica/OverSIP/commit/7e54d1c89351e0517bc12d543e577dff46f251a4)

- If request.from or request.to (NameAddr instances) are modified before routing the request,
  changes are applied for the outgoing request and reverted when sending responses upstream.
  [Commit](https://github.com/versatica/OverSIP/commit/f7eefd6d8e02d30e61fd219f4426e6e63ea7f2a8)


Version 1.1.2
-------------

2012-08-28

- Require EventMachine-LE >= 1.1.3 which includes the :use_tls option for selecting TLSv1 or SSLv23.
  [Fixed #12](https://github.com/versatica/OverSIP/issues/12): "Need to use TLS1.0 in outbound TLS connection"
  [Commit](https://github.com/versatica/OverSIP/commit/d91d2e4899a777dd7dd101e83fe36a1bca744398)
