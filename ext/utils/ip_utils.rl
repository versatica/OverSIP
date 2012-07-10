#include <stdlib.h>
#include "ip_utils.h"


/** machine **/
%%{
  machine utils_ip_parser;


  action is_ipv4 {
    ip_type = ip_type_ipv4;
  }

  action is_ipv6 {
    ip_type = ip_type_ipv6;
  }

  action is_ipv6_reference {
    ip_type = ip_type_ipv6_reference;
  }

  include grammar_ip           "grammar_ip.rl";

  IPv6reference                 = "[" IPv6address "]";

  main                         := IPv4address @is_ipv4 |
                                  IPv6address @is_ipv6 |
                                  IPv6reference @is_ipv6_reference;
}%%

/** Data **/
%% write data;


/** exec **/
enum enum_ip_type utils_ip_parser_execute(const char *str, size_t len)
{
  int cs = 0;
  const char *p, *pe;
  enum enum_ip_type ip_type = ip_type_error;

  p = str;
  pe = str+len;

  %% write init;
  %% write exec;

  if(len != p-str)
    return ip_type_error;
  else
    return ip_type;
}

