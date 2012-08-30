#include <ruby.h>
#include "ext_help.h"
#include "ip_utils.h"
#include "utils_ruby.h"
#include "../common/c_util.h"


static VALUE mOverSIP;
static VALUE mUtils;

static VALUE symbol_ipv4;
static VALUE symbol_ipv6;
static VALUE symbol_ipv6_reference;



/*
 * Ruby functions.
 */

VALUE Utils_is_ip(VALUE self, VALUE string)
{
  TRACE();
  char *str;
  long len;

  if (TYPE(string) != T_STRING)
    rb_raise(rb_eTypeError, "Argument must be a String");

  str = RSTRING_PTR(string);
  len = RSTRING_LEN(string);

  if (utils_ip_parser_execute(str, len) != ip_type_error)
    return Qtrue;
  else
    return Qfalse;
}


VALUE Utils_is_pure_ip(VALUE self, VALUE string)
{
  TRACE();
  char *str;
  long len;

  if (TYPE(string) != T_STRING)
    rb_raise(rb_eTypeError, "Argument must be a String");

  str = RSTRING_PTR(string);
  len = RSTRING_LEN(string);

  switch(utils_ip_parser_execute(str, len)) {
    case(ip_type_ipv4):
      return Qtrue;
      break;
    case(ip_type_ipv6):
      return Qtrue;
      break;
    default:
      return Qfalse;
      break;
  }
}


VALUE Utils_ip_type(VALUE self, VALUE string)
{
  TRACE();
  char *str;
  long len;
  
  if (TYPE(string) != T_STRING)
    rb_raise(rb_eTypeError, "Argument must be a String");

  str = RSTRING_PTR(string);
  len = RSTRING_LEN(string);

  switch(utils_ip_parser_execute(str, len)) {
    case(ip_type_ipv4):
      return symbol_ipv4;
      break;
    case(ip_type_ipv6):
      return symbol_ipv6;
      break;
    case(ip_type_ipv6_reference):
      return symbol_ipv6_reference;
      break;
    default:
      return Qfalse;
      break;
  }
}


/*
 * Returns true if both IP's are equal (binary comparison).
 * Returns false if both IP's are not equal.
 * Returns nil if at least one of the IP's is not valid IPv4, IPv6 or IPv6 reference.
 * This function also allows comparing an IPv6 with an IPv6 reference.
 */
VALUE Utils_compare_ips(VALUE self, VALUE string1, VALUE string2)
{
  TRACE();
  char *str1, *str2;
  long len1, len2;
  enum enum_ip_type ip1_type, ip2_type;

  if (TYPE(string1) != T_STRING || TYPE(string2) != T_STRING)
    rb_raise(rb_eTypeError, "Arguments must be two String");

  str1 = RSTRING_PTR(string1);
  len1 = RSTRING_LEN(string1);
  str2 = RSTRING_PTR(string2);
  len2 = RSTRING_LEN(string2);

  switch(ip1_type = utils_ip_parser_execute(str1, len1)) {
    case(ip_type_error):
      return Qnil;
      break;
    case(ip_type_ipv6_reference):
      str1 += 1;
      len1 -= 2;
      ip1_type = ip_type_ipv6;
      break;
    default:
      break;
  }
  switch(ip2_type = utils_ip_parser_execute(str2, len2)) {
    case(ip_type_error):
      return Qnil;
      break;
    case(ip_type_ipv6_reference):
      str2 += 1;
      len2 -= 2;
      ip2_type = ip_type_ipv6;
      break;
    default:
      break;
  }

  if (utils_compare_pure_ips(str1, len1, ip1_type, str2, len2, ip2_type))
    return Qtrue;
  else
    return Qfalse;
}


/*
 * Returns true if both IP's are equal (binary comparison).
 * Returns false if both IP's are not equal.
 * Returns nil if at least one of the IP's is not valid IPv4 or IPv6.
 * This function does not allow comparing an IPv6 with an IPv6 reference.
 */
VALUE Utils_compare_pure_ips(VALUE self, VALUE string1, VALUE string2)
{
  TRACE();
  char *str1, *str2;
  long len1, len2;
  enum enum_ip_type ip1_type, ip2_type;

  if (TYPE(string1) != T_STRING || TYPE(string2) != T_STRING)
    rb_raise(rb_eTypeError, "Arguments must be two String");
  
  str1 = RSTRING_PTR(string1);
  len1 = RSTRING_LEN(string1);
  str2 = RSTRING_PTR(string2);
  len2 = RSTRING_LEN(string2);

  switch(ip1_type = utils_ip_parser_execute(str1, len1)) {
    case(ip_type_error):
      return Qnil;
      break;
    case(ip_type_ipv6_reference):
      return Qnil;
      break;
    default:
      break;
  }
  switch(ip2_type = utils_ip_parser_execute(str2, len2)) {
    case(ip_type_error):
      return Qnil;
      break;
    case(ip_type_ipv6_reference):
      return Qnil;
      break;
    default:
      break;
  }

  if (utils_compare_pure_ips(str1, len1, ip1_type, str2, len2, ip2_type))
    return Qtrue;
  else
    return Qfalse;
}


/*
 * Returns the normalized printable string of the given IPv6.
 * - First argument is a string to normalize. It must be a valid IPv6 or
 *   IPv6 reference. If not, the method returns false.
 * - Second argument is optional. If true, returned value is a pure IPv6 even
 *   if the first argument is a IPv6 reference.
 */
VALUE Utils_normalize_ipv6(int argc, VALUE *argv, VALUE self)
{
  TRACE();
  VALUE string;
  int force_pure_ipv6 = 0;

  if (argc == 0 || argc > 2)
    rb_raise(rb_eTypeError, "Wrong number of arguments (pass one or two)");

  string = argv[0];
  if (TYPE(string) != T_STRING)
    rb_raise(rb_eTypeError, "First argument must be a String");

  if (argc == 2 && TYPE(argv[1]) != T_NIL && TYPE(argv[1]) != T_FALSE)
    force_pure_ipv6 = 1;

  return utils_normalize_ipv6(string, force_pure_ipv6);
}


/*
 * Returns the normalized printable string of the given IPv4 or IPv6.
 * - First argument is a string to normalize. It must be a valid IPv4, IPv6 or
 *   IPv6 reference. If not, the method returns the string itself.
 * - Second argument is the type of host (:ipv4, :ipv6, :ipv6_reference or :domain).
 * - Third argument is optional. If true, returned value is a pure IPv6 even
 *   if the first argument is a IPv6 reference.
 *
 * TODO: Not in use and seems really ugly!
 */
VALUE Utils_normalize_host(int argc, VALUE *argv, VALUE self)
{
  TRACE();
  VALUE host, ip_type;
  int force_pure_ipv6 = 0;

  if (argc == 0 || argc > 3)
    rb_raise(rb_eTypeError, "Wrong number of arguments (pass one, two or three)");

  host = argv[0];
  if (TYPE(host) != T_STRING)
    rb_raise(rb_eTypeError, "First argument must be a String");

  ip_type = argv[1];
  if (TYPE(ip_type) != T_SYMBOL)
    rb_raise(rb_eTypeError, "Second argument must be a Symbol (:ipv4, :ipv6 or :domain)");

  if (argc == 3 && TYPE(argv[2]) != T_NIL && TYPE(argv[2]) != T_FALSE)
    force_pure_ipv6 = 1;

  if (ip_type == symbol_ipv6 || ip_type == symbol_ipv6_reference)
    return utils_normalize_ipv6(host, force_pure_ipv6);
  else
    return host;
}


/*
 * If the given argument is a IPV6 reference it returns a new string with the pure IPv6.
 * In any other case, return the given argument.
 *
 * TODO: Not documented in the API (seems ugly).
 */
VALUE Utils_to_pure_ip(VALUE self, VALUE string)
{
  TRACE();
  char *str;

  str = StringValueCStr(string);
  if (str[0] == '[')
    return rb_str_new(RSTRING_PTR(string)+1, RSTRING_LEN(string)-2);
  else
    return string;
}


/*
 * TODO: We lack a simple "normalice_host(ip)" method that parses the given ip and so on...
 */


/*
 * Expects a string like "1.2.3.4_5060" or "1af:43::ab_9090" and returns
 * an Array as follows:
 *   [ ip_type, ip, port ]
 * where:
 *   - ip_type is :ipv4 or :ipv6,
 *   - ip is a String,
 *   - port is a Fixnum
 * If the string is invalid it returns false.
 */
VALUE Utils_parser_outbound_udp_flow_token(VALUE self, VALUE string)
{
  TRACE();
  char *str = NULL;
  long len = 0;
  struct_outbound_udp_flow_token outbound_udp_flow_token;
  VALUE ip_type, ip, port;

  if (TYPE(string) != T_STRING)
    rb_raise(rb_eTypeError, "Argument must be a String");

  str = RSTRING_PTR(string);
  len = RSTRING_LEN(string);

  /* Remove the leading "_" from the string. */
  outbound_udp_flow_token = outbound_udp_flow_token_parser_execute(str, len);

  if (outbound_udp_flow_token.valid == 0)
    return Qfalse;
  else {
    if (outbound_udp_flow_token.ip_type == outbound_udp_flow_token_ip_type_ipv4)
      ip_type = symbol_ipv4;
    else
      ip_type = symbol_ipv6;

    ip = rb_str_new((char *)outbound_udp_flow_token.ip_s, outbound_udp_flow_token.ip_len);
    port = INT2FIX(str_to_int((char *)outbound_udp_flow_token.port_s, outbound_udp_flow_token.port_len));

    return rb_ary_new3(3, ip_type, ip, port);
  }
}


/*
 * Expects a string like "PROXY TCP4 192.168.0.1 192.168.0.11 56324 443\r\n" and returns
 * an Array as follows:
 *   [ num_bytes, ip_type, ip, port ]
 * where:
 *   - num_bytes is the length of the HAProxy Protocol line (to be removed), a Fixnum.
 *   - ip_type is :ipv4 or :ipv6,
 *   - ip is a String,
 *   - port is a Fixnum
 * If the string is invalid it returns false.
 */
VALUE Utils_parser_haproxy_protocol(VALUE self, VALUE string)
{
  TRACE();
  char *str = NULL;
  long len = 0;
  struct_haproxy_protocol haproxy_protocol;
  VALUE num_bytes, ip_type, ip, port;

  if (TYPE(string) != T_STRING)
    rb_raise(rb_eTypeError, "Argument must be a String");

  str = RSTRING_PTR(string);
  len = RSTRING_LEN(string);

  haproxy_protocol = struct_haproxy_protocol_parser_execute(str, len);

  if (haproxy_protocol.valid == 0)
    return Qfalse;
  else {
    if (haproxy_protocol.ip_type == haproxy_protocol_ip_type_ipv4)
      ip_type = symbol_ipv4;
    else
      ip_type = symbol_ipv6;

    ip = rb_str_new((char *)haproxy_protocol.ip_s, haproxy_protocol.ip_len);
    port = INT2FIX(str_to_int((char *)haproxy_protocol.port_s, haproxy_protocol.port_len));
    num_bytes = INT2FIX(haproxy_protocol.total_len);

    return rb_ary_new3(4, num_bytes, ip_type, ip, port);
  }
}


void Init_utils()
{
  TRACE();

  mOverSIP = rb_define_module("OverSIP");
  mUtils = rb_define_module_under(mOverSIP, "Utils");

  rb_define_module_function(mUtils, "ip?", Utils_is_ip, 1);
  rb_define_module_function(mUtils, "pure_ip?", Utils_is_pure_ip, 1);
  rb_define_module_function(mUtils, "ip_type", Utils_ip_type, 1);
  rb_define_module_function(mUtils, "compare_ips", Utils_compare_ips, 2);
  rb_define_module_function(mUtils, "compare_pure_ips", Utils_compare_pure_ips, 2);
  rb_define_module_function(mUtils, "normalize_ipv6", Utils_normalize_ipv6, -1);
  rb_define_module_function(mUtils, "normalize_host", Utils_normalize_host, -1);
  rb_define_module_function(mUtils, "to_pure_ip", Utils_to_pure_ip, 1);
  rb_define_module_function(mUtils, "parse_outbound_udp_flow_token", Utils_parser_outbound_udp_flow_token, 1);
  rb_define_module_function(mUtils, "parse_haproxy_protocol", Utils_parser_haproxy_protocol, 1);

  symbol_ipv4 = ID2SYM(rb_intern("ipv4"));
  symbol_ipv6 = ID2SYM(rb_intern("ipv6"));
  symbol_ipv6_reference = ID2SYM(rb_intern("ipv6_reference"));
}
