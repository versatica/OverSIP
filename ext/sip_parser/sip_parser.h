#ifndef sip_parser_h
#define sip_parser_h


#include <ruby.h>
#include <sys/types.h>


enum data_type {
  sip_request = 1,
  sip_response,
  outbound_keepalive
};

enum method {
  method_INVITE = 1,
  method_ACK,
  method_CANCEL,
  method_PRACK,
  method_BYE,
  method_REFER,
  method_INFO,
  method_UPDATE,
  method_OPTIONS,
  method_REGISTER,
  method_MESSAGE,
  method_SUBSCRIBE,
  method_NOTIFY,
  method_PUBLISH,
  method_PULL,
  method_PUSH,
  method_STORE,
  method_unknown
};

enum component {
  component_ruri = 1,
  component_from,
  component_to,
  component_route,
  component_route_uri,
  component_contact
};

enum uri_owner {
  uri_owner_ruri = 1,
  uri_owner_from,
  uri_owner_to,
  uri_owner_route,
  uri_owner_contact
};

enum uri_scheme {
  uri_scheme_sip = 1,
  uri_scheme_sips,
  uri_scheme_tel,
  uri_scheme_unknown
};

enum uri_param_name {
  uri_param_transport = 1,
  uri_param_lr,
  uri_param_ob,
  uri_param_ovid,
  uri_tel_phone_context
};

enum host_type {
  host_type_domain = 1,
  host_type_ipv4,
  host_type_ipv6
};

enum header_field {
  header_field_any = 0,
  header_field_via,
  header_field_from,
  header_field_to,
  header_field_route,
  header_field_supported,
  header_field_require,
  header_field_proxy_require,
  header_field_contact
};

enum transport {
  transport_udp = 1,
  transport_tcp,
  transport_tls,
  transport_sctp,
  transport_ws,
  transport_wss,
  transport_unknown
};

typedef void (*data_type_cb)(void *parser, enum data_type value);
typedef void (*msg_method_cb)(VALUE parsed, const char *at, size_t length, enum method method);
typedef void (*msg_element_cb)(VALUE parsed, const char *at, size_t length);
typedef void (*msg_has_param_cb)(VALUE parsed);
typedef void (*header_core_value_cb)(VALUE parsed, enum header_field header_field, const char *at, size_t length);
typedef void (*header_param_cb)(VALUE parsed, enum header_field header_field, const char *key, size_t key_len, const char *value, size_t value_len);
typedef void (*header_cb)(VALUE parsed, const char *hdr_field, size_t hdr_field_len, const char *hdr_value, size_t hdr_value_len, enum header_field hdr_field_name);
typedef void (*uri_element_cb)(VALUE parsed, enum uri_owner owner, const char *at, size_t length, enum uri_scheme);
typedef void (*uri_element2_cb)(VALUE parsed, enum uri_owner owner, const char *at, size_t length, int type);
typedef void (*uri_param_cb)(VALUE parsed, enum uri_owner owner, const char *key, size_t key_len, const char *value, size_t value_len);
typedef void (*uri_known_param_cb)(VALUE parsed, enum uri_owner owner, enum uri_param_name, const char *at, size_t length, int uri_param_value);
typedef void (*uri_has_param_cb)(VALUE parsed, enum uri_owner, enum uri_param_name);
typedef void (*option_tag_cb)(VALUE parsed, enum header_field, const char *at, size_t length);
typedef void (*init_component_cb)(VALUE parsed, enum component);


typedef struct struct_message {
  msg_method_cb               method;
  msg_element_cb              sip_version;
  msg_element_cb              status_code;
  msg_element_cb              reason_phrase;
  msg_element_cb              via_sent_by_host;
  msg_element_cb              via_sent_by_port;
  msg_element_cb              via_branch;
  msg_element_cb              via_branch_rfc3261;
  msg_element_cb              via_received;
  msg_has_param_cb            via_has_rport;
  msg_has_param_cb            via_has_alias;
  msg_element_cb              call_id;
  msg_element_cb              cseq_number;
  msg_element_cb              max_forwards;
  msg_element_cb              content_length;
  msg_element_cb              from_tag;
  msg_element_cb              to_tag;
  msg_element_cb              contact_params;
  msg_has_param_cb            contact_has_reg_id;
  /* Header value without header params. */
  header_core_value_cb        header_core_value;
  header_param_cb             header_param;
  option_tag_cb               option_tag;
  init_component_cb           init_component;
} struct_message;

typedef struct struct_uri {
  uri_element_cb              full;
  uri_element_cb              scheme;
  uri_element_cb              user;
  uri_element2_cb             host;
  uri_element_cb              port;
  uri_param_cb                param;
  uri_known_param_cb          known_param;
  uri_has_param_cb            has_param;
  uri_element_cb              headers;
  uri_element_cb              display_name;
} struct_uri;

typedef struct sip_message_parser {
  /* Parser stuf. */
  int                 cs;
  size_t              nread;
  char *              error_start;
  size_t              error_len;
  int                 error_pos;
  
  size_t              mark;
  size_t              hdr_field_start;
  size_t              hdr_field_len;
  size_t              hdr_value_start;
  size_t              hdr_value_len;
  enum header_field   hdr_field_name;
  size_t              uri_start;
  /* URI parameters. */
  size_t              uri_param_key_start;
  size_t              uri_param_key_len;
  size_t              uri_param_value_start;
  size_t              uri_param_value_len;
  /* Header parameters. */
  size_t              header_param_key_start;
  size_t              header_param_key_len;
  size_t              header_param_value_start;
  size_t              header_param_value_len;

  /* Method which set parser->parsed as OverSIP::SIP::Request, OverSIP::SIP::Response or
   * :outbound_keepalive. */
  data_type_cb        data_type;
  /* Message method. */
  enum method         method;
  /* Method already set. */
  size_t              method_set;
  /* Just take top most Via data. */
  size_t              num_via;
  /* Don't allow duplicate headers (From, To, Call-ID, CSeq, Max-Forwards and Content-Length). */
  size_t              num_from;
  size_t              num_to;
  size_t              num_call_id;
  size_t              num_cseq;
  size_t              num_max_forwards;
  size_t              num_content_length;
  size_t              num_contact;
  int                 contact_is_valid;
  /* If a previous Route was found then don't re-initialize the ruby @route array. */
  size_t              route_found;
  /* Set it before parsing a desired URI. */
  size_t              do_uri;
  /* The header (or request line) the URI belongs to. */
  enum uri_owner      uri_owner;
  /* URI scheme type. */
  enum uri_scheme     uri_scheme;
  /* URI display name is quoted. */
  size_t              uri_display_name_quoted;
  
  header_cb           header;
  struct_message      message;
  struct_uri          uri;

  /* Can be set to OverSIP::SIP::Request, OverSIP::SIP::Response or :outbound_keepalive or nil. */
  VALUE               parsed;

  /* A pointer to the Ruby OverSIP::SIP::MessageParser instance (required by data_type() in
   * sip_parser_ruby.c). */
  VALUE               ruby_sip_parser;
} sip_message_parser;


int sip_message_parser_init(sip_message_parser *parser);
int sip_message_parser_finish(sip_message_parser *parser);
size_t sip_message_parser_execute(sip_message_parser *parser, const char *buffer, size_t len, size_t off);
int sip_message_parser_has_error(sip_message_parser *parser);
int sip_message_parser_is_finished(sip_message_parser *parser);
#define sip_message_parser_nread(parser) (parser)->nread


#endif
