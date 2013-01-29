#include "sip_parser.h"
#include "ext_help.h"
#include <stdio.h>
#include <assert.h>
#include <stdlib.h>
#include <ctype.h>
#include <string.h>

#define MARK(M, FPC) (parser->M = (FPC) - buffer)
#define LEN(AT, FPC) (FPC - buffer - parser->AT)
#define PTR_TO(F) (buffer + parser->F)




/** machine **/
%%{
  machine sip_uri_parser;


  action mark { MARK(mark, fpc); }

  action uri_is_sip {
    parser->uri_scheme = uri_scheme_sip;
  }

  action uri_is_sips {
    parser->uri_scheme = uri_scheme_sips;
  }

  action uri_is_tel {
    parser->uri_scheme = uri_scheme_tel;
  }

  action uri_is_unknown {
    parser->uri_scheme = uri_scheme_unknown;
  }

  action uri_scheme {
    parser->uri.scheme(parser->parsed, parser->parsed, PTR_TO(mark), LEN(mark, fpc), parser->uri_scheme);
  }

  action uri_user {
    parser->uri.user(parser->parsed, parser->parsed, PTR_TO(mark), LEN(mark, fpc), parser->uri_scheme);
  }

  action uri_host_domain {
    parser->uri.host(parser->parsed, parser->parsed, PTR_TO(mark), LEN(mark, fpc), host_type_domain);
  }

  action uri_host_ipv4 {
    parser->uri.host(parser->parsed, parser->parsed, PTR_TO(mark), LEN(mark, fpc), host_type_ipv4);
  }

  action uri_host_ipv6 {
    parser->uri.host(parser->parsed, parser->parsed, PTR_TO(mark), LEN(mark, fpc), host_type_ipv6);
  }

  action uri_port {
    parser->uri.port(parser->parsed, parser->parsed, PTR_TO(mark), LEN(mark, fpc), parser->uri_scheme);
  }


  action start_uri_param_key {
    MARK(uri_param_key_start, fpc);
  }

  action uri_param_key_len {
    parser->uri_param_key_len = LEN(uri_param_key_start, fpc);
    /* If current param has no value don't take previous param's value. */
    parser->uri_param_value_len = 0;
  }

  action start_uri_param_value {
    MARK(uri_param_value_start, fpc);
  }

  action uri_param_value_len {
    parser->uri_param_value_len = LEN(uri_param_value_start, fpc);
  }

  action write_uri_param {
    parser->uri.param(parser->parsed, parser->parsed, PTR_TO(uri_param_key_start), parser->uri_param_key_len, PTR_TO(uri_param_value_start), parser->uri_param_value_len);
  }


  action uri_headers {
    parser->uri.headers(parser->parsed, parser->parsed, PTR_TO(mark), LEN(mark, fpc), parser->uri_scheme);
  }

  action uri_tel_phone_context {
    parser->uri.known_param(parser->parsed, parser->parsed, uri_tel_phone_context, PTR_TO(mark), LEN(mark, fpc), 0);
  }

  action sip_uri_transport_udp {
    parser->uri.known_param(parser->parsed, parser->parsed, uri_param_transport, PTR_TO(mark), LEN(mark, fpc), transport_udp);
  }

  action sip_uri_transport_tcp {
    parser->uri.known_param(parser->parsed, parser->parsed, uri_param_transport, PTR_TO(mark), LEN(mark, fpc), transport_tcp);
  }

  action sip_uri_transport_tls {
    parser->uri.known_param(parser->parsed, parser->parsed, uri_param_transport, PTR_TO(mark), LEN(mark, fpc), transport_tls);
  }

  action sip_uri_transport_sctp {
    parser->uri.known_param(parser->parsed, parser->parsed, uri_param_transport, PTR_TO(mark), LEN(mark, fpc), transport_sctp);
  }

  action sip_uri_transport_ws {
    parser->uri.known_param(parser->parsed, parser->parsed, uri_param_transport, PTR_TO(mark), LEN(mark, fpc), transport_ws);
  }

  action sip_uri_transport_wss {
    parser->uri.known_param(parser->parsed, parser->parsed, uri_param_transport, PTR_TO(mark), LEN(mark, fpc), transport_wss);
  }

  action sip_uri_transport_unknown {
    parser->uri.known_param(parser->parsed, parser->parsed, uri_param_transport, PTR_TO(mark), LEN(mark, fpc), transport_unknown);
  }

  action sip_uri_has_lr {
    parser->uri.has_param(parser->parsed, parser->parsed, uri_param_lr);
  }

  action sip_uri_has_ob {
    parser->uri.has_param(parser->parsed, parser->parsed, uri_param_ob);
  }

  action sip_uri_ovid {
    parser->uri.known_param(parser->parsed, parser->parsed, uri_param_ovid, PTR_TO(mark), LEN(mark, fpc), 0);
  }

  action uri_display_name {
    if (!parser->uri_display_name_quoted)
      parser->uri.display_name(parser->parsed, parser->parsed, PTR_TO(mark), LEN(mark, fpc), parser->uri_scheme);
    else
      parser->uri.display_name(parser->parsed, parser->parsed, PTR_TO(mark)+1, LEN(mark, fpc)-2, parser->uri_scheme);
  }

  # This is for removing double quotes in display name.
  action uri_display_name_quoted {
    parser->uri_display_name_quoted=1;
  }

  action start_uri {
    MARK(uri_start, fpc);
  }

  action write_uri {
    parser->uri.full(parser->parsed, parser->parsed, PTR_TO(uri_start), LEN(uri_start, fpc), parser->uri_scheme);
  }


  action done { fbreak; }

  # Condition for when parsing a URI.
  action parsing_uri {
    allow_name_addr == 0
  }

  # Condition for when parsing a NameAddr.
  action parsing_name_addr {
    allow_name_addr == 1
  }


  include grammar_sip_core      "grammar_sip_core.rl";
  include grammar_sip_uri       "grammar_sip_uri.rl";
  include grammar_tel_uri       "grammar_tel_uri.rl";
  include grammar_absolute_uri  "grammar_absolute_uri.rl";
  include grammar_name_addr     "grammar_name_addr.rl";

  header_param_gen_value      = token | host | quoted_string;
  header_param                = token ( EQUAL header_param_gen_value )? ;

  # The given string ends with '\0'.
  main  :=  (
              ( SIP_URI | TEL_URI | absoluteURI ) when parsing_uri |
              ( ( name_addr | ( addr_spec -- ( "," | "?" | ";" ) ) ) ( SEMI header_param )* ) when parsing_name_addr
            ) '\0' @done;
}%%



/** Data **/
%% write data;


/** reset **/
void sip_uri_parser_reset(sip_uri_parser *parser)
{
  TRACE();

  parser->mark = 0;
  parser->uri_start = 0;
  parser->uri_param_key_start = 0;
  parser->uri_param_value_start = 0;
  parser->uri_scheme = 0;
  parser->uri_display_name_quoted = 0;
}


/** exec **/
int sip_uri_parser_execute(sip_uri_parser *parser, const char *buffer, size_t len, VALUE parsed, int allow_name_addr)
{
  TRACE();
  int cs = 0;
  const char *p, *pe;

  p = buffer;
  pe = buffer+len;

  parser->parsed = parsed;

  sip_uri_parser_reset(parser);

  %% write init;
  %% write exec;

  sip_uri_parser_reset(parser);

  /* Error? */
  if(len != p-buffer)
    return 1;

  return 0;
}
