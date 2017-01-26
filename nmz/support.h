#ifndef _SUPPORT_H
#define _SUPPORT_H

#ifdef HAVE_CONFIG_H
# include <config.h>
#endif

#include <stdio.h>
#ifdef HAVE_STDLIB_H
#  include <stdlib.h>
#endif
#ifdef HAVE_STRING_H
#  include <string.h>
#else
#  include <strings.h>
#endif

/* symbol mangling for libnmz.  */

#ifndef HAVE_MEMMOVE
#define memmove _nmz_memmove
#endif

#ifndef HAVE_MEMSET
#define memset _nmz_memset
#endif

#ifndef HAVE_STRCSPN
#define strcspn _nmz_strcspn
#endif

#ifndef HAVE_STRERROR
#define strerror _nmz_strerror
#endif

#if defined (_WIN32) && !defined (__CYGWIN__)
# define strcasecmp _stricmp
# define strncasecmp _strnicmp
# define snprintf _snprintf
# define vsnprintf _vsnprintf
# define strdup _strdup
# define putenv _putenv
#else
# ifndef HAVE_STRCASECMP
#  define strcasecmp _nmz_strcasecmp
# endif
# ifndef HAVE_STRNCASECMP
#  define strncasecmp _nmz_strncasecmp
# endif
# ifndef HAVE_VSNPRINTF
#  define snprintf _nmz_snprintf
#  define vsnprintf _nmz_vsnprintf
# endif 
#endif

#endif /* _SUPPORT_H */
