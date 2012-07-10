#ifndef haproxy_protocol_h
#define haproxy_protocol_h


#include <sys/types.h>


enum enum_haproxy_protocol_ip_type {
  haproxy_protocol_ip_type_ipv4 = 1,
  haproxy_protocol_ip_type_ipv6
};


typedef struct struct_haproxy_protocol {
  unsigned short int                        valid;
  unsigned short int                        total_len;
  enum enum_haproxy_protocol_ip_type        ip_type;
  size_t                                    ip_s;
  size_t                                    ip_len;
  size_t                                    port_s;
  size_t                                    port_len;
} struct_haproxy_protocol;


struct_haproxy_protocol struct_haproxy_protocol_parser_execute(const char *str, size_t len);

#endif
