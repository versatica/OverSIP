#include "sip_parser.h"
#include "ext_help.h"
#include <stdio.h>
#include <assert.h>
#include <stdlib.h>
#include <ctype.h>
#include <string.h>

#define MARK(M, FPC) (parser->M = (FPC) - buffer)
#define LEN(AT, FPC) (FPC - buffer - parser->AT)
#define PTR_TO(F) (buffer + parser->F)



/** machine **/
%%{
  machine sip_message_parser;


  action msg_request {
    parser->data_type(parser, sip_request);
  }

  action msg_response {
    parser->data_type(parser, sip_response);
  }

  action outbound_keepalive {
    parser->data_type(parser, outbound_keepalive);
  }


  action mark { MARK(mark, fpc); }

  action start_hdr_field {
    MARK(hdr_field_start, fpc);
  }

  action write_hdr_field {
    parser->hdr_field_len = LEN(hdr_field_start, fpc);
    parser->hdr_field_name = header_field_any;
  }

  action start_hdr_value { MARK(hdr_value_start, fpc); }

  action store_hdr_value {
    parser->hdr_value_len = LEN(hdr_value_start, fpc);
  }

  action write_hdr_value {
    if (parser->hdr_value_start) {
      parser->header(parser->parsed, PTR_TO(hdr_field_start), parser->hdr_field_len, PTR_TO(hdr_value_start), parser->hdr_value_len, parser->hdr_field_name);
    }
  }


  action msg_method_INVITE {
    if (!parser->method) {
      parser->method = method_INVITE;
    }
  }

  action msg_method_ACK {
    if (!parser->method) {
      parser->method = method_ACK;
    }
  }

  action msg_method_CANCEL {
    if (!parser->method) {
      parser->method = method_CANCEL;
    }
  }

  action msg_method_PRACK {
    if (!parser->method) {
      parser->method = method_PRACK;
    }
  }

  action msg_method_BYE {
    if (!parser->method) {
      parser->method = method_BYE;
    }
  }

  action msg_method_REFER {
    if (!parser->method) {
      parser->method = method_REFER;
    }
  }

  action msg_method_INFO {
    if (!parser->method) {
      parser->method = method_INFO;
    }
  }

  action msg_method_UPDATE {
    if (!parser->method) {
      parser->method = method_UPDATE;
    }
  }

  action msg_method_OPTIONS {
    if (!parser->method_set) {
      parser->method = method_OPTIONS;
      parser->method_set = 1;
    }
  }

  action msg_method_REGISTER {
    if (!parser->method) {
      parser->method = method_REGISTER;
    }
  }

  action msg_method_MESSAGE {
    if (!parser->method) {
      parser->method = method_MESSAGE;
    }
  }

  action msg_method_SUBSCRIBE {
    if (!parser->method) {
      parser->method = method_SUBSCRIBE;
    }
  }

  action msg_method_NOTIFY {
    if (!parser->method) {
      parser->method = method_NOTIFY;
    }
  }

  action msg_method_PUBLISH {
    if (!parser->method) {
      parser->method = method_PUBLISH;
    }
  }

  action msg_method_PULL {
    if (!parser->method) {
      parser->method = method_PULL;
    }
  }

  action msg_method_PUSH {
    if (!parser->method) {
      parser->method = method_PUSH;
    }
  }

  action msg_method_STORE {
    if (!parser->method) {
      parser->method = method_STORE;
    }
  }

  action msg_method_unknown {
    if (!parser->method) {
      parser->method = method_unknown;
    }
  }

  action msg_method {
    parser->message.method(parser->parsed, PTR_TO(mark), LEN(mark, fpc), parser->method);
  }

  action is_method_set {
    parser->method
  }


  action msg_sip_version {
    parser->message.sip_version(parser->parsed, PTR_TO(mark), LEN(mark, fpc));
  }

  action msg_status_code { 
    parser->message.status_code(parser->parsed, PTR_TO(mark), LEN(mark, fpc));
  }

  action msg_reason_phrase {
    parser->message.reason_phrase(parser->parsed, PTR_TO(mark), LEN(mark, fpc));
  }


  action start_header_param_key {
    MARK(header_param_key_start, fpc);
  }

  action header_param_key_len {
    parser->header_param_key_len = LEN(header_param_key_start, fpc);
    /* If current param has no value don't take previous param's value. */
    parser->header_param_value_len = 0;
  }

  action start_header_param_value {
    MARK(header_param_value_start, fpc);
  }

  action header_param_value_len {
    parser->header_param_value_len = LEN(header_param_value_start, fpc);
  }


  action init_via {
    parser->hdr_field_name = header_field_via;
  }

  action new_via { parser->num_via++; }

  action via_sent_by_host {
    if (parser->num_via == 1)
      parser->message.via_sent_by_host(parser->parsed, PTR_TO(mark), LEN(mark, fpc));
  }

  action via_sent_by_port {
    if (parser->num_via == 1)
      parser->message.via_sent_by_port(parser->parsed, PTR_TO(mark), LEN(mark, fpc));
  }

  action via_branch {
    if (parser->num_via == 1)
      parser->message.via_branch(parser->parsed, PTR_TO(mark), LEN(mark, fpc));
  }

  action via_branch_rfc3261 {
    if (parser->num_via == 1)
      parser->message.via_branch_rfc3261(parser->parsed, PTR_TO(mark), LEN(mark, fpc));
  }

  action via_received {
    if (parser->num_via == 1)
      parser->message.via_received(parser->parsed, PTR_TO(mark), LEN(mark, fpc));
  }

  action via_has_rport {
    if (parser->num_via == 1)
      parser->message.via_has_rport(parser->parsed);
  }

  action via_has_alias {
    if (parser->num_via == 1)
      parser->message.via_has_alias(parser->parsed);
  }

  action write_header_via_core {
    if (parser->num_via == 1)
      parser->message.header_core_value(parser->parsed, header_field_via, PTR_TO(hdr_value_start), LEN(hdr_value_start, fpc));
  }

  action write_via_param {
    if (parser->num_via == 1)
      parser->message.header_param(parser->parsed, header_field_via, PTR_TO(header_param_key_start), parser->header_param_key_len, PTR_TO(header_param_value_start), parser->header_param_value_len);
  }

  action new_call_id { parser->num_call_id++; }

  action msg_call_id {
    if (parser->num_call_id == 1)
      parser->message.call_id(parser->parsed, PTR_TO(mark), LEN(mark, fpc));
  }

  action new_cseq { parser->num_cseq++; }

  action msg_cseq_number {
    if (parser->num_cseq == 1)
      parser->message.cseq_number(parser->parsed, PTR_TO(mark), LEN(mark, fpc));
  }

  action new_max_forwards { parser->num_max_forwards++; }

  action msg_max_forwards {
    if (parser->num_max_forwards == 1)
      parser->message.max_forwards(parser->parsed, PTR_TO(mark), LEN(mark, fpc));
  }

  action new_content_length { parser->num_content_length++; }

  action msg_content_length {
    if (parser->num_content_length == 1)
      parser->message.content_length(parser->parsed, PTR_TO(mark), LEN(mark, fpc));
  }


  action uri_is_sip {
    if (parser->do_uri)
      parser->uri_scheme = uri_scheme_sip;
  }

  action uri_is_sips {
    if (parser->do_uri)
      parser->uri_scheme = uri_scheme_sips;
  }

  action uri_is_tel {
    if (parser->do_uri)
      parser->uri_scheme = uri_scheme_tel;
  }

  action uri_is_unknown {
    if (parser->do_uri)
      parser->uri_scheme = uri_scheme_unknown;
  }

  action uri_scheme {
    if (parser->do_uri)
      parser->uri.scheme(parser->parsed, parser->uri_owner, PTR_TO(mark), LEN(mark, fpc), parser->uri_scheme);
  }

  action uri_user {
    if (parser->do_uri)
      parser->uri.user(parser->parsed, parser->uri_owner, PTR_TO(mark), LEN(mark, fpc), parser->uri_scheme);
  }

  action uri_host_domain {
    if (parser->do_uri)
      parser->uri.host(parser->parsed, parser->uri_owner, PTR_TO(mark), LEN(mark, fpc), host_type_domain);
  }

  action uri_host_ipv4 {
    if (parser->do_uri)
      parser->uri.host(parser->parsed, parser->uri_owner, PTR_TO(mark), LEN(mark, fpc), host_type_ipv4);
  }

  action uri_host_ipv6 {
    if (parser->do_uri)
      parser->uri.host(parser->parsed, parser->uri_owner, PTR_TO(mark), LEN(mark, fpc), host_type_ipv6);
  }

  action uri_port {
    if (parser->do_uri)
      parser->uri.port(parser->parsed, parser->uri_owner, PTR_TO(mark), LEN(mark, fpc), parser->uri_scheme);
  }


  action start_uri_param_key {
    if (parser->do_uri)
      MARK(uri_param_key_start, fpc);
  }

  action uri_param_key_len {
    if (parser->do_uri) {
      parser->uri_param_key_len = LEN(uri_param_key_start, fpc);
      /* If current param has no value don't take previous param's value. */
      parser->uri_param_value_len = 0;
    }
  }

  action start_uri_param_value {
    if (parser->do_uri)
      MARK(uri_param_value_start, fpc);
  }

  action uri_param_value_len {
    if (parser->do_uri)
      parser->uri_param_value_len = LEN(uri_param_value_start, fpc);
  }

  action write_uri_param {
    if (parser->do_uri == 1)
      parser->uri.param(parser->parsed, parser->uri_owner, PTR_TO(uri_param_key_start), parser->uri_param_key_len, PTR_TO(uri_param_value_start), parser->uri_param_value_len);
  }


  action uri_headers {
    if (parser->do_uri)
      parser->uri.headers(parser->parsed, parser->uri_owner, PTR_TO(mark), LEN(mark, fpc), parser->uri_scheme);
  }

  action uri_tel_phone_context {
    if (parser->do_uri)
      parser->uri.known_param(parser->parsed, parser->uri_owner, uri_tel_phone_context, PTR_TO(mark), LEN(mark, fpc), 0);
  }

  action sip_uri_transport_udp {
    if (parser->do_uri)
      parser->uri.known_param(parser->parsed, parser->uri_owner, uri_param_transport, PTR_TO(mark), LEN(mark, fpc), transport_udp);
  }

  action sip_uri_transport_tcp {
    if (parser->do_uri)
      parser->uri.known_param(parser->parsed, parser->uri_owner, uri_param_transport, PTR_TO(mark), LEN(mark, fpc), transport_tcp);
  }

  action sip_uri_transport_tls {
    if (parser->do_uri)
      parser->uri.known_param(parser->parsed, parser->uri_owner, uri_param_transport, PTR_TO(mark), LEN(mark, fpc), transport_tls);
  }

  action sip_uri_transport_sctp {
    if (parser->do_uri)
      parser->uri.known_param(parser->parsed, parser->uri_owner, uri_param_transport, PTR_TO(mark), LEN(mark, fpc), transport_sctp);
  }

  action sip_uri_transport_ws {
    if (parser->do_uri)
      parser->uri.known_param(parser->parsed, parser->uri_owner, uri_param_transport, PTR_TO(mark), LEN(mark, fpc), transport_ws);
  }

  action sip_uri_transport_wss {
    if (parser->do_uri)
      parser->uri.known_param(parser->parsed, parser->uri_owner, uri_param_transport, PTR_TO(mark), LEN(mark, fpc), transport_wss);
  }

  action sip_uri_transport_unknown {
    if (parser->do_uri)
      parser->uri.known_param(parser->parsed, parser->uri_owner, uri_param_transport, PTR_TO(mark), LEN(mark, fpc), transport_unknown);
  }

  action sip_uri_has_lr {
    if (parser->do_uri)
      parser->uri.has_param(parser->parsed, parser->uri_owner, uri_param_lr);
  }

  action sip_uri_has_ob {
    if (parser->do_uri)
      parser->uri.has_param(parser->parsed, parser->uri_owner, uri_param_ob);
  }

  action sip_uri_ovid {
    if (parser->do_uri)
      parser->uri.known_param(parser->parsed, parser->uri_owner, uri_param_ovid, PTR_TO(mark), LEN(mark, fpc), 0);
  }

  action uri_display_name {
    if (parser->do_uri)
      if (!parser->uri_display_name_quoted)
        parser->uri.display_name(parser->parsed, parser->uri_owner, PTR_TO(mark), LEN(mark, fpc), parser->uri_scheme);
      else
        parser->uri.display_name(parser->parsed, parser->uri_owner, PTR_TO(mark)+1, LEN(mark, fpc)-2, parser->uri_scheme);
  }

  # This is for removing double quotes in display name.
  action uri_display_name_quoted {
    parser->uri_display_name_quoted=1;
  }

  action start_uri {
    if (parser->do_uri)
      MARK(uri_start, fpc);
  }

  action write_uri {
    if (parser->do_uri)
      parser->uri.full(parser->parsed, parser->uri_owner, PTR_TO(uri_start), LEN(uri_start, fpc), parser->uri_scheme);
    /* Reset variables after parsing a URI. */
    parser->do_uri = 0;
    parser->uri_owner = 0;
    parser->uri_scheme = 0;
    parser->uri_display_name_quoted = 0;
  }

  action init_ruri { parser->message.init_component(parser->parsed, component_ruri); }

  action do_request_uri {
    parser->do_uri = 1;
    parser->uri_owner = uri_owner_ruri;
  }

  action init_from {
    parser->message.init_component(parser->parsed, component_from);
    parser->hdr_field_name = header_field_from;
  }

  action new_from { parser->num_from++; }

  action do_from_uri {
    if (parser->num_from == 1) {
      parser->do_uri = 1;
      parser->uri_owner = uri_owner_from;
    }
  }

  action init_to {
    parser->message.init_component(parser->parsed, component_to);
    parser->hdr_field_name = header_field_to;
  }

  action new_to { parser->num_to++; }

  action do_to_uri {
    if (parser->num_to == 1) {
      parser->do_uri = 1;
      parser->uri_owner = uri_owner_to;
    }
  }


  action from_tag {
    parser->message.from_tag(parser->parsed, PTR_TO(mark), LEN(mark, fpc));
  }

  action to_tag {
    parser->message.to_tag(parser->parsed, PTR_TO(mark), LEN(mark, fpc));
  }


  action init_route {
    if (parser->route_found == 0) {
      parser->message.init_component(parser->parsed, component_route);
      parser->hdr_field_name = header_field_route;
      parser->route_found = 1;
    }
  }

  action init_route_uri {
    parser->message.init_component(parser->parsed, component_route_uri); }

  action do_route_uri {
    parser->do_uri = 1;
    parser->uri_owner = uri_owner_route;
  }


  action init_contact {
    parser->message.init_component(parser->parsed, component_contact);
    parser->hdr_field_name = header_field_contact;
  }

  action new_contact { parser->num_contact++; }

  action do_contact_uri {
    if (parser->num_contact == 1) {
      parser->do_uri = 1;
      parser->uri_owner = uri_owner_contact;
    }
  }

#   action write_contact_param {
#     if (parser->num_contact == 1)
#       parser->message.header_param(parser->parsed, header_field_contact, PTR_TO(header_param_key_start), parser->header_param_key_len, PTR_TO(header_param_value_start), parser->header_param_value_len);
#   }

  action contact_params {
    if (parser->num_contact == 1)
      parser->message.contact_params(parser->parsed, PTR_TO(mark), LEN(mark, fpc));
  }

  action contact_has_reg_id_param {
    if (parser->num_contact == 1)
      parser->message.contact_has_reg_id(parser->parsed);
  }

  action contact_is_valid {
    parser->contact_is_valid = 1;
  }

  action contact_is_invalid {
    parser->contact_is_valid = 0;
  }


  action require_option_tag {
    parser->message.option_tag(parser->parsed, header_field_require, PTR_TO(mark), LEN(mark, fpc));
  }

  action proxy_require_option_tag {
    parser->message.option_tag(parser->parsed, header_field_proxy_require, PTR_TO(mark), LEN(mark, fpc));
  }

  action supported_option_tag {
    parser->message.option_tag(parser->parsed, header_field_supported, PTR_TO(mark), LEN(mark, fpc));
  }


  action done { fbreak; }

  include grammar_sip_message "grammar_sip_message.rl";
}%%



/** Data **/
%% write data;

int sip_message_parser_init(sip_message_parser *parser)
{
  TRACE();
  int cs = 0;
  %% write init;
  parser->cs = cs;
  parser->nread = 0;
  parser->error_start = NULL;
  parser->error_len = 0;
  parser->error_pos = 0;

  parser->mark = 0;
  parser->hdr_field_start = 0;
  parser->hdr_field_len = 0;
  parser->hdr_value_start = 0;
  parser->hdr_value_len = 0;
  parser->hdr_field_name = header_field_any;
  parser->uri_start = 0;
  parser->uri_param_key_start = 0;
  parser->uri_param_value_start = 0;
  parser->header_param_key_start = 0;
  parser->header_param_value_start = 0;

  parser->method = 0;
  parser->method_set = 0;
  parser->num_via = 0;
  parser->num_from = 0;
  parser->num_to = 0;
  parser->num_call_id = 0;
  parser->num_cseq = 0;
  parser->num_max_forwards = 0;
  parser->num_content_length = 0;
  parser->num_contact = 0;
  parser->contact_is_valid = 0;
  parser->route_found = 0;
  parser->do_uri = 0;
  parser->uri_owner = 0;
  parser->uri_scheme = 0;
  parser->uri_display_name_quoted = 0;

  parser->parsed = Qnil;

  return(1);
}


/** exec **/
size_t sip_message_parser_execute(sip_message_parser *parser, const char *buffer, size_t len, size_t off)
{
  TRACE();
  const char *p, *pe;
  int cs = parser->cs;

  assert(off <= len && "offset past end of buffer");

  p = buffer+off;
  pe = buffer+len;

  assert(*pe == '\0' && "pointer does not end on NULL");
  assert(pe - p == len - off && "pointers aren't same distance");

  %% write exec;

  parser->cs = cs;
  parser->nread += p - (buffer + off);

  assert(p <= pe && "buffer overflow after parsing execute");
  assert(parser->nread <= len && "nread longer than length");
  assert(parser->mark < len && "mark is after buffer end");
  assert(parser->hdr_field_start < len && "field starts after buffer end");
  assert(parser->hdr_field_len <= len && "field has length longer than whole buffer");
  assert(parser->hdr_value_start < len && "value starts after buffer end");
  assert(parser->hdr_value_len <= len && "value has length longer than whole buffer");

  if (sip_message_parser_has_error(parser)) {
    parser->error_start = (char *)buffer;
    parser->error_len = pe - buffer;
    parser->error_pos = p - buffer;
    /* DOC:
     * buffer is the start of the parsed data.
     * p is last position of the parsing.
     * pe is first position after data ends.
     */
  }

  return(parser->nread);
}

int sip_message_parser_finish(sip_message_parser *parser)
{
  TRACE();
  int cs = parser->cs;

  parser->cs = cs;

  if (sip_message_parser_has_error(parser))
    return -1;
  else if (sip_message_parser_is_finished(parser))
    return 1;
  else
    return 0;
}

int sip_message_parser_has_error(sip_message_parser *parser)
{
  TRACE();
  return parser->cs == sip_message_parser_error;
}

int sip_message_parser_is_finished(sip_message_parser *parser)
{
  TRACE();
  return parser->cs == sip_message_parser_first_final;
}
