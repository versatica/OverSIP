#include <stdlib.h>
#include <string.h>
#include "haproxy_protocol.h"


/** machine **/
%%{
  machine utils_haproxy_protocol_parser;


  action is_ipv4 {
    haproxy_protocol.ip_type = haproxy_protocol_ip_type_ipv4;
  }

  action is_ipv6 {
    haproxy_protocol.ip_type = haproxy_protocol_ip_type_ipv6;
  }

  action start_ip {
    haproxy_protocol.ip_s = (size_t)fpc;
  }

  action end_ip {
    haproxy_protocol.ip_len = (size_t)fpc - haproxy_protocol.ip_s;
  }

  action start_port {
    haproxy_protocol.port_s = (size_t)fpc;
  }

  action end_port {
    haproxy_protocol.port_len = (size_t)fpc - haproxy_protocol.port_s + 1;
  }

  action done {
    finished = 1;
  }

  include grammar_ip           "grammar_ip.rl";

  main                         := "PROXY TCP" ( "4" | "6" ) " "
                                  ( IPv4address %is_ipv4 | IPv6address %is_ipv6 ) >start_ip %end_ip " "
                                  ( IPv4address | IPv6address ) " "
                                  port >start_port @end_port " "
                                  port "\r\n"
                                  @done;
}%%

/** Data **/
%% write data;


/** exec **/
/*
 * Expects a string like "PROXY TCP4 192.168.0.1 192.168.0.11 56324 443\r\n".
 */
struct_haproxy_protocol struct_haproxy_protocol_parser_execute(const char *str, size_t len)
{
  int cs = 0;
  const char *p, *pe;
  size_t mark;
  int finished = 0;
  struct_haproxy_protocol haproxy_protocol;

  p = str;
  pe = str+len;

  haproxy_protocol.valid = 0;
  haproxy_protocol.total_len = 0;
  haproxy_protocol.ip_s = 0;
  haproxy_protocol.ip_len = 0;
  haproxy_protocol.port_s = 0;
  haproxy_protocol.port_len = 0;

  %% write init;
  %% write exec;

  if(finished && len == p-str)
    haproxy_protocol.valid = 1;

  /* Write the number of read bytes so the HAProxy Protocol line can be removed. */
  haproxy_protocol.total_len = (int)(p - str);

  return haproxy_protocol;
}

