#include <stdlib.h>
#include <string.h>
#include "outbound_utils.h"


/** machine **/
%%{
  machine utils_outbound_udp_flow_token_parser;


  action is_ipv4 {
    outbound_udp_flow_token.ip_type = outbound_udp_flow_token_ip_type_ipv4;
  }

  action is_ipv6 {
    outbound_udp_flow_token.ip_type = outbound_udp_flow_token_ip_type_ipv6;
  }

  action start_ip {
    outbound_udp_flow_token.ip_s = (size_t)fpc;
  }

  action end_ip {
    outbound_udp_flow_token.ip_len = (size_t)fpc - outbound_udp_flow_token.ip_s;
  }

  action start_port {
    outbound_udp_flow_token.port_s = (size_t)fpc;
  }

  action end_port {
    outbound_udp_flow_token.port_len = (size_t)fpc - outbound_udp_flow_token.port_s + 1;
    finished = 1;
  }

  include grammar_ip           "grammar_ip.rl";

  main                         := ( IPv4address %is_ipv4 | IPv6address %is_ipv6 ) >start_ip %end_ip "_" port >start_port @end_port;
}%%

/** Data **/
%% write data;


/** exec **/
/*
 * Expects a string like "1.2.3.4_5060" or "1af:43::ab_9090" (no "_" at the beginning).
 */
struct_outbound_udp_flow_token outbound_udp_flow_token_parser_execute(const char *str, size_t len)
{
  int cs = 0;
  const char *p, *pe;
  size_t mark;
  int finished = 0;
  struct_outbound_udp_flow_token outbound_udp_flow_token;

  p = str;
  pe = str+len;

  outbound_udp_flow_token.valid = 0;
  outbound_udp_flow_token.ip_s = 0;
  outbound_udp_flow_token.ip_len = 0;
  outbound_udp_flow_token.port_s = 0;
  outbound_udp_flow_token.port_len = 0;

  %% write init;
  %% write exec;

  if(finished && len == p-str)
    outbound_udp_flow_token.valid = 1;

  return outbound_udp_flow_token;
}

