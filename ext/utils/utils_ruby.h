/*
 * This file is not used by Ruby OverSIP::Utils module itself, its aim is to
 * be included by other OverSIP Ruby C extensions.
 */

#ifndef utils_ruby_h
#define utils_ruby_h


#include "ip_utils.h"
#include "outbound_utils.h"
#include "haproxy_protocol.h"
#include <arpa/inet.h>  // inet_ntop()


/* Export the Ruby C functions so other C libraries within OverSIP can use them. */
VALUE Utils_is_ip(VALUE self, VALUE string);
VALUE Utils_is_pure_ip(VALUE self, VALUE string);
VALUE Utils_ip_type(VALUE self, VALUE string);
VALUE Utils_compare_ips(VALUE self, VALUE string1, VALUE string2);
VALUE Utils_compare_pure_ips(VALUE self, VALUE string1, VALUE string2);
VALUE Utils_normalize_ipv6(int argc, VALUE *argv, VALUE self);
VALUE Utils_normalize_host(int argc, VALUE *argv, VALUE self);
VALUE Utils_to_pure_ip(VALUE self, VALUE string);
VALUE Utils_parser_outbound_udp_flow_token(VALUE self, VALUE string);
VALUE Utils_parser_haproxy_protocol(VALUE self, VALUE string);


VALUE utils_normalize_ipv6(VALUE string, int force_pure_ipv6)
{
  struct in6_addr addr;
  char normalized_ipv6[INET6_ADDRSTRLEN + 1];
  char normalized_ipv6_reference[INET6_ADDRSTRLEN + 3];
  char *str, str2[INET6_ADDRSTRLEN + 3], *str_pointer;
  int is_ipv6_reference = 0;

  str = StringValueCStr(string);
  if (str[0] != '[') {
    str_pointer = str;
  }
  else {
    is_ipv6_reference = 1;
    memcpy(str2, str + 1, strlen(str) - 2);
    str2[strlen(str) - 2] = '\0';
    str_pointer = str2;
  }

  switch(inet_pton(AF_INET6, str_pointer, &addr)) {
    /* Not a valid IPv6. */
    case 0:
      return Qfalse;
      break;
    /* Some error ocurred. */
    case -1:
      return Qnil;
      break;
    default:
      break;
  }

  if (inet_ntop(AF_INET6, &addr, normalized_ipv6, INET6_ADDRSTRLEN))
    if (is_ipv6_reference && !force_pure_ipv6) {
      memcpy(normalized_ipv6_reference, "[", 1);
      memcpy(normalized_ipv6_reference + 1, normalized_ipv6, strlen(normalized_ipv6));
      memcpy(normalized_ipv6_reference + strlen(normalized_ipv6) + 1, "]\0", 2);
      return rb_str_new_cstr(normalized_ipv6_reference);
    }
    else
      return rb_str_new_cstr(normalized_ipv6);
  /* Some error ocurred. */
  else
    return Qnil;
}


#endif
