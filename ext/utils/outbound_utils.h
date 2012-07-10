#ifndef outbound_utils_h
#define outbound_utils_h


#include <sys/types.h>


enum enum_outbound_udp_flow_token_ip_type {
  outbound_udp_flow_token_ip_type_ipv4 = 1,
  outbound_udp_flow_token_ip_type_ipv6
};


typedef struct struct_outbound_udp_flow_token {
  unsigned short int                        valid;
  enum enum_outbound_udp_flow_token_ip_type ip_type;
  size_t                                    ip_s;
  size_t                                    ip_len;
  size_t                                    port_s;
  size_t                                    port_len;
} struct_outbound_udp_flow_token;


struct_outbound_udp_flow_token outbound_udp_flow_token_parser_execute(const char *str, size_t len);


#endif
