#include <ruby.h>
#include "ws_framing_utils.h"
#include "ext_help.h"


static VALUE mOverSIP;
static VALUE mWebSocket;
static VALUE mFramingUtils;
static VALUE cUtf8Validator;



/*
 * Ruby functions.
 */

VALUE WsFramingUtils_unmask(VALUE self, VALUE payload, VALUE mask)
{
  char *payload_str, *mask_str;
  long payload_len;  /* mask length is always 4 bytes. */
  char *unmasked_payload_str;
  VALUE rb_unmasked_payload;
  int i;

  if (TYPE(payload) != T_STRING)
    rb_raise(rb_eTypeError, "Argument must be a String");

  if (TYPE(mask) != T_STRING)
    rb_raise(rb_eTypeError, "Argument must be a String");

  if (RSTRING_LEN(mask) != 4)
    rb_raise(rb_eTypeError, "mask size must be 4 bytes");

  payload_str = RSTRING_PTR(payload);
  payload_len = RSTRING_LEN(payload);
  mask_str = RSTRING_PTR(mask);

  /* NOTE: In Ruby C extensions always use:
   *    pointer = ALLOC_N(type, n)
   * which means: pointer = (type*)xmalloc(sizeof(type)*(n))
   * and:
   *    xfree()
   */

  unmasked_payload_str = ALLOC_N(char, payload_len);

  for(i=0; i < payload_len; i++)
    unmasked_payload_str[i] = payload_str[i] ^ mask_str[i % 4];

  rb_unmasked_payload = rb_str_new(unmasked_payload_str, payload_len);
  xfree(unmasked_payload_str);
  return(rb_unmasked_payload);
}


static void Utf8Validator_free(void *validator)
{
  TRACE();
  if(validator) {
    xfree(validator);
  }
}


VALUE Utf8Validator_alloc(VALUE klass)
{
  TRACE();
  VALUE obj;
  utf8_validator *validator = ALLOC(utf8_validator);

  validator->state = UTF8_ACCEPT;

  obj = Data_Wrap_Struct(klass, NULL, Utf8Validator_free, validator);
  return obj;
}


VALUE Utf8Validator_reset(VALUE self)
{
  TRACE();
  utf8_validator *validator = NULL;
  DATA_GET(self, utf8_validator, validator);

  validator->state = UTF8_ACCEPT;

  return Qnil;
}


/*
 * Returns:
 * - true: Valid UTF-8 string.
 * - nil: Valid but not terminated UTF-8 string.
 * - false: Invalid UTF-8 string.
 */
VALUE Utf8Validator_validate(VALUE self, VALUE string)
{
  TRACE();
  utf8_validator *validator = NULL;
  uint8_t *str = NULL;
  int i;

  REQUIRE_TYPE(string, T_STRING);
  str = (uint8_t *)RSTRING_PTR(string);

  DATA_GET(self, utf8_validator, validator);

  for(i=0; i < RSTRING_LEN(string); i++)
    if (utf8_decode(&validator->state, &validator->codepoint, str[i]) == UTF8_REJECT)
      return Qfalse;

  switch(validator->state) {
    case UTF8_ACCEPT:
      return Qtrue;
      break;
    default:
      return Qnil;
      break;
  }
}


void Init_ws_framing_utils()
{
  mOverSIP = rb_define_module("OverSIP");
  mWebSocket = rb_define_module_under(mOverSIP, "WebSocket");
  mFramingUtils = rb_define_module_under(mWebSocket, "FramingUtils");
  cUtf8Validator = rb_define_class_under(mFramingUtils, "Utf8Validator", rb_cObject);

  rb_define_module_function(mFramingUtils, "unmask", WsFramingUtils_unmask,2);

  rb_define_alloc_func(cUtf8Validator, Utf8Validator_alloc);
  rb_define_method(cUtf8Validator, "reset", Utf8Validator_reset,0);
  rb_define_method(cUtf8Validator, "validate", Utf8Validator_validate,1);
}
