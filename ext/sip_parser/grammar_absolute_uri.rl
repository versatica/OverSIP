%%{
  machine grammar_absolute_uri;

  abs_uri_reg_name            = ( unreserved | escaped | "$" | "," | ";" | ":" | "@" | "&" | "=" | "+" )+;
  abs_uri_srvr                = ( ( userinfo "@" )? hostport )?;
  abs_uri_authority           = abs_uri_srvr | abs_uri_reg_name;
  abs_uri_scheme              = ALPHA ( ALPHA | DIGIT | "+" | "-" | "." )* - ( "sip"i | "sips"i | "tel"i );
  abs_uri_pchar               = unreserved | escaped | ":" | "@" | "&" | "=" | "+" | "$" | ",";
  abs_uri_param                = ( abs_uri_pchar )*;
  abs_uri_segment             = ( abs_uri_pchar )* ( ";" abs_uri_param )*;
  abs_uri_path_segments       = abs_uri_segment ( "/" abs_uri_segment )*;
  abs_uri_uric                = reserved | unreserved | escaped;
  abs_uri_query               = ( abs_uri_uric )*;
  abs_uri_uric_no_slash       = abs_uri_uric - "/";
  abs_uri_opaque_part         = abs_uri_uric_no_slash ( abs_uri_uric )*;
  abs_uri_abs_path            = "/" abs_uri_path_segments;
  abs_uri_net_path            = "//" abs_uri_authority ( abs_uri_abs_path )?;
  # NOTE: Original BNF in RFC 3261 for absoluteURI doesn't allow "mailto:qwe@[::1]" (due to a bug in RFC 3986 URI). Fix it:
  #   http://crazygreek.co.uk/blogger/2009/03/sip-uri-syntax-is-broken-with-ipv6.html
  #   http://www.ietf.org/mail-archive/web/sip/current/msg26338.html
  #abs_uri_hier_part           = ( abs_uri_net_path | abs_uri_abs_path ) ( "?" abs_uri_query )?;
  abs_uri_hier_part           = ( abs_uri_net_path | abs_uri_abs_path | abs_uri_authority ) ( "?" abs_uri_query )?;

  absoluteURI                 = (
                                  abs_uri_scheme %uri_is_unknown >start_uri >mark %uri_scheme
                                  ":" ( abs_uri_hier_part | abs_uri_opaque_part )
                                ) %write_uri;
}%%