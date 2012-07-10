#include "ws_http_parser.h"
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
  machine ws_http_request_parser;


  action mark { MARK(mark, fpc); }

  action start_hdr_field {
    MARK(hdr_field_start, fpc);
  }

  action write_hdr_field {
    parser->hdr_field_len = LEN(hdr_field_start, fpc);
  }

  action start_hdr_value { MARK(hdr_value_start, fpc); }

  action store_hdr_value {
    parser->hdr_value_len = LEN(hdr_value_start, fpc);
  }

  action write_hdr_value {
    if (parser->hdr_value_start) {
      parser->header(parser->data, PTR_TO(hdr_field_start), parser->hdr_field_len, PTR_TO(hdr_value_start), parser->hdr_value_len);
    }
  }

  action method_GET { parser->method = method_GET; }
  action method_POST { parser->method = method_POST; }
  action method_OPTIONS { parser->method = method_OPTIONS; }
  action method_unknown {
    if (!parser->method) {
      parser->method = method_unknown;
    }
  }

  action req_method {
    parser->request.method(parser->data, PTR_TO(mark), LEN(mark, fpc), parser->method);
  }

  action request_uri {
    parser->request.request_uri(parser->data, PTR_TO(mark), LEN(mark, fpc));
  }

  action request_path {
    parser->request.request_path(parser->data, PTR_TO(mark), LEN(mark, fpc));
  }

  action start_query {
    MARK(query_start, fpc);
  }

  action query {
    parser->request.query(parser->data, PTR_TO(query_start), LEN(query_start, fpc));
  }

  action fragment {
    parser->request.fragment(parser->data, PTR_TO(mark), LEN(mark, fpc));
  }

  action uri_is_http {
    parser->uri_scheme = uri_scheme_http;
  }

  action uri_is_https {
    parser->uri_scheme = uri_scheme_https;
  }

  action uri_is_unknown {
    parser->uri_scheme = uri_scheme_unknown;
  }

  action uri_scheme {
    parser->request.uri_scheme(parser->data, PTR_TO(mark), LEN(mark, fpc), parser->uri_scheme);
  }

  action http_version {
    parser->request.http_version(parser->data, PTR_TO(mark), LEN(mark, fpc));
  }

  action host {
    parser->request.host(parser->data, PTR_TO(mark), LEN(mark, fpc));
  }

  action port {
    parser->request.port(parser->data, PTR_TO(mark), LEN(mark, fpc));
  }

  action content_length {
    parser->request.content_length(parser->data, PTR_TO(mark), LEN(mark, fpc));
  }

  action hdr_connection_value {
    parser->request.hdr_connection_value(parser->data, PTR_TO(mark), LEN(mark, fpc));
  }

  action hdr_upgrade {
    parser->request.hdr_upgrade(parser->data, PTR_TO(mark), LEN(mark, fpc));
  }

  action hdr_origin {
    parser->request.hdr_origin(parser->data, PTR_TO(mark), LEN(mark, fpc));
  }

  action hdr_sec_websocket_version {
    parser->request.hdr_sec_websocket_version(parser->data, PTR_TO(mark), LEN(mark, fpc));
  }

  action hdr_sec_websocket_key {
    parser->request.hdr_sec_websocket_key(parser->data, PTR_TO(mark), LEN(mark, fpc));
  }

  action hdr_sec_websocket_protocol_value {
    parser->request.hdr_sec_websocket_protocol_value(parser->data, PTR_TO(mark), LEN(mark, fpc));
  }

  action done { fbreak; }

  include grammar_ws_http_request "grammar_ws_http_request.rl";
}%%

/** Data **/
%% write data;

int ws_http_request_parser_init(ws_http_request_parser *parser)
{
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
  parser->query_start = 0;

  parser->method = 0;
  parser->uri_scheme = 0;

  parser->data = NULL;

  return(1);
}


/** exec **/
size_t ws_http_request_parser_execute(ws_http_request_parser *parser, const char *buffer, size_t len, size_t off)
{
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

  if (ws_http_request_parser_has_error(parser)) {
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

int ws_http_request_parser_finish(ws_http_request_parser *parser)
{
  int cs = parser->cs;

  parser->cs = cs;

  if (ws_http_request_parser_has_error(parser))
    return -1;
  else if (ws_http_request_parser_is_finished(parser))
    return 1;
  else
    return 0;
}

int ws_http_request_parser_has_error(ws_http_request_parser *parser)
{
  return parser->cs == ws_http_request_parser_error;
}

int ws_http_request_parser_is_finished(ws_http_request_parser *parser)
{
  return parser->cs == ws_http_request_parser_first_final;
}
