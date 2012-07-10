#include <ruby.h>
#include "ext_help.h"
#include "ws_http_parser.h"
#include "../utils/utils_ruby.h"
#include "../common/c_util.h"
#include "../common/ruby_c_util.h"


static VALUE headerize(const char*, size_t);


static VALUE mOverSIP;
static VALUE eOverSIPError;

static VALUE mWebSocket;
static VALUE cHttpRequestParser;
static VALUE eHttpRequestParserError;

static ID id_http_method;
static ID id_is_unknown_method;
static ID id_http_version;
static ID id_uri_scheme;
static ID id_uri;
static ID id_uri_path;
static ID id_uri_query;
static ID id_uri_fragment;
static ID id_host;
static ID id_port;
static ID id_content_length;
static ID id_hdr_connection;
static ID id_hdr_upgrade;
static ID id_hdr_sec_websocket_version;
static ID id_hdr_sec_websocket_key;
static ID id_hdr_sec_websocket_protocol;
static ID id_hdr_origin;

static VALUE symbol_GET;
static VALUE symbol_POST;
static VALUE symbol_OPTIONS;
static VALUE symbol_http;
static VALUE symbol_https;



static void header(void *data, const char *hdr_field, size_t hdr_field_len, const char *hdr_value, size_t hdr_value_len)
{
  TRACE();
  char *ch, *end;
  VALUE parsed = (VALUE)data;
  VALUE v, f, el;

  /* Header name. */
  f = headerize(hdr_field, hdr_field_len);

  /* Header value. */
  v = RB_STR_UTF8_NEW(hdr_value, hdr_value_len);

  /* Here we have the header name capitalized in variable f. */
  el = rb_hash_lookup(parsed, f);
  switch(TYPE(el)) {
    case T_ARRAY:
      rb_ary_push(el, v);
      break;
    default:
      rb_hash_aset(parsed, f, rb_ary_new3(1, v));
      break;
  }
}


static void req_method(void *data, const char *at, size_t length, enum method method)
{
  TRACE();
  VALUE parsed = (VALUE)data;
  VALUE v;

  switch(method) {
    /* If the method is known store it as a symbol (i.e. :GET). */
    case method_GET:
      rb_ivar_set(parsed, id_http_method, symbol_GET);
      break;
    case method_POST:
      rb_ivar_set(parsed, id_http_method, symbol_POST);
      break;
    case method_OPTIONS:
      rb_ivar_set(parsed, id_http_method, symbol_OPTIONS);
      break;
    /* If the method is unknown store it as a string (i.e. "CHICKEN") and set the
    attribute @is_unknown_method to true. */
    case method_unknown:
      v = RB_STR_UTF8_NEW(at, length);
      rb_ivar_set(parsed, id_http_method, v);
      rb_ivar_set(parsed, id_is_unknown_method, Qtrue);
      break;
  }
}


static void req_uri_scheme(void *data, const char *at, size_t length, enum uri_scheme scheme)
{
  TRACE();
  VALUE parsed = (VALUE)data;
  VALUE v;

  switch(scheme) {
    case uri_scheme_http:     v = symbol_http;   break;
    case uri_scheme_https:    v = symbol_https;  break;
    case uri_scheme_unknown:  v = my_rb_str_downcase(at, length); break;
  }

  rb_ivar_set(parsed, id_uri_scheme, v);
}


static void req_request_uri(void *data, const char *at, size_t length)
{
  TRACE();
  VALUE parsed = (VALUE)data;
  VALUE v;

  v = RB_STR_UTF8_NEW(at, length);
  rb_ivar_set(parsed, id_uri, v);
}


static void req_request_path(void *data, const char *at, size_t length)
{
  TRACE();
  VALUE parsed = (VALUE)data;
  VALUE v;

  v = RB_STR_UTF8_NEW(at, length);
  rb_ivar_set(parsed, id_uri_path, v);
}


static void req_query(void *data, const char *at, size_t length)
{
  TRACE();
  VALUE parsed = (VALUE)data;
  VALUE v;

  v = RB_STR_UTF8_NEW(at, length);
  rb_ivar_set(parsed, id_uri_query, v);
}


static void req_fragment(void *data, const char *at, size_t length)
{
  TRACE();
  VALUE parsed = (VALUE)data;
  VALUE v;

  v = RB_STR_UTF8_NEW(at, length);
  rb_ivar_set(parsed, id_uri_fragment, v);
}


static void req_http_version(void *data, const char *at, size_t length)
{
  TRACE();
  VALUE parsed = (VALUE)data;
  VALUE v;

  v = RB_STR_UTF8_NEW(at, length);
  rb_ivar_set(parsed, id_http_version, v);
}


static void req_host(void *data, const char *at, size_t length)
{
  TRACE();
  VALUE parsed = (VALUE)data;
  VALUE v;

  /* If it's a domain and ends with ".", remove it. */
  if (at[length-1] == '.')
    length--;

  v = my_rb_str_downcase(at, length);
  rb_ivar_set(parsed, id_host, v);
}


static void req_port(void *data, const char *at, size_t length)
{
  TRACE();
  VALUE parsed = (VALUE)data;
  VALUE v;

  v = INT2FIX(str_to_int(at, length));
  rb_ivar_set(parsed, id_port, v);
}


static void req_content_length(void *data, const char *at, size_t length)
{
  TRACE();
  VALUE parsed = (VALUE)data;
  VALUE v;

  v = LONG2FIX(strtol(at,NULL,0));
  rb_ivar_set(parsed, id_content_length, v);
}


static void req_hdr_connection_value(void *data, const char *at, size_t length)
{
  TRACE();
  VALUE parsed = (VALUE)data;
  VALUE v;
  VALUE array;

  v = my_rb_str_downcase(at, length);

  array = rb_ivar_get(parsed, id_hdr_connection);
  switch(TYPE(array)) {
    case T_ARRAY:
      rb_ary_push(array, v);
      break;
    default:
      rb_ivar_set(parsed, id_hdr_connection, rb_ary_new3(1, v));
      break;
  }
}


static void req_hdr_upgrade(void *data, const char *at, size_t length)
{
  TRACE();
  VALUE parsed = (VALUE)data;
  VALUE v;

  v = my_rb_str_downcase(at, length);
  rb_ivar_set(parsed, id_hdr_upgrade, v);
}


static void req_hdr_sec_websocket_version(void *data, const char *at, size_t length)
{
  TRACE();
  VALUE parsed = (VALUE)data;
  VALUE v;

  v = INT2FIX(str_to_int(at, length));
  rb_ivar_set(parsed, id_hdr_sec_websocket_version, v);
}


static void req_hdr_sec_websocket_key(void *data, const char *at, size_t length)
{
  TRACE();
  VALUE parsed = (VALUE)data;
  VALUE v;

  v = rb_str_new(at, length);
  rb_ivar_set(parsed, id_hdr_sec_websocket_key, v);
}


static void req_hdr_sec_websocket_protocol_value(void *data, const char *at, size_t length)
{
  TRACE();
  VALUE parsed = (VALUE)data;
  VALUE v;
  VALUE array;

  v = rb_str_new(at, length);

  array = rb_ivar_get(parsed, id_hdr_sec_websocket_protocol);
  switch(TYPE(array)) {
    case T_ARRAY:
      rb_ary_push(array, v);
      break;
    default:
      rb_ivar_set(parsed, id_hdr_sec_websocket_protocol, rb_ary_new3(1, v));
      break;
  }
}


static void req_hdr_origin(void *data, const char *at, size_t length)
{
  TRACE();
  VALUE parsed = (VALUE)data;
  VALUE v;

  v = my_rb_str_downcase(at, length);
  rb_ivar_set(parsed, id_hdr_origin, v);
}



/*************** Custom C funcions (helpers) ****************/


/*
 * Normalizes it (by capitalizing the first letter and each letter
 * under a "-" or "_" symbol).
*/
static VALUE headerize(const char* hname, size_t hname_len)
{
  TRACE();
  VALUE headerized;
  char* str;
  int i;

  headerized = rb_str_new(hname, hname_len);
  str = RSTRING_PTR(headerized);
  if (*str >= 'a' && *str <= 'z')
    *str &= ~0x20;

  for(i = 1; i < hname_len; i++) {
    if (str[i-1] == '-' || str[i-1] == '_') {
      if (str[i] >= 'a' && str[i] <= 'z')
        str[i] &= ~0x20;
    }
    else {
      if (str[i] >= 'A' && str[i] <= 'Z')
        str[i] += 32;
    }
  }

  return(headerized);
}




/*************** Ruby functions ****************/

static void HttpRequestParser_free(void *parser)
{
  TRACE();
  if(parser) {
    /* NOTE: Use always xfree() rather than free():
     *   http://www.mail-archive.com/libxml-devel@rubyforge.org/msg00242.html */
    xfree(parser);
  }
}


VALUE HttpRequestParser_alloc(VALUE klass)
{
  TRACE();
  VALUE obj;
  /* NOTE: Use always ALLOC/ALLOC_N rather than malloc().
   * ALLOC uses xmalloc:
   *   ALLOC(type)   (type*)xmalloc(sizeof(type))
   *   ALLOC_N(type, n)   (type*)xmalloc(sizeof(type)*(n))
  */
  ws_http_request_parser *parser = ALLOC(ws_http_request_parser);

  parser->header                 = header;
  parser->request.method         = req_method;
  parser->request.uri_scheme     = req_uri_scheme;
  parser->request.request_uri    = req_request_uri;
  parser->request.request_path   = req_request_path;
  parser->request.query          = req_query;
  parser->request.fragment       = req_fragment;
  parser->request.http_version   = req_http_version;
  parser->request.host           = req_host;
  parser->request.port           = req_port;
  parser->request.content_length = req_content_length;
  parser->request.hdr_connection_value = req_hdr_connection_value;
  parser->request.hdr_upgrade    = req_hdr_upgrade;
  parser->request.hdr_sec_websocket_version = req_hdr_sec_websocket_version;
  parser->request.hdr_sec_websocket_key = req_hdr_sec_websocket_key;
  parser->request.hdr_sec_websocket_protocol_value = req_hdr_sec_websocket_protocol_value;
  parser->request.hdr_origin     = req_hdr_origin;

  ws_http_request_parser_init(parser);

  obj = Data_Wrap_Struct(klass, NULL, HttpRequestParser_free, parser);
  return obj;
}


/**
 * call-seq:
 *    parser.new -> parser
 *
 * Creates a new parser.
 */
VALUE HttpRequestParser_init(VALUE self)
{
  TRACE();
  ws_http_request_parser *parser = NULL;
  DATA_GET(self, ws_http_request_parser, parser);
  ws_http_request_parser_init(parser);

  return self;
}


/**
 * call-seq:
 *    parser.reset -> nil
 *
 * Resets the parser to it's initial state so that you can reuse it
 * rather than making new ones.
 */
VALUE HttpRequestParser_reset(VALUE self)
{
  TRACE();
  ws_http_request_parser *parser = NULL;
  DATA_GET(self, ws_http_request_parser, parser);
  ws_http_request_parser_init(parser);

  return Qnil;
}


/**
 * call-seq:
 *    parser.finish -> true/false
 *
 * Finishes a parser early which could put in a "good" or bad state.
 * You should call reset after finish it or bad things will happen.
 */
VALUE HttpRequestParser_finish(VALUE self)
{
  TRACE();
  ws_http_request_parser *parser = NULL;
  DATA_GET(self, ws_http_request_parser, parser);
  ws_http_request_parser_finish(parser);

  return ws_http_request_parser_is_finished(parser) ? Qtrue : Qfalse;
}


VALUE HttpRequestParser_execute(VALUE self, VALUE req_hash, VALUE buffer, VALUE start)
{
  TRACE();
  ws_http_request_parser *parser = NULL;
  int from = 0;
  char *dptr = NULL;
  long dlen = 0;

  REQUIRE_TYPE(req_hash, T_HASH);
  REQUIRE_TYPE(buffer, T_STRING);
  REQUIRE_TYPE(start, T_FIXNUM);

  DATA_GET(self, ws_http_request_parser, parser);

  from = FIX2INT(start);
  dptr = RSTRING_PTR(buffer);
  dlen = RSTRING_LEN(buffer);

  /* This should never occur or there is an error in the parser. */
  if(from >= dlen)
    rb_raise(eHttpRequestParserError, "requested start is after buffer end.");

  parser->data = (void *)req_hash;
  ws_http_request_parser_execute(parser, dptr, dlen, from);

  if(ws_http_request_parser_has_error(parser))
    return Qfalse;
  else
    return INT2FIX(ws_http_request_parser_nread(parser));
}


/**
 * call-seq:
 *    parser.error? -> true/false
 *
 * Tells you whether the parser is in an error state.
 */
VALUE HttpRequestParser_has_error(VALUE self)
{
  TRACE();
  ws_http_request_parser *parser = NULL;
  DATA_GET(self, ws_http_request_parser, parser);

  return ws_http_request_parser_has_error(parser) ? Qtrue : Qfalse;
}


/**
 * call-seq:
 *    parser.error -> String
 *
 * Returns a String showing the error by enclosing the exact wrong char between {{{ }}}.
 */
VALUE HttpRequestParser_error(VALUE self)
{
  TRACE();
  ws_http_request_parser *parser = NULL;
  DATA_GET(self, ws_http_request_parser, parser);

  if(ws_http_request_parser_has_error(parser)) {
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
VALUE HttpRequestParser_is_finished(VALUE self)
{
  TRACE();
  ws_http_request_parser *parser = NULL;
  DATA_GET(self, ws_http_request_parser, parser);

  return ws_http_request_parser_is_finished(parser) ? Qtrue : Qfalse;
}


/**
 * call-seq:
 *    parser.nread -> Integer
 *
 * Returns the amount of data processed so far during this processing cycle.  It is
 * set to 0 on initialize or reset calls and is incremented each time execute is called.
 */
VALUE HttpRequestParser_nread(VALUE self)
{
  TRACE();
  ws_http_request_parser *parser = NULL;
  DATA_GET(self, ws_http_request_parser, parser);

  return INT2FIX(parser->nread);
}


void Init_ws_http_parser()
{
  mOverSIP = rb_define_module("OverSIP");
  eOverSIPError = rb_define_class_under(mOverSIP, "Error", rb_eStandardError);

  mWebSocket = rb_define_module_under(mOverSIP, "WebSocket");
  cHttpRequestParser = rb_define_class_under(mWebSocket, "HttpRequestParser", rb_cObject);
  eHttpRequestParserError = rb_define_class_under(mWebSocket, "HttpRequestParserError", eOverSIPError);

  rb_define_alloc_func(cHttpRequestParser, HttpRequestParser_alloc);
  rb_define_method(cHttpRequestParser, "initialize", HttpRequestParser_init,0);
  rb_define_method(cHttpRequestParser, "reset", HttpRequestParser_reset,0);
  rb_define_method(cHttpRequestParser, "finish", HttpRequestParser_finish,0);
  rb_define_method(cHttpRequestParser, "execute", HttpRequestParser_execute,3);
  rb_define_method(cHttpRequestParser, "error?", HttpRequestParser_has_error,0);
  rb_define_method(cHttpRequestParser, "error", HttpRequestParser_error,0);
  rb_define_method(cHttpRequestParser, "finished?", HttpRequestParser_is_finished,0);
  rb_define_method(cHttpRequestParser, "nread", HttpRequestParser_nread,0);

  id_http_method = rb_intern("@http_method");
  id_is_unknown_method = rb_intern("is_unknown_method");
  id_http_version = rb_intern("@http_version");
  id_uri_scheme = rb_intern("@uri_scheme");
  id_uri = rb_intern("@uri");
  id_uri_path = rb_intern("@uri_path");
  id_uri_query = rb_intern("@uri_query");
  id_uri_fragment = rb_intern("@uri_fragment");
  id_host = rb_intern("@host");
  id_port = rb_intern("@port");
  id_content_length = rb_intern("@content_length");
  id_hdr_connection = rb_intern("@hdr_connection");
  id_hdr_upgrade = rb_intern("@hdr_upgrade");
  id_hdr_sec_websocket_version = rb_intern("@hdr_sec_websocket_version");
  id_hdr_sec_websocket_key = rb_intern("@hdr_sec_websocket_key");
  id_hdr_sec_websocket_protocol = rb_intern("@hdr_sec_websocket_protocol");
  id_hdr_origin = rb_intern("@hdr_origin");

  symbol_GET = ID2SYM(rb_intern("GET"));
  symbol_POST = ID2SYM(rb_intern("POST"));
  symbol_OPTIONS = ID2SYM(rb_intern("OPTIONS"));
  symbol_http = ID2SYM(rb_intern("http"));
  symbol_https = ID2SYM(rb_intern("https"));
}
