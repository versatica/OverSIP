%%{
  machine grammar_sip_uri;

  sip_uri_param_unreserved    = "[" | "]" | "/" | ":" | "&" | "+" | "$";
  sip_uri_paramchar           = sip_uri_param_unreserved | unreserved | escaped;
  #sip_uri_pname               = sip_uri_paramchar+;
  # Let's allow ugly devices that add parameters with "=" but no value!
  sip_uri_pname               = sip_uri_paramchar+ "="?;
  sip_uri_pvalue              = sip_uri_paramchar+;
  sip_uri_lr                  = "lr"i  %sip_uri_has_lr ( "=" token )?;
  sip_uri_ob                  = "ob"i  %sip_uri_has_ob ( "=" token )?;
  # Custom URI param for Route header inspection.
  # as it's not discarded in 'sip_uri_param'.
  sip_uri_ovid                = "ovid"i ( "=" token >mark %sip_uri_ovid )?;
  sip_uri_transport           = "transport="i
                                ( "udp"i  %sip_uri_transport_udp  |
                                  "tcp"i  %sip_uri_transport_tcp  |
                                  "tls"i  %sip_uri_transport_tls  |
                                  "sctp"i %sip_uri_transport_sctp |
                                  "ws"i %sip_uri_transport_ws |
                                  "wss"i %sip_uri_transport_wss |
                                  ( token - ( "udp"i | "tcp"i | "tls"i | "sctp"i | "ws"i | "wss"i ) ) >mark %sip_uri_transport_unknown );

  sip_uri_param               = ( sip_uri_pname >start_uri_param_key %uri_param_key_len
                                ( "=" sip_uri_pvalue >start_uri_param_value %uri_param_value_len )? %write_uri_param ) |
                                sip_uri_transport | sip_uri_lr | sip_uri_ob | sip_uri_ovid;

  sip_uri_params              = ( ";" sip_uri_param )*;

  sip_uri_hnv_unreserved      = "[" | "]" | "/" | "?" | ":" | "+" | "$";
  sip_uri_hname               = ( sip_uri_hnv_unreserved | unreserved | escaped )+;
  sip_uri_hvalue              = ( sip_uri_hnv_unreserved | unreserved | escaped )*;
  sip_uri_header              = sip_uri_hname "=" sip_uri_hvalue;
  sip_uri_headers             = "?" sip_uri_header ( "&" sip_uri_header )*;

  SIP_URI                     = (
                                  ( "sip"i %uri_is_sip | "sips"i %uri_is_sips ) >start_uri >mark %uri_scheme ":"
                                  ( userinfo >mark %uri_user "@" )?
                                  ( hostname %uri_host_domain |
                                    IPv4address %uri_host_ipv4 |
                                    IPv6reference %uri_host_ipv6 ) >mark
                                  ( ":" port  >mark %uri_port )?
                                  sip_uri_params
                                  ( sip_uri_headers >mark %uri_headers )?
                                ) %write_uri;

}%%