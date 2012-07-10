#ifndef ext_help_h
#define ext_help_h

/* Uncomment for enabling TRACE() function. */
/*#define DEBUG*/

#ifdef DEBUG
#define TRACE()  fprintf(stderr, "TRACE: %s:%d:%s\n", __FILE__, __LINE__, __FUNCTION__)
#else
#define TRACE() 
#endif

#endif

