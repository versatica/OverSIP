#include <ruby.h>
#include "ext_help.h"
#include "sip_parser.h"
#include "common_headers.h"
#include "../utils/utils_ruby.h"
#include "../common/c_util.h"
#include "../common/ruby_c_util.h"


static VALUE my_rb_str_tel_number_clean(const char*, size_t);

static VALUE mOverSIP;
static VALUE eOverSIPError;

static VALUE mSIP;
static VALUE cSIPMessageParser;
static VALUE eSIPMessageParserError;
static VALUE cSIPMessage;
static VALUE cSIPRequest;
static VALUE cSIPResponse;
static VALUE cUri;
static VALUE cNameAddr;

static ID id_headers;
static ID id_parsed;
static ID id_sip_method;
static ID id_is_unknown_method;
static ID id_ruri;
static ID id_status_code;
static ID id_reason_phrase;
static ID id_sip_version;
static ID id_via_sent_by_host;
static ID id_via_sent_by_port;
static ID id_via_branch;
static ID id_via_branch_rfc3261;
static ID id_via_received;
static ID id_via_has_rport;
static ID id_via_has_alias;
static ID id_via_core_value;
static ID id_via_params;
static ID id_num_vias;
static ID id_call_id;
static ID id_cseq;
static ID id_max_forwards;
static ID id_content_length;
static ID id_from;
static ID id_from_tag;
static ID id_to;
static ID id_to_tag;
static ID id_routes;
static ID id_contact;
static ID id_contact_params;
static ID id_require;
static ID id_proxy_require;
static ID id_supported;
static ID id_hdr_via;
static ID id_hdr_from;
static ID id_hdr_to;
static ID id_hdr_route;

static ID id_display_name;
static ID id_uri;
static ID id_uri_scheme;
static ID id_uri_user;
static ID id_uri_host;
static ID id_uri_host_type;
static ID id_uri_port;
static ID id_uri_params;
static ID id_uri_transport_param;
static ID id_uri_lr_param;
static ID id_uri_ob_param;
static ID id_uri_ovid_param;
static ID id_uri_phone_context_param;
static ID id_uri_headers;

static VALUE symbol_outbound_keepalive;
static VALUE symbol_INVITE;
static VALUE symbol_OPTIONS;
static VALUE symbol_INVITE;
static VALUE symbol_ACK;
static VALUE symbol_CANCEL;
static VALUE symbol_PRACK;
static VALUE symbol_BYE;
static VALUE symbol_REFER;
static VALUE symbol_INFO;
static VALUE symbol_UPDATE;
static VALUE symbol_OPTIONS;
static VALUE symbol_REGISTER;
static VALUE symbol_MESSAGE;
static VALUE symbol_SUBSCRIBE;
static VALUE symbol_NOTIFY;
static VALUE symbol_PUBLISH;
static VALUE symbol_PULL;
static VALUE symbol_PUSH;
static VALUE symbol_STORE;
static VALUE symbol_sip;
static VALUE symbol_sips;
static VALUE symbol_tel;
static VALUE symbol_udp;
static VALUE symbol_tcp;
static VALUE symbol_tls;
static VALUE symbol_sctp;
static VALUE symbol_ws;
static VALUE symbol_wss;
static VALUE symbol_domain;
static VALUE symbol_ipv4;
static VALUE symbol_ipv6;
static VALUE symbol_ipv6_reference;

static VALUE string_Via;
static VALUE string_From;
static VALUE string_To;
static VALUE string_CSeq;
static VALUE string_Call_ID;
static VALUE string_Max_Forwards;
static VALUE string_Content_Length;




static void data_type(void *parser, enum data_type data_type)
{
  TRACE();
  VALUE parsed;
  sip_message_parser *sp = (sip_message_parser*)parser;
  
  switch(data_type) {
    case sip_request:
      parsed = rb_obj_alloc(cSIPRequest);
      rb_ivar_set(parsed, id_headers, rb_hash_new());
      sp->parsed = parsed;
      break;
    case sip_response:
      parsed = rb_obj_alloc(cSIPResponse);
      rb_ivar_set(parsed, id_headers, rb_hash_new());
      sp->parsed = parsed;
      break;
    case outbound_keepalive:
      parsed = symbol_outbound_keepalive;
      sp->parsed = parsed;
      break;
  }
  /* NOTE: The parsing can require multiple invocations of the parser#execute() so
   * we need to store the in-process message (Request or Response) in an attribute
   * within the parser (if not it would be garbage collected as it has been declared
   * as a VALUE variable). */
  rb_ivar_set(sp->ruby_sip_parser, id_parsed, parsed);
}


static void init_component(VALUE parsed, enum component msg_component)
{
  switch(msg_component) {
    case component_ruri:      rb_ivar_set(parsed, id_ruri, rb_obj_alloc(cUri));          break;
    case component_from:      rb_ivar_set(parsed, id_from, rb_obj_alloc(cNameAddr));     break;
    case component_to:        rb_ivar_set(parsed, id_to, rb_obj_alloc(cNameAddr));       break;
    case component_route:     rb_ivar_set(parsed, id_routes, rb_ary_new());              break;
    case component_route_uri: rb_ary_push(rb_ivar_get(parsed, id_routes), rb_obj_alloc(cNameAddr)); break;
    case component_contact:   rb_ivar_set(parsed, id_contact, rb_obj_alloc(cNameAddr));  break;
  }
}


static void header(VALUE parsed, const char *hdr_field, size_t hdr_field_len, const char *hdr_value, size_t hdr_value_len, enum header_field hdr_field_name)
{
  TRACE();
  char *ch, *end;
  VALUE v, f, el;
  VALUE headers, array;

  /* Header name. */
  f = headerize(hdr_field, hdr_field_len);
  
  /* Header value. */
  v = RB_STR_UTF8_NEW(hdr_value, hdr_value_len);

  headers = rb_ivar_get(parsed, id_headers);

  /* Here we have the header name capitalized in variable f. */
  el = rb_hash_lookup(headers, f);
  switch(TYPE(el)) {
    case T_ARRAY:
      rb_ary_push(el, v);
      break;
    default:
      array = rb_hash_aset(headers, f, rb_ary_new3(1, v));
      switch(hdr_field_name) {
        case header_field_any:
          break;
        case header_field_via:
          rb_ivar_set(parsed, id_hdr_via, array);
          break;
        case header_field_from:
          rb_ivar_set(parsed, id_hdr_from, v);
          break;
        case header_field_to:
          rb_ivar_set(parsed, id_hdr_to, v);
          break;
        case header_field_route:
          rb_ivar_set(parsed, id_hdr_route, array);
          break;
      }
  }
}


static void msg_method(VALUE parsed, const char *at, size_t length, enum method method)
{
  TRACE();
  VALUE v;
  
  switch(method) {
    /* If the method is known store it as a symbol (i.e. :INVITE). */
    case method_INVITE:
      rb_ivar_set(parsed, id_sip_method, symbol_INVITE);
      break;
    case method_ACK:
      rb_ivar_set(parsed, id_sip_method, symbol_ACK);
      break;
    case method_CANCEL:
      rb_ivar_set(parsed, id_sip_method, symbol_CANCEL);
      break;
    case method_PRACK:
      rb_ivar_set(parsed, id_sip_method, symbol_PRACK);
      break;
    case method_BYE:
      rb_ivar_set(parsed, id_sip_method, symbol_BYE);
      break;
    case method_REFER:
      rb_ivar_set(parsed, id_sip_method, symbol_REFER);
      break;
    case method_INFO:
      rb_ivar_set(parsed, id_sip_method, symbol_INFO);
      break;
    case method_UPDATE:
      rb_ivar_set(parsed, id_sip_method, symbol_UPDATE);
      break;
    case method_OPTIONS:
      rb_ivar_set(parsed, id_sip_method, symbol_OPTIONS);
      break;
    case method_REGISTER:
      rb_ivar_set(parsed, id_sip_method, symbol_REGISTER);
      break;
    case method_MESSAGE:
      rb_ivar_set(parsed, id_sip_method, symbol_MESSAGE);
      break;
    case method_SUBSCRIBE:
      rb_ivar_set(parsed, id_sip_method, symbol_SUBSCRIBE);
      break;
    case method_NOTIFY:
      rb_ivar_set(parsed, id_sip_method, symbol_NOTIFY);
      break;
    case method_PUBLISH:
      rb_ivar_set(parsed, id_sip_method, symbol_PUBLISH);
      break;
    case method_PULL:
      rb_ivar_set(parsed, id_sip_method, symbol_PULL);
      break;
    case method_PUSH:
      rb_ivar_set(parsed, id_sip_method, symbol_PUSH);
      break;
    case method_STORE:
      rb_ivar_set(parsed, id_sip_method, symbol_STORE);
      break;
    /* If the method is unknown store it as a string (i.e. "CHICKEN") and set the
    attribute @is_unknown_method to true. */
    case method_unknown:
      v = RB_STR_UTF8_NEW(at, length);
      rb_ivar_set(parsed, id_sip_method, v);
      rb_ivar_set(parsed, id_is_unknown_method, Qtrue);
      break;
  }
}


static void msg_status_code(VALUE parsed, const char *at, size_t length)
{
  TRACE();
  VALUE v;

  v = INT2FIX(str_to_int(at, length));
  rb_ivar_set(parsed, id_status_code, v);
}


static void msg_reason_phrase(VALUE parsed, const char *at, size_t length)
{
  TRACE();
  VALUE v;

  v = RB_STR_UTF8_NEW(at, length);
  rb_ivar_set(parsed, id_reason_phrase, v);
}


static void msg_sip_version(VALUE parsed, const char *at, size_t length)
{
  TRACE();
  VALUE v;

  v = RB_STR_UTF8_NEW(at, length);
  rb_ivar_set(parsed, id_sip_version, v);
}


static void msg_via_sent_by_host(VALUE parsed, const char *at, size_t length)
{
  TRACE();
  VALUE v;
  
  v = RB_STR_UTF8_NEW(at, length);
  rb_ivar_set(parsed, id_via_sent_by_host, v);
}


static void msg_via_sent_by_port(VALUE parsed, const char *at, size_t length)
{
  TRACE();
  VALUE v;
  
  v = INT2FIX(str_to_int(at, length));
  rb_ivar_set(parsed, id_via_sent_by_port, v);
}


static void msg_via_branch(VALUE parsed, const char *at, size_t length)
{
  TRACE();
  VALUE v;

  v = RB_STR_UTF8_NEW(at, length);
  rb_ivar_set(parsed, id_via_branch, v);
}


static void msg_via_branch_rfc3261(VALUE parsed, const char *at, size_t length)
{
  TRACE();
   
  rb_ivar_set(parsed, id_via_branch_rfc3261, Qtrue);
}


static void msg_via_received(VALUE parsed, const char *at, size_t length)
{
  TRACE();
  VALUE v;

  v = RB_STR_UTF8_NEW(at, length);
  rb_ivar_set(parsed, id_via_received, v);
}


static void msg_via_has_rport(VALUE parsed)
{
  TRACE();

  rb_ivar_set(parsed, id_via_has_rport, Qtrue);
}


static void msg_via_has_alias(VALUE parsed)
{
  TRACE();
  
  rb_ivar_set(parsed, id_via_has_alias, Qtrue);
}


static void msg_call_id(VALUE parsed, const char *at, size_t length)
{
  TRACE();
  VALUE v;

  v = RB_STR_UTF8_NEW(at, length);
  rb_ivar_set(parsed, id_call_id, v);
}


static void msg_cseq_number(VALUE parsed, const char *at, size_t length)
{
  TRACE();
  VALUE v;

  v = LONG2FIX(strtol(at,NULL,0));
  rb_ivar_set(parsed, id_cseq, v);
}


static void msg_max_forwards(VALUE parsed, const char *at, size_t length)
{
  TRACE();
  VALUE v;
  
  v = INT2FIX(str_to_int(at, length));
  rb_ivar_set(parsed, id_max_forwards, v);
}


static void msg_content_length(VALUE parsed, const char *at, size_t length)
{
  TRACE();
  VALUE v;

  v = LONG2FIX(strtol(at,NULL,0));
  rb_ivar_set(parsed, id_content_length, v);
}


static void msg_from_tag(VALUE parsed, const char *at, size_t length)
{
  TRACE();
  VALUE v;

  v = RB_STR_UTF8_NEW(at, length);
  rb_ivar_set(parsed, id_from_tag, v);
}


static void msg_to_tag(VALUE parsed, const char *at, size_t length)
{
  TRACE();
  VALUE v;

  v = RB_STR_UTF8_NEW(at, length);
  rb_ivar_set(parsed, id_to_tag, v);
}


static VALUE get_uri_object(VALUE parsed, enum uri_owner owner)
{
  TRACE();
  VALUE routes_array;

  switch(owner) {
    case uri_owner_ruri:     return rb_ivar_get(parsed, id_ruri);    break;
    case uri_owner_from:     return rb_ivar_get(parsed, id_from);    break;
    case uri_owner_to:       return rb_ivar_get(parsed, id_to);      break;
    /* If we are in Route header, then return the last NameAddr entry. */
    case uri_owner_route:
      routes_array = rb_ivar_get(parsed, id_routes);
      return RARRAY_PTR(routes_array)[RARRAY_LEN(routes_array)-1];
      break;
    case uri_owner_contact:  return rb_ivar_get(parsed, id_contact);  break;
  }
  return Qnil;
}


static void uri_scheme(VALUE parsed, enum uri_owner owner, const char *at, size_t length, enum uri_scheme scheme)
{
  TRACE();
  VALUE v;

  switch(scheme) {
    case uri_scheme_sip:     v = symbol_sip;   break;
    case uri_scheme_sips:    v = symbol_sips;  break;
    case uri_scheme_tel:     v = symbol_tel;   break;
    case uri_scheme_unknown: v = my_rb_str_downcase(at, length); break;
  }

  rb_ivar_set(get_uri_object(parsed, owner), id_uri_scheme, v);
}


static void uri_full(VALUE parsed, enum uri_owner owner, const char *at, size_t length, enum uri_scheme scheme)
{
  TRACE();
  VALUE v;

  v = RB_STR_UTF8_NEW(at, length);
  rb_ivar_set(get_uri_object(parsed, owner), id_uri, v);
}


static void uri_user(VALUE parsed, enum uri_owner owner, const char *at, size_t length, enum uri_scheme scheme)
{
  TRACE();
  VALUE v;

  if (scheme == uri_scheme_tel)
    v = my_rb_str_tel_number_clean(at, length);
  else
    v = my_rb_str_hex_unescape(at, length);

  rb_ivar_set(get_uri_object(parsed, owner), id_uri_user, v);
}


static void uri_host(VALUE parsed, enum uri_owner owner, const char *at, size_t length, int type)
{
  TRACE();
  VALUE v;
  VALUE host_type;

  /* If it's a domain and ends with ".", remove it. */
  if (at[length-1] == '.')
    length--;

  /* Downcase the host part. */
  v = my_rb_str_downcase(at, length);

  switch(type) {
    case host_type_domain:  host_type = symbol_domain;         break;
    case host_type_ipv4:    host_type = symbol_ipv4;           break;
    case host_type_ipv6:    host_type = symbol_ipv6_reference; break;
  }

  /* NOTE: In case of an IPv6 we normalize it so comparissons are easier later. */
  if (host_type == symbol_ipv6_reference)
    rb_ivar_set(get_uri_object(parsed, owner), id_uri_host, utils_normalize_ipv6(v, 0));
  else
    rb_ivar_set(get_uri_object(parsed, owner), id_uri_host, v);

  rb_ivar_set(get_uri_object(parsed, owner), id_uri_host_type, host_type);
}


static void uri_port(VALUE parsed, enum uri_owner owner, const char *at, size_t length, enum uri_scheme scheme)
{
  TRACE();
  VALUE v;

  v = INT2FIX(str_to_int(at, length));
  rb_ivar_set(get_uri_object(parsed, owner), id_uri_port, v);
}


static void uri_param(VALUE parsed, enum uri_owner owner, const char *key, size_t key_len, const char *value, size_t value_len)
{
  TRACE();
  VALUE uri, params, v;

  if ((uri = get_uri_object(parsed, owner)) == Qnil)
    return;

  if ((params = rb_ivar_get(uri, id_uri_params)) == Qnil) {
    params = rb_hash_new();
    rb_ivar_set(uri, id_uri_params, params);
  }
  if (value_len > 0)
    v = RB_STR_UTF8_NEW(value, value_len);
  else
    v = Qnil;
  rb_hash_aset(params, my_rb_str_downcase(key, key_len), v);
}


static void uri_known_param(VALUE parsed, enum uri_owner owner, enum uri_param_name param_name, const char *at, size_t length, int param_value)
{
  TRACE();
  VALUE p, v;

  switch(param_name) {
    case uri_param_transport:
      p = id_uri_transport_param;
      switch(param_value) {
        case transport_udp:  v = symbol_udp;   break;
        case transport_tcp:  v = symbol_tcp;   break;
        case transport_tls:  v = symbol_tls;   break;
        case transport_sctp: v = symbol_sctp;  break;
        case transport_ws:   v = symbol_ws;    break;
        case transport_wss:  v = symbol_wss;   break;
        case transport_unknown:  v = my_rb_str_downcase(at, length);  break;
      }
      break;
    case uri_param_ovid:
      p = id_uri_ovid_param;
      v = rb_str_new(at, length);
      break;
    case uri_tel_phone_context:
      if (length == 0)
        return;
      /* If it's a domain and ends with ".", remove it. */
      if (at[length-1] == '.')
        length--;
      p = id_uri_phone_context_param;
      v = my_rb_str_downcase(at, length);
      break;
  }
  
  rb_ivar_set(get_uri_object(parsed, owner), p, v);
}


static void uri_has_param(VALUE parsed, enum uri_owner owner, enum uri_param_name param_name)
{
  TRACE();

  VALUE p;
  
  switch(param_name) {
    case uri_param_lr:  p = id_uri_lr_param;  break;
    case uri_param_ob:  p = id_uri_ob_param;  break;
  }
  
  rb_ivar_set(get_uri_object(parsed, owner), p, Qtrue);
}


static void uri_headers(VALUE parsed, enum uri_owner owner, const char *at, size_t length, enum uri_scheme scheme)
{
  TRACE();
  VALUE v;

  v = RB_STR_UTF8_NEW(at, length);
  rb_ivar_set(get_uri_object(parsed, owner), id_uri_headers, v);
}


static void uri_display_name(VALUE parsed, enum uri_owner owner, const char *at, size_t length, enum uri_scheme scheme)
{
  TRACE();
  VALUE v;

  if (length == 0)
    return;
  
  v = RB_STR_UTF8_NEW(at, length);
  rb_ivar_set(get_uri_object(parsed, owner), id_display_name, v);
}


static void header_core_value(VALUE parsed, enum header_field header_field, const char *at, size_t length)
{
  TRACE();
  VALUE v;

  if (length == 0)
    return;

  v = RB_STR_UTF8_NEW(at, length);

  switch(header_field) {
    case header_field_via:   rb_ivar_set(parsed, id_via_core_value, v);  break;
  }
}


static void header_param(VALUE parsed, enum header_field header_field, const char *key, size_t key_len, const char *value, size_t value_len)
{
  TRACE();
  VALUE v;
  VALUE header_params;
  
  switch(header_field) {
    case header_field_via:
      if ((header_params = rb_ivar_get(parsed, id_via_params)) == Qnil) {
        header_params = rb_hash_new();
        rb_ivar_set(parsed, id_via_params, header_params);
      }
      if (value_len > 0)
        v = RB_STR_UTF8_NEW(value, value_len);
      else
        v = Qnil;
      rb_hash_aset(header_params, my_rb_str_downcase(key, key_len), v);
      break;
    /* case header_field_contact:
      if ((header_params = rb_ivar_get(parsed, id_contact_params)) == Qnil) {
        header_params = rb_hash_new();
        rb_ivar_set(parsed, id_contact_params, header_params);
      }
      if (value_len > 0)
        v = RB_STR_UTF8_NEW(value, value_len);
      else
        v = Qnil;
      rb_hash_aset(header_params, my_rb_str_downcase(key, key_len), v);
      break; */
  }
}


static void msg_contact_params(VALUE parsed, const char *at, size_t length)
{
  TRACE();
  VALUE v;

  if (length == 0)
    return;

  v = RB_STR_UTF8_NEW(at, length);
  rb_ivar_set(parsed, id_contact_params, v);
}


static void option_tag(VALUE parsed, enum header_field header_field, const char *at, size_t length)
{
  TRACE();
  VALUE v;
  VALUE id_option_tag_owner;
  VALUE option_tag_owner;
  
  switch(header_field) {
    case header_field_require:        id_option_tag_owner = id_require;        break;
    case header_field_proxy_require:  id_option_tag_owner = id_proxy_require;  break;
    case header_field_supported:      id_option_tag_owner = id_supported;      break;
  }

  if ((option_tag_owner = rb_ivar_get(parsed, id_option_tag_owner)) == Qnil) {
    option_tag_owner = rb_ary_new();
    rb_ivar_set(parsed, id_option_tag_owner, option_tag_owner);
  }
  rb_ary_push(option_tag_owner,my_rb_str_downcase(at, length));
}


/*************** Custom C funcions (helpers) ****************/


/*
 * my_rb_str_tel_number_clean: Remove separators from a TEL URI number and downcase letters.
 */
static VALUE my_rb_str_tel_number_clean(const char *str, size_t len)
{
  TRACE();
  char *new_str;
  VALUE str_clean;

  new_str = ALLOC_N(char, len);

  char *s;
  int i, j;
  int new_len;

  for (s = (char *)str, i = 0, j = 0, new_len = len; i < len ; s++, i++)
    /* The char is not a separator so keep it. */
    if (*s != '-' && *s != '.' && *s != '(' && *s != ')')
      /* Downcase if it's A-F. */
      if (*s >= 'A' && *s <= 'F')
        new_str[j++] = *s + 32;
      else
        new_str[j++] = *s;
    else
      new_len--;

  str_clean = RB_STR_UTF8_NEW(new_str, new_len);
  xfree(new_str);
  return(str_clean);
}



/*************** Ruby functions ****************/

static void SipMessageParser_free(void *parser)
{
  TRACE();
  if(parser) {
    /* NOTE: Use always xfree() rather than free():
     *   http://www.mail-archive.com/libxml-devel@rubyforge.org/msg00242.html */
    xfree(parser);
  }
}


VALUE SipMessageParser_alloc(VALUE klass)
{
  TRACE();
  VALUE obj;
  /* NOTE: Use always ALLOC/ALLOC_N rather than malloc().
   * ALLOC uses xmalloc:
   *   ALLOC(type)   (type*)xmalloc(sizeof(type))
   *   ALLOC_N(type, n)   (type*)xmalloc(sizeof(type)*(n))
  */
  sip_message_parser *parser = ALLOC(sip_message_parser);

  /* Asign functions to the pointers of sip_message_parser struct. */
  parser->data_type                   = data_type;
  parser->header                      = header;

  parser->message.method              = msg_method;
  parser->message.status_code         = msg_status_code;
  parser->message.reason_phrase       = msg_reason_phrase;
  parser->message.sip_version         = msg_sip_version;
  parser->message.via_sent_by_host    = msg_via_sent_by_host;
  parser->message.via_sent_by_port    = msg_via_sent_by_port;
  parser->message.via_branch          = msg_via_branch;
  parser->message.via_branch_rfc3261  = msg_via_branch_rfc3261;
  parser->message.via_received        = msg_via_received;
  parser->message.via_has_rport       = msg_via_has_rport;
  parser->message.via_has_alias       = msg_via_has_alias;
  parser->message.call_id             = msg_call_id;
  parser->message.cseq_number         = msg_cseq_number;
  parser->message.max_forwards        = msg_max_forwards;
  parser->message.content_length      = msg_content_length;
  parser->message.from_tag            = msg_from_tag;
  parser->message.to_tag              = msg_to_tag;
  parser->message.contact_params      = msg_contact_params;
  parser->message.header_core_value   = header_core_value;
  parser->message.header_param        = header_param;
  parser->message.option_tag          = option_tag;
  parser->message.init_component      = init_component;
  
  parser->uri.full                    = uri_full;
  parser->uri.scheme                  = uri_scheme;
  parser->uri.user                    = uri_user;
  parser->uri.host                    = uri_host;
  parser->uri.port                    = uri_port;
  parser->uri.param                   = uri_param;
  parser->uri.known_param             = uri_known_param;
  parser->uri.has_param               = uri_has_param;
  parser->uri.headers                 = uri_headers;
  parser->uri.display_name            = uri_display_name;
  
  sip_message_parser_init(parser);

  obj = Data_Wrap_Struct(klass, NULL, SipMessageParser_free, parser);
  return obj;
}


/**
 * call-seq:
 *    parser.new -> parser
 *
 * Creates a new parser.
 */
VALUE SipMessageParser_init(VALUE self)
{
  TRACE();
  sip_message_parser *parser = NULL;
  DATA_GET(self, sip_message_parser, parser);
  sip_message_parser_init(parser);

  /* NOTE: This allows the C struct to access to the VALUE element of the Ruby
  MessageParser instance. */
  parser->ruby_sip_parser = self;

  return self;
}


/**
 * call-seq:
 *    parser.reset -> nil
 *
 * Resets the parser to it's initial state so that you can reuse it
 * rather than making new ones.
 */
VALUE SipMessageParser_reset(VALUE self)
{
  TRACE();
  sip_message_parser *parser = NULL;
  DATA_GET(self, sip_message_parser, parser);
  sip_message_parser_init(parser);

  return Qnil;
}


/**
 * call-seq:
 *    parser.finish -> true/false
 *
 * Finishes a parser early which could put in a "good" or bad state.
 * You should call reset after finish it or bad things will happen.
 */
VALUE SipMessageParser_finish(VALUE self)
{
  TRACE();
  sip_message_parser *parser = NULL;
  DATA_GET(self, sip_message_parser, parser);
  sip_message_parser_finish(parser);

  return sip_message_parser_is_finished(parser) ? Qtrue : Qfalse;
}


/**
 * call-seq:
 *    parser.execute(buffer, start) -> Integer
 */
VALUE SipMessageParser_execute(VALUE self, VALUE buffer, VALUE start)
{
  TRACE();
  sip_message_parser *parser = NULL;
  int from = 0;
  char *dptr = NULL;
  long dlen = 0;
  
  REQUIRE_TYPE(buffer, T_STRING);
  REQUIRE_TYPE(start, T_FIXNUM);

  DATA_GET(self, sip_message_parser, parser);

  from = FIX2INT(start);
  dptr = RSTRING_PTR(buffer);
  dlen = RSTRING_LEN(buffer);

  /* This should never occur or there is an error in the parser. */
  if(from >= dlen)
    rb_raise(eSIPMessageParserError, "requested start is after buffer end.");

  sip_message_parser_execute(parser, dptr, dlen, from);

  if(sip_message_parser_has_error(parser))
    return Qfalse;
  else
    return INT2FIX(sip_message_parser_nread(parser));
}


/**
 * call-seq:
 *    parser.error? -> true/false
 *
 * Tells you whether the parser is in an error state.
 */
VALUE SipMessageParser_has_error(VALUE self)
{
  TRACE();
  sip_message_parser *parser = NULL;
  DATA_GET(self, sip_message_parser, parser);

  return sip_message_parser_has_error(parser) ? Qtrue : Qfalse;
}


/**
 * call-seq:
 *    parser.error -> String
 *
 * Returns a String showing the error by enclosing the exact wrong char between {{{ }}}.
 */
VALUE SipMessageParser_error(VALUE self)
{
  TRACE();
  sip_message_parser *parser = NULL;
  DATA_GET(self, sip_message_parser, parser);

  if(sip_message_parser_has_error(parser)) {
    char *parsing_error_str;
    int parsing_error_str_len;
    int i;
    int j;
    VALUE rb_error_str;

    /* Duplicate error string length so '\r' and '\n' are displayed as CR and LF.
    Let 6 chars more for allocating {{{ and }}}. */
    parsing_error_str = ALLOC_N(char, 2*parser->error_len + 6);

    parsing_error_str_len=0;
    for(i=0, j=0; i < parser->error_len; i++) {
      if (i != parser->error_pos) {
        if (parser->error_start[i] == '\r') {
          parsing_error_str[j++] = '\\';
          parsing_error_str[j++] = 'r';
          parsing_error_str_len += 2;
        }
        else if (parser->error_start[i] == '\n') {
          parsing_error_str[j++] = '\\';
          parsing_error_str[j++] = 'n';
          parsing_error_str_len += 2;
        }
        else {
          parsing_error_str[j++] = parser->error_start[i];
          parsing_error_str_len++;
        }
      }
      else {
        parsing_error_str[j++] = '{';
        parsing_error_str[j++] = '{';
        parsing_error_str[j++] = '{';
        if (parser->error_start[i] == '\r') {
          parsing_error_str[j++] = '\\';
          parsing_error_str[j++] = 'r';
          parsing_error_str_len += 2;
        }
        else if (parser->error_start[i] == '\n') {
          parsing_error_str[j++] = '\\';
          parsing_error_str[j++] = 'n';
          parsing_error_str_len += 2;
        }
        else {
          parsing_error_str[j++] = parser->error_start[i];
          parsing_error_str_len++;
        }
        parsing_error_str[j++] = '}';
        parsing_error_str[j++] = '}';
        parsing_error_str[j++] = '}';
        parsing_error_str_len += 6;
      }
    }

    rb_error_str = rb_str_new(parsing_error_str, parsing_error_str_len);
    xfree(parsing_error_str);
    return rb_error_str;
  }
  else
    return Qnil;
}


/**
 * call-seq:
 *    parser.finished? -> true/false
 *
 * Tells you whether the parser is finished or not and in a good state.
 */
VALUE SipMessageParser_is_finished(VALUE self)
{
  TRACE();
  sip_message_parser *parser = NULL;
  DATA_GET(self, sip_message_parser, parser);

  return sip_message_parser_is_finished(parser) ? Qtrue : Qfalse;
}


/**
 * call-seq:
 *    parser.parsed -> OverSIP::Request or OverSIP::Response or :outbound_keepalive or nil
 *
 * Returns the parsed object. It doesn't meant that the parsing has succedded. The returned
 * object could be a message identified as a Request or Response or :outbound_keepalive, but later
 * the message has been detected as invalid. So the parsed object is incomplete.
 *
 * In case the parsing has failed in the first char the method returns nil.
 */
VALUE SipMessageParser_parsed(VALUE self)
{
  TRACE();
  sip_message_parser *parser = NULL;
  DATA_GET(self, sip_message_parser, parser);

  /* NOTE: We can safely access here to parser->parsed as its content is also referenced
   * by id_parsed so it cannot be garbage collected while the OverSIP::MessageParser
   * still alives. */
  return parser->parsed;
}


/**
 * call-seq:
 *    parser.nread -> Integer
 *
 * Returns the amount of data processed so far during this processing cycle.  It is
 * set to 0 on initialize or reset calls and is incremented each time execute is called.
 */
VALUE SipMessageParser_nread(VALUE self)
{
  TRACE();
  sip_message_parser *parser = NULL;
  DATA_GET(self, sip_message_parser, parser);

  return INT2FIX(parser->nread);
}


/**
 * call-seq:
 *    parser.duplicated_core_header? -> true/false
 *
 * In case a core header is duplicated its name is returned as string.
 * False otherwise.
 */
VALUE SipMessageParser_has_duplicated_core_header(VALUE self)
{
  TRACE();
  sip_message_parser *parser = NULL;
  DATA_GET(self, sip_message_parser, parser);

  /* NOTE: Good moment for counting the num of Via values and store it. */
  rb_ivar_set(parser->parsed, id_num_vias, INT2FIX(parser->num_via));
  
  if (parser->num_from > 1)
    return string_From;
  else if (parser->num_to > 1)
    return string_To;
  else if (parser->num_cseq > 1)
    return string_CSeq;
  else if (parser->num_call_id > 1)
    return string_Call_ID;
  else if (parser->num_max_forwards > 1)
    return string_Max_Forwards;
  else if (parser->num_content_length > 1)
    return string_Content_Length;

  return Qfalse;
}


/**
 * call-seq:
 *    parser.missing_core_header? -> true/false
 *
 * In case a core header is missing its name is returned as string.
 * False otherwise.
 */
VALUE SipMessageParser_has_missing_core_header(VALUE self)
{
  TRACE();
  sip_message_parser *parser = NULL;
  DATA_GET(self, sip_message_parser, parser);

  if (parser->num_via == 0)
    return string_Via;
  else if (parser->num_from == 0)
    return string_From;
  else if (parser->num_to == 0)
    return string_To;
  else if (parser->num_cseq == 0)
    return string_CSeq;
  else if (parser->num_call_id == 0)
    return string_Call_ID;
  
  return Qfalse;
}


VALUE SipMessageParser_post_parsing(VALUE self)
{
  TRACE();
  sip_message_parser *parser = NULL;
  DATA_GET(self, sip_message_parser, parser);

  /* We just parse Contact if it's a single header with a single Name Addr within it. */
  if (! (parser->contact_is_valid == 1 && parser->num_contact == 1)) {
    /*printf("--- if (! (parser->contact_is_valid == 1 && parser->num_contact == 1))  returns false\n");
    printf("--- parser->num_contact = %d\n", parser->num_contact);*/
    rb_ivar_set(parser->parsed, id_contact, Qnil);
  }

  return Qnil;
}


/**
 * call-seq:
 *    OverSIP::SIP::MessageParser.headarize -> String
 *
 * Tries to lookup the header name in a list of well-known headers. If so,
 * returns the retrieved VALUE. It also works for short headers.
 * In case the header is unknown, it normalizes it (by capitalizing the
 * first letter and each letter under a "-" or "_" symbol).
 */
VALUE SipMessageParser_Class_headerize(VALUE self, VALUE string)
{
  TRACE();
  if (TYPE(string) != T_STRING)
    rb_raise(rb_eTypeError, "Argument must be a String");
  
  if ((RSTRING_LEN(string)) == 0)
    rb_str_new(RSTRING_PTR(string), RSTRING_LEN(string));

  return(headerize(RSTRING_PTR(string), RSTRING_LEN(string)));
}




void Init_sip_parser()
{
  TRACE();
  
  mOverSIP = rb_define_module("OverSIP");
  eOverSIPError = rb_define_class_under(mOverSIP, "Error", rb_eStandardError);
  
  mSIP = rb_define_module_under(mOverSIP, "SIP");
  cSIPMessageParser = rb_define_class_under(mSIP, "MessageParser", rb_cObject);
  cSIPMessage = rb_define_class_under(mSIP, "Message", rb_cObject);
  cSIPRequest = rb_define_class_under(mSIP, "Request", cSIPMessage);
  cSIPResponse = rb_define_class_under(mSIP, "Response", cSIPMessage);
  cUri = rb_define_class_under(mSIP, "Uri", rb_cObject);
  cNameAddr = rb_define_class_under(mSIP, "NameAddr", cUri);
  eSIPMessageParserError = rb_define_class_under(mSIP, "MessageParserError", eOverSIPError);

  rb_define_alloc_func(cSIPMessageParser, SipMessageParser_alloc);
  rb_define_method(cSIPMessageParser, "initialize", SipMessageParser_init,0);
  rb_define_method(cSIPMessageParser, "reset", SipMessageParser_reset,0);
  rb_define_method(cSIPMessageParser, "finish", SipMessageParser_finish,0);
  rb_define_method(cSIPMessageParser, "execute", SipMessageParser_execute,2);
  rb_define_method(cSIPMessageParser, "error?", SipMessageParser_has_error,0);
  rb_define_method(cSIPMessageParser, "error", SipMessageParser_error,0);
  rb_define_method(cSIPMessageParser, "finished?", SipMessageParser_is_finished,0);
  rb_define_method(cSIPMessageParser, "parsed", SipMessageParser_parsed,0);
  rb_define_method(cSIPMessageParser, "nread", SipMessageParser_nread,0);
  rb_define_method(cSIPMessageParser, "duplicated_core_header?", SipMessageParser_has_duplicated_core_header,0);
  rb_define_method(cSIPMessageParser, "missing_core_header?", SipMessageParser_has_missing_core_header,0);
  rb_define_method(cSIPMessageParser, "post_parsing", SipMessageParser_post_parsing,0);
  
  rb_define_module_function(cSIPMessageParser, "headerize", SipMessageParser_Class_headerize,1);
  
  init_common_headers();
  init_short_headers();

  id_headers = rb_intern("@headers");
  id_parsed = rb_intern("@parsed");
  id_sip_method = rb_intern("@sip_method");
  id_is_unknown_method = rb_intern("@is_unknown_method");
  id_ruri = rb_intern("@ruri");
  id_status_code = rb_intern("@status_code");
  id_reason_phrase = rb_intern("@reason_phrase");
  id_sip_version = rb_intern("@sip_version");
  id_via_sent_by_host = rb_intern("@via_sent_by_host");
  id_via_sent_by_port = rb_intern("@via_sent_by_port");
  id_via_branch = rb_intern("@via_branch");
  id_via_branch_rfc3261 = rb_intern("@via_branch_rfc3261");
  id_via_received = rb_intern("@via_received");
  id_via_has_rport = rb_intern("@via_has_rport");
  id_via_has_alias = rb_intern("@via_has_alias");
  id_via_core_value = rb_intern("@via_core_value");
  id_via_params = rb_intern("@via_params");
  id_num_vias = rb_intern("@num_vias");
  id_call_id = rb_intern("@call_id");
  id_cseq = rb_intern("@cseq");
  id_max_forwards = rb_intern("@max_forwards");
  id_content_length = rb_intern("@content_length");
  id_from = rb_intern("@from");
  id_from_tag = rb_intern("@from_tag");
  id_to = rb_intern("@to");
  id_to_tag = rb_intern("@to_tag");
  id_routes = rb_intern("@routes");
  id_contact = rb_intern("@contact");
  id_contact_params = rb_intern("@contact_params");
  id_require = rb_intern("@require");
  id_proxy_require = rb_intern("@proxy_require");
  id_supported = rb_intern("@supported");
  id_hdr_via = rb_intern("@hdr_via");
  id_hdr_from = rb_intern("@hdr_from");
  id_hdr_to = rb_intern("@hdr_to");
  id_hdr_route = rb_intern("@hdr_route");
  
  id_display_name = rb_intern("@display_name");
  id_uri = rb_intern("@uri");
  id_uri_scheme = rb_intern("@scheme");
  id_uri_user = rb_intern("@user");
  id_uri_host = rb_intern("@host");
  id_uri_host_type = rb_intern("@host_type");
  id_uri_port = rb_intern("@port");
  id_uri_params = rb_intern("@params");
  id_uri_transport_param = rb_intern("@transport_param");
  id_uri_lr_param = rb_intern("@lr_param");
  id_uri_ob_param = rb_intern("@ob_param");
  id_uri_ovid_param = rb_intern("@ovid_param");
  id_uri_phone_context_param = rb_intern("@phone_context_param");
  id_uri_headers = rb_intern("@headers");

  symbol_outbound_keepalive = ID2SYM(rb_intern("outbound_keepalive"));
  symbol_INVITE = ID2SYM(rb_intern("INVITE"));
  symbol_ACK = ID2SYM(rb_intern("ACK"));
  symbol_CANCEL = ID2SYM(rb_intern("CANCEL"));
  symbol_PRACK = ID2SYM(rb_intern("PRACK"));
  symbol_BYE = ID2SYM(rb_intern("BYE"));
  symbol_REFER = ID2SYM(rb_intern("REFER"));
  symbol_INFO = ID2SYM(rb_intern("INFO"));
  symbol_UPDATE = ID2SYM(rb_intern("UPDATE"));
  symbol_OPTIONS = ID2SYM(rb_intern("OPTIONS"));
  symbol_REGISTER = ID2SYM(rb_intern("REGISTER"));
  symbol_MESSAGE = ID2SYM(rb_intern("MESSAGE"));
  symbol_SUBSCRIBE = ID2SYM(rb_intern("SUBSCRIBE"));
  symbol_NOTIFY = ID2SYM(rb_intern("NOTIFY"));
  symbol_PUBLISH = ID2SYM(rb_intern("PUBLISH"));
  symbol_PULL = ID2SYM(rb_intern("PULL"));
  symbol_PUSH = ID2SYM(rb_intern("PUSH"));
  symbol_STORE = ID2SYM(rb_intern("STORE"));
  symbol_sip = ID2SYM(rb_intern("sip"));
  symbol_sips = ID2SYM(rb_intern("sips"));
  symbol_tel = ID2SYM(rb_intern("tel"));
  symbol_udp = ID2SYM(rb_intern("udp"));
  symbol_tcp = ID2SYM(rb_intern("tcp"));
  symbol_tls = ID2SYM(rb_intern("tls"));
  symbol_sctp = ID2SYM(rb_intern("sctp"));
  symbol_ws = ID2SYM(rb_intern("ws"));
  symbol_wss = ID2SYM(rb_intern("wss"));
  symbol_domain = ID2SYM(rb_intern("domain"));
  symbol_ipv4 = ID2SYM(rb_intern("ipv4"));
  symbol_ipv6 = ID2SYM(rb_intern("ipv6"));
  symbol_ipv6_reference = ID2SYM(rb_intern("ipv6_reference"));
  
  string_Via = rb_str_new2("Via");
  string_Via = rb_obj_freeze(string_Via);
  rb_global_variable(&string_Via);
  string_From = rb_str_new2("From");
  string_From = rb_obj_freeze(string_From);
  rb_global_variable(&string_From);
  string_To = rb_str_new2("To");
  string_To = rb_obj_freeze(string_To);
  rb_global_variable(&string_To);
  string_CSeq = rb_str_new2("CSeq");
  string_CSeq = rb_obj_freeze(string_CSeq);
  rb_global_variable(&string_CSeq);
  string_Call_ID = rb_str_new2("Call-ID");
  string_Call_ID = rb_obj_freeze(string_Call_ID);
  rb_global_variable(&string_Call_ID);
  string_Max_Forwards = rb_str_new2("Max-Forwards");
  string_Max_Forwards = rb_obj_freeze(string_Max_Forwards);
  rb_global_variable(&string_Max_Forwards);
  string_Content_Length = rb_str_new2("Content-Length");
  string_Content_Length = rb_obj_freeze(string_Content_Length);
  rb_global_variable(&string_Content_Length);
}
