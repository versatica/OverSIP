#ifndef ip_utils_h
#define ip_utils_h

#include <string.h>
#include <netinet/in.h>


enum enum_ip_type {
  ip_type_ipv4 = 1,
  ip_type_ipv6,
  ip_type_ipv6_reference,
  ip_type_error
};


enum enum_ip_type utils_ip_parser_execute(const char *str, size_t len);


/*! \brief Return 1 if both pure IP's are equal, 0 otherwise. */
static int utils_compare_pure_ips(char *ip1, size_t len1, enum enum_ip_type ip1_type, char *ip2, size_t len2, enum enum_ip_type ip2_type)
{
  struct in_addr in_addr1, in_addr2;
  struct in6_addr in6_addr1, in6_addr2;
  char _ip1[INET6_ADDRSTRLEN+1], _ip2[INET6_ADDRSTRLEN+1];

  /* Not same IP type, return false. */
  if (ip1_type != ip2_type)
    return 0;

  memcpy(_ip1, ip1, len1);
  _ip1[len1] = '\0';
  memcpy(_ip2, ip2, len2);
  _ip2[len2] = '\0';

  switch(ip1_type) {
    /* Comparing IPv4 with IPv4. */
    case(ip_type_ipv4):
      if (inet_pton(AF_INET, _ip1, &in_addr1) == 0)  return 0;
      if (inet_pton(AF_INET, _ip2, &in_addr2) == 0)  return 0;
      if (in_addr1.s_addr == in_addr2.s_addr)
        return 1;
      else
        return 0;
      break;
    /* Comparing IPv6 with IPv6. */
    case(ip_type_ipv6):
      if (inet_pton(AF_INET6, _ip1, &in6_addr1) != 1)  return 0;
      if (inet_pton(AF_INET6, _ip2, &in6_addr2) != 1)  return 0;
      if (memcmp(in6_addr1.s6_addr, in6_addr2.s6_addr, sizeof(in6_addr1.s6_addr)) == 0)
        return 1;
      else
        return 0;
      break;
    default:
      return 0;
      break;
  }
}


#endif
