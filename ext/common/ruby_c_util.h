/*
 * Generic Ruby C functions and macros go here.
 */

#ifndef ruby_c_util_h
#define ruby_c_util_h


#include <ruby.h>
#include <ruby/encoding.h>  /* Required:  http://redmine.ruby-lang.org/issues/show/4272 */
#include "c_util.h"


#define RB_STR_UTF8_NEW(s, len) (rb_enc_str_new(s, len, rb_utf8_encoding()))


/*
 * my_rb_str_hex_unescape: Unescapes hexadecimal encoded symbols (%NN).
 */
static VALUE my_rb_str_hex_unescape(const char *str, size_t len)
{
  TRACE();
  /* Check if hexadecimal unescaping is required. */
  if (strnchr(str, len, '%')) {
    char *new_str;
    VALUE str_unescaped;

    new_str = ALLOC_N(char, len);
    memcpy(new_str, str, len);

    char *s, *t;
    char hex[3] = {0, 0, 0};
    int i;

    for (s = t = new_str, i = 0 ; i < len ; s++, i++) {
      if (*s != '%' || !(*(s+1)) || !(*(s+2)))
        *t++ = *s;
      else {
        hex[0] = *(s+1);
        hex[1] = *(s+2);
        *t++ = (strtol(hex, NULL, 16) & 0xFF);
        s += 2;
        len -= 2;
      }
    }

    str_unescaped = RB_STR_UTF8_NEW(new_str, len);
    xfree(new_str);
    return(str_unescaped);
  }
  /* If unescaping is not required, then create a Ruby string with original pointer and length. */
  else
    return(RB_STR_UTF8_NEW(str, len));
}

/*
 * my_rb_str_downcase: Downcases a string formed by simple symbols (ASCII).
 */
static VALUE my_rb_str_downcase(const char *str, size_t len)
{
  TRACE();
  /* Check if there is at least an upcase char. */
  if (str_find_upcase(str, len)) {
    char *new_str;
    VALUE str_downcased;

    new_str = ALLOC_N(char, len);
    memcpy(new_str, str, len);

    char *s;
    int i;

    for (s = new_str, i = 0 ; i < len ; s++, i++)
      if (*s >= 'A' && *s <= 'Z')
        *s += 32;

    str_downcased = RB_STR_UTF8_NEW(new_str, len);
    xfree(new_str);
    return(str_downcased);
  }
  /* If not, then create a Ruby string with original pointer and length. */
  else
    return(RB_STR_UTF8_NEW(str, len));
}


#endif

