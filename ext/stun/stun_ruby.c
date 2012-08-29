#include <ruby.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include "ext_help.h"


#define STUN_MESSAGE_MIN_SIZE 20
#define STUN_MAGIC_COOKIE_LEN 4
#define STUN_TRANSACTION_ID_LEN 12
#define STUN_BINDING_SUCCESS_RESPONSE_IPV4_SIZE 32
#define STUN_BINDING_SUCCESS_RESPONSE_IPV6_SIZE 44


static VALUE mOverSIP;
static VALUE mStun;


/*
 * Ruby functions.
 */


/*
 * RFC 5389.
 *
 * 6.  STUN Message Structure
 *
 *   0                   1                   2                   3
 *   0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
 *   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 *   |0 0|     STUN Message Type     |         Message Length        |
 *   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 *   |                         Magic Cookie                          |
 *   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 *   |                                                               |
 *   |                     Transaction ID (96 bits)                  |
 *   |                                                               |
 *   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 *
 */


/*
 * Expects 3 arguments:
 * - String containing a STUN Binding Request (MUST not be empty!!).
 * - String containing the source IP of the request.
 * - Fxinum containing the source port of the request.
 * Return value:
 * - If it's a valid STUN Binding Request, returns a Ruby String representing the
 *   STUN Binding Response.
 * - If it seems a valid STUN message but not a valid STUN Binding Request, returns _false_.
 * - Otherwise returns _nil_ (so it could be a SIP message).
 */
VALUE Stun_parse_request(VALUE self, VALUE rb_stun_request, VALUE rb_source_ip, VALUE rb_source_port)
{
  TRACE();

  char *request = NULL;
  size_t request_len = 0;
  char *source_ip = NULL;
  short source_ip_is_ipv6 = 0;
  uint16_t source_port;

  char *transaction_id;
  uint16_t message_length;
  char *magic_cookie;
  short is_rfc3489_client = 0;

  struct in_addr in_addr_ipv4;
  struct in6_addr in_addr_ipv6;
  uint16_t xor_port;
  uint32_t xor_ipv4;
  unsigned char xor_ipv6[16];

  /* The size of our STUN Binding Response is the sum of:
   * - STUN message header: 20 bytes.
   * - One attribute (XOR-MAPPED-ADDRESS or MAPPED-ADDRESS).
   *    - Type + Length: 4 bytes.
   *    - XOR-MAPPED-ADDRESS or MAPPED-ADDRESS for IPv4: 4 + 4 = 8 bytes.
   *    - XOR-MAPPED-ADDRESS or MAPPED-ADDRESS for IPv6: 4 + 16 = 20 bytes.
   * - Size for a response with IPv4: 20 + 4 + 8 = 32 bytes.
   * - Size for a response with IPv6: 20 + 4 + 20 = 44 bytes.
   */
  char response[STUN_BINDING_SUCCESS_RESPONSE_IPV6_SIZE];

  if (TYPE(rb_stun_request) != T_STRING)
    rb_raise(rb_eTypeError, "First argument must be a String containing the STUN Binding Request");

  request = RSTRING_PTR(rb_stun_request);

  /* First octet of any STUN *request* must be 0. Return false otherwise. */
  if (request[0]) {
    LOG("first octet is not 0, so it's not a STUN request\n");
    return Qnil;
  }

  /* Any STUN message must contain, at least, 20 bytes. Return false otherwise. */
  if ((request_len = RSTRING_LEN(rb_stun_request)) < STUN_MESSAGE_MIN_SIZE) {
    LOG("ERROR: request length less than 20 bytes, invalid STUN message\n");
    return Qfalse;
  }

  if (TYPE(rb_source_ip) != T_STRING)
    rb_raise(rb_eTypeError, "Third argument must be a String containing the source IP");

  if (TYPE(rb_source_port) != T_FIXNUM)
    rb_raise(rb_eTypeError, "Fourth argument must be a Fixnum containing the source port");

  /*
   * RFC 5389 section 6.
   *
   *   a Binding request has class=0b00 (request) and method=0b000000000001 (Binding)
   *   and is encoded into the first 16 bits as 0x0001.
   *
   * So let's check the second byte which must be 0x1.
   */
  if ( request[1] != 0b00000001 ) {
    LOG("ERROR: not a valid STUN Binding Request, maybe an STUN Indication (so ignore it)\n");
    return Qfalse;
  }

  /*
   * RFC 5389 section 6.
   *
   *   The magic cookie field MUST contain the fixed value 0x2112A442 in network byte order.
   *
   * 0x21 = 33, 0x12 = 18, 0xA4 = -92, 0x42=66.
   */
  if (! (request[4] == 33 && request[5] == 18 && request[6] == -92 && request[7] == 66) ) {
    LOG("WARN: STUN magic cookie does not match, using backward compatibility with RFC 3489\n");

    /*
     * RFC 5389 section 12.2.
     *
     *  A STUN server can detect when a given Binding request message was
     *  sent from an RFC 3489 [RFC3489] client by the absence of the correct
     *  value in the magic cookie field.  When the server detects an RFC 3489
     *  client, it SHOULD copy the value seen in the magic cookie field in
     *  the Binding request to the magic cookie field in the Binding response
     *  message, and insert a MAPPED-ADDRESS attribute instead of an
     *  XOR-MAPPED-ADDRESS attribute.
     *
     */
    is_rfc3489_client = 1;
  }

  /* Get the Magic Cookie. */
  magic_cookie = ((char *)request)+4;

  /* Get the Transaction ID. */
  transaction_id = ((char *)request)+8;

  /*
   * RFC 5389 section 6.
   *   "The message length MUST contain the size, in bytes, of the message
   *    not including the 20-byte STUN header.  Since all STUN attributes are
   *    padded to a multiple of 4 bytes, the last 2 bits of this field are
   *    always zero.  This provides another way to distinguish STUN packets
   *    from packets of other protocols."
   *
   */
  message_length = ntohs(*(uint16_t *)(request+2));



  /*
   * Create the STUN Binding Response.
   */

  /* A Binding response has class=0b10 (success response) and method=*0b000000000001,
   * and is encoded into the first 16 bits as 0x0101. */
  response[0] = 1;
  response[1] = 1;

  /* Add the received Magic Cookie (for RFC 3489 backward compatibility). */
  memcpy(response+4, magic_cookie, STUN_MAGIC_COOKIE_LEN);

  /* Add the received Transaction Id. */
  memcpy(response+8, transaction_id, STUN_TRANSACTION_ID_LEN);

  /*
   * Add an attribute XOR-MAPPED-ADDRESS (or MAPPED-ADDRESS if it's a RFC 3489 client).
   */

  /*
   * STUN Attribute.
   * 
   *  0                   1                   2                   3
   *  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
   *  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   *  |         Type                  |            Length             |
   *  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   *  |                         Value (variable)                ....
   *  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   *
   * 
   * XOR-MAPPED-ADDRESS.
   *
   *  0                   1                   2                   3
   *  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
   *  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   *  |x x x x x x x x|    Family     |         X-Port                |
   *  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   *  |                X-Address (Variable)
   *  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   *
   * 
   * MAPPED-ADDRESS.
   * 
   *  0                   1                   2                   3
   *  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
   *  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   *  |0 0 0 0 0 0 0 0|    Family     |           Port                |
   *  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   *  |                                                               |
   *  |                 Address (32 bits or 128 bits)                 |
   *  |                                                               |
   *  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   * 
   */

  source_ip = StringValueCStr(rb_source_ip);

  /* Check the IP and its type (IPv4 or IPv6). */
  switch(inet_pton(AF_INET, source_ip, &in_addr_ipv4)) {
    /* It's valid IPv4. */
    case 1:
      break;
    /* Not valid INET family, hummmm. */
    case -1:
      LOG("ERROR: Family AF_INET (IPv4) not supported\n");
      return Qfalse;
      break;
    /* Let's check with IPv6. */
    case 0:
      switch(inet_pton(AF_INET6, source_ip, &in_addr_ipv6)) {
        /* It's valid IPv6. */
        case 1:
          source_ip_is_ipv6 = 1;
          break;
          /* Not valid INET family, hummmm. */
        case -1:
          LOG("ERROR: Family AF_INET6 (IPv6) not supported\n");
          return Qfalse;
          break;
        /* The string is neither an IPv4 or IPv6. */
        case 0:
          LOG("ERROR: Unknown Address Family\n");
          return Qfalse;
          break;
      }
  }

  /* Get the port in an integer (two bytes) */
  source_port = (uint16_t)(FIX2INT(rb_source_port));

  /* It's a RFC 5389 compliant client, so add XOR-MAPPED-ADDRESS. */
  if (! is_rfc3489_client) {
    /* STUN attribute type: 0x0020: XOR-MAPPED-ADDRESS */
    response[20] = 0x00;
    response[21] = 0x20;

    /*
     *  XOR-MAPPED-ADDRESS fields.
     */

    /* First byte must be 0x00. */
    response[24] = 0x00;

    /* Second byte is the IP Family (0x01:IPv4, 0x02:IPv6). */
    if (source_ip_is_ipv6)
      response[25] = 0x02;
    else
      response[25] = 0x01;

    /* Bytes 3 and 4 are the X-Port. X-Port is computed by taking the mapped port in
     * host byte order, XOR'ing it with the most significant 16 bits of the magic cookie,
     * and then the converting the result to network byte order. */
    xor_port = htons(source_port ^ *(uint16_t *)(magic_cookie));

    memcpy(response+26, &xor_port, 2);

    /* Next bytes are the IP in network byte order with XOR stuff. */

    /* IPv4. */
    if (! source_ip_is_ipv6) {
      /* If the IP address family is IPv4, X-Address is computed by taking the mapped IP
       * address in host byte order, XOR'ing it with the magic cookie, and converting the
       * result to network byte order. */
      xor_ipv4 = htons((uint32_t)(in_addr_ipv4.s_addr) ^ *(uint32_t *)(magic_cookie));

      memcpy(response+28, &xor_ipv4, 4);
      /* So set the attribute Length to 8. */
      response[22] = 0;
      response[23] = 8;
      /* So set the STUN Response Message Length to 12 bytes. */
      response[2] = 0;
      response[3] = 12;

      /* Return the Ruby string containing the response. */
      return rb_str_new(response, STUN_BINDING_SUCCESS_RESPONSE_IPV4_SIZE);
    }
    /* IPv6. */
    else {
      /* If the IP address family is IPv6, X-Address is computed by taking the
       * mapped IP address in host byte order, XOR'ing it with the concatenation
       * of the magic cookie and the 96-bit transaction ID, and converting the result
       * to network byte order. */
      /* NOTE: struct in_addr.s6_addr is an array of 16 char in network byte order (big-endian). */
      /* TODO: So do I need to convert in_addr_ipv6.s6_addr to host byte order and later the
       * whole result to network byte order? */
      int i;
      for(i=0; i<16; i++)
        xor_ipv6[i] = in_addr_ipv6.s6_addr[i] ^ magic_cookie[i];

      memcpy(response+28, xor_ipv6, 16);

      /* So set the attribute Length to 20. */
      response[22] = 0;
      response[23] = 20;
      /* So set the STUN Response Message Length to 24 bytes. */
      response[2] = 0;
      response[3] = 24;

      /* Return the Ruby string containing the response. */
      return rb_str_new(response, STUN_BINDING_SUCCESS_RESPONSE_IPV6_SIZE);
    } 
  }

  /* It's a RFC 3489 compliant client, so add MAPPED-ADDRESS. */
  else {
    /* STUN attribute type: 0x0001: MAPPED-ADDRESS */
    response[20] = 0x00;
    response[21] = 0x01;

    /*
     *  MAPPED-ADDRESS fields.
     */

    /* First byte must be 0x00. */
    response[24] = 0x00;

    /* Second byte is the IP Family (0x01:IPv4, 0x02:IPv6). */
    if (source_ip_is_ipv6)
      response[25] = 0x02;
    else
      response[25] = 0x01;

    /* Bytes 3 and 4 are the Port in network byte order. */
    source_port = htons(source_port);
    memcpy(response+26, &source_port, 2);

    /* Next bytes are the IP in network byte order. */

    /* IPv4. */
    if (! source_ip_is_ipv6) {
      memcpy(response+28, &in_addr_ipv4.s_addr, 4);
      /* So set the attribute Length to 8. */
      response[22] = 0;
      response[23] = 8;
      /* So set the STUN Response Message Length to 12 bytes. */
      response[2] = 0;
      response[3] = 12;

      /* Return the Ruby string containing the response. */
      return rb_str_new(response, STUN_BINDING_SUCCESS_RESPONSE_IPV4_SIZE);
    }
    /* IPv6. */
    else {
      memcpy(response+28, &in_addr_ipv6.s6_addr, 16);
      /* So set the attribute Length to 20. */
      response[22] = 0;
      response[23] = 20;
      /* So set the STUN Response Message Length to 24 bytes. */
      response[2] = 0;
      response[3] = 24;

      /* Return the Ruby string containing the response. */
      return rb_str_new(response, STUN_BINDING_SUCCESS_RESPONSE_IPV6_SIZE);
    }
  }

}


void Init_stun()
{
  TRACE();

  mOverSIP = rb_define_module("OverSIP");
  mStun = rb_define_module_under(mOverSIP, "Stun");

  rb_define_module_function(mStun, "parse_request", Stun_parse_request, 3);
}
