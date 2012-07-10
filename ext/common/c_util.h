/*
 * Generic C functions and macros go here, there are no dependencies
 * on OverSIP internal structures or the Ruby C API in here.
 */

#ifndef c_util_h
#define c_util_h


#define ARRAY_SIZE(x) (sizeof(x)/sizeof(x[0]))


/*
 * str_to_int: Given a pointer to char and length returns an int (but just possitive).
 */
static int str_to_int(const char* str, size_t len)
{
  TRACE();
  int number = 0;
  const char *s = str;

  while (len--) {
    /* Ignore zeroes at the beginning. */
    if (number || *s != '0')
      number = number*10 + (*s)-'0';
    s++;
  }
  return number;
}


/*
 * strnchr: Find the first character in a length limited string.
 * @s: The string to be searched
 * @len: The number of characters to be searched
 * @c: The character to search for
 */
static char *strnchr(const char *s, size_t len, size_t c)
{
  TRACE();
  for (; len--; ++s)
    if (*s == (char)c)
      return (char *)s;
    return NULL;
}


/*
 * str_find_upcase: Returns non zero if the string (*str, len) contains at least
 * an upcase letter.
 */
static char *str_find_upcase(const char *s, size_t len)
{
  TRACE();
  for (; len--; ++s)
    if (*s >= 'A' && *s <= 'Z')
      return (char *)s;
    return NULL;
}


/*
 * capitalizes all lower-case ASCII characters.
 */
static void downcase_char(char *c)
{
  TRACE();
  if (*c >= 'A' && *c <= 'Z')
    *c += 32;
}


#endif

