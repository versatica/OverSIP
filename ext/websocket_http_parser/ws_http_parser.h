#ifndef ws_http_parser_h
#define ws_http_parser_h


#include <sys/types.h>

#if defined(_WIN32)
#include <stddef.h>
#endif


enum method {
  method_GET = 1,
  method_POST,
  method_OPTIONS,
  method_unknown
};

enum uri_scheme {
  uri_scheme_http = 1,
  uri_scheme_https,
  uri_scheme_unknown
};

typedef void (*msg_method_cb)(void *data, const char *at, size_t length, enum method method);
typedef void (*uri_scheme_cb)(void *data, const char *at, size_t length, enum uri_scheme);
typedef void (*msg_element_cb)(void *data, const char *at, size_t length);
typedef void (*header_cb)(void *data, const char *hdr_field, size_t hdr_field_len, const char *hdr_value, size_t hdr_value_len);


typedef struct struct_request {
  msg_method_cb               method;
  uri_scheme_cb               uri_scheme;
  msg_element_cb              request_uri;
  msg_element_cb              request_path;
  msg_element_cb              query;
  msg_element_cb              fragment;
  msg_element_cb              http_version;
  msg_element_cb              host;
  msg_element_cb              port;
  msg_element_cb              content_length;
  msg_element_cb              hdr_connection_value;
  msg_element_cb              hdr_upgrade;
  msg_element_cb              hdr_origin;
  msg_element_cb              hdr_sec_websocket_version;
  msg_element_cb              hdr_sec_websocket_key;
  msg_element_cb              hdr_sec_websocket_protocol_value;
} struct_request;

typedef struct ws_http_request_parser {
  /* Parser stuf. */
  int             cs;
  size_t          nread;
  char *          error_start;
  size_t          error_len;
  int             error_pos;
  
  size_t          mark;
  size_t          hdr_field_start;
  size_t          hdr_field_len;
  size_t          hdr_value_start;
  size_t          hdr_value_len;
  size_t          query_start;
  size_t          fragment_start;

  /* Request method. */
  enum method     method;
  /* URI scheme type. */
  enum uri_scheme uri_scheme;
  
  header_cb       header;
  struct_request  request;

  /* OverSIP::WebSocket::Request instance. */
  void *          data;
} ws_http_request_parser;


int ws_http_request_parser_init(ws_http_request_parser *parser);
int ws_http_request_parser_finish(ws_http_request_parser *parser);
size_t ws_http_request_parser_execute(ws_http_request_parser *parser, const char *buffer, size_t len, size_t off);
int ws_http_request_parser_has_error(ws_http_request_parser *parser);
int ws_http_request_parser_is_finished(ws_http_request_parser *parser);
#define ws_http_request_parser_nread(parser) (parser)->nread


#endif
