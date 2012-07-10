#ifndef common_headers_h
#define common_headers_h

#include "../common/c_util.h"
#include "ruby.h"


/* There are 20 headers with sort representation. */
#define NUM_SHORT_HEADERS 20


struct common_header_name {
  const signed long len;
  const char *name;
  VALUE value;
  const char short_name;
};


struct short_header {
  char abbr;
  VALUE value;
};


/*
 * A list of common SIP headers we expect to receive.
 * This allows us to avoid repeatedly creating identical string
 * objects to be used with rb_hash_aset().
 */
static struct common_header_name common_headers[] = {
#define f(N, S) { (sizeof(N) - 1), N, Qnil, S }
  f("Accept", ' '),
  f("Accept-Contact", 'A'),
  f("Accept-Encoding", ' '),
  f("Accept-Language", ' '),
  f("Alert-Info", ' '),
  f("Allow", ' '),
  f("Allow-Events", 'U'),
  f("Authentication-Info", ' '),
  f("Authorization", ' '),
  f("Call-ID", 'I'),
  f("Call-Info", ' '),
  f("Contact", 'M'),
  f("Content-Disposition", ' '),
  f("Content-Encoding", 'E'),
  f("Content-Language", ' '),
  f("Content-Length", 'L'),
  f("Content-Type", 'C'),
  f("CSeq", ' '),
  f("Date", ' '),
  f("Event", 'O'),
  f("Error-Info", ' '),
  f("Expires", ' '),
  f("From", 'F'),
  f("Identity", 'Y'),
  f("Identity-Info", 'N'),
  f("In-Reply-To", ' '),
  f("Max-Forwards", ' '),
  f("Min-Expires", ' '),
  f("MIME-Version", ' '),
  f("Organization", ' '),
  f("Priority", ' '),
  f("Proxy-Authenticate", ' '),
  f("Proxy-Authorization", ' '),
  f("Proxy-Require", ' '),
  f("Record-Route", ' '),
  f("Refer-To", 'R'),
  f("Referred-By", 'B'),
  f("Reject-Contact", 'J'),
  f("Reply-To", ' '),
  f("Request-Disposition", 'D'),
  f("Require", ' '),
  f("Retry-After", ' '),
  f("Route", ' '),
  f("Server", ' '),
  f("Session-Expires", 'X'),
  f("Subject", 'S'),
  f("Supported", 'K'),
  f("Timestamp", ' '),
  f("To", 'T'),
  f("Unsupported", ' '),
  f("User-Agent", ' '),
  f("Via", 'V'),
  f("Warning", ' '),
  f("WWW-Authenticate", ' ')
# undef f
};


/*
 * The list of short headers. This list is filled by the funcion
 * init_short_header_names.
 */ 
static struct short_header short_headers[NUM_SHORT_HEADERS];


/* this function is not performance-critical, called only at load time */
static void init_common_headers(void)
{
  TRACE();
  int i;
  struct common_header_name *cf = common_headers;

  for(i = ARRAY_SIZE(common_headers); --i >= 0; cf++) {
    cf->value = rb_str_new(cf->name, cf->len);
    cf->value = rb_obj_freeze(cf->value);
    /* This tell Ruby not to GC global variables which refer to Ruby's objects,
    but are not exported to the Ruby world. */
    rb_global_variable(&cf->value);
  }
}

/* this funcion fills the list of short headers taken the data from
 * common_headers array.
 */
static void init_short_headers(void)
{
  TRACE();
  int i, j;
  struct common_header_name *cf = common_headers;

  for(i = ARRAY_SIZE(common_headers), j=0; --i >= 0; cf++) {
    if (cf->short_name != ' ') {
      short_headers[j].abbr = cf->short_name;
      short_headers[j].value = cf->value;
      j++;
    }
  }
}

/* this function is called for every header set */
static VALUE find_common_header_name(const char *name, size_t len)
{
  TRACE();
  int i;
  struct common_header_name *cf = common_headers;

  for(i = ARRAY_SIZE(common_headers); --i >= 0; cf++) {
    if (cf->len == (long)len && !strncasecmp(cf->name, name, len))
      return cf->value;
  }
  return Qnil;
}

/* This function is called for every short header found */
static VALUE find_short_header_name(char abbr)
{
  TRACE();
  int i;
  struct short_header *sh = short_headers;

  for(i = ARRAY_SIZE(short_headers); --i >= 0; sh++) {
    if (sh->abbr == toupper(abbr))
      return sh->value;
  }
  return Qnil;
}


/* Tries to lookup the header name in a list of well-known headers. If so,
 * returns the retrieved VALUE. It also works for short headers.
 * In case the header is unknown, it normalizes it (by capitalizing the
 * first letter and each letter under a "-" or "_" symbol).
 */
static VALUE headerize(const char* hname, size_t hname_len)
{
  TRACE();
  VALUE headerized;
  char* str;
  int i;

  /* Header short name. */
  if (hname_len == 1) {
    headerized = find_short_header_name(hname[0]);
    if (NIL_P(headerized)) {
      headerized = rb_str_new(hname, hname_len);
      /* Downcase the header name. */
      downcase_char(RSTRING_PTR(headerized));
    }
  }

  /* Header long name. */
  else {
    headerized = find_common_header_name(hname, hname_len);
    if (NIL_P(headerized)) {
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
    }
  }

  return(headerized);
}


#endif
