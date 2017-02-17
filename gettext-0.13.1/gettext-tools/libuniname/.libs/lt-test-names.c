
/* .libs/lt-test-names.c - temporary wrapper executable for .libs/test-names.exe
   Generated by ltmain.sh - GNU libtool 1.5 (1.1220 2003/04/05 19:32:58)

   The test-names program cannot be directly executed until all the libtool
   libraries that it depends on are installed.
   
   This wrapper executable should never be moved out of the build directory.
   If it is, it will not operate correctly.

   Currently, it simply execs the wrapper *script* "/bin/sh test-names",
   but could eventually absorb all of the scripts functionality and
   exec .libs/test-names.exe directly.
*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <unistd.h>
#include <malloc.h>
#include <stdarg.h>
#include <assert.h>

#if defined(PATH_MAX)
# define LT_PATHMAX PATH_MAX
#elif defined(MAXPATHLEN)
# define LT_PATHMAX MAXPATHLEN
#else
# define LT_PATHMAX 1024
#endif

#ifndef DIR_SEPARATOR
#define DIR_SEPARATOR '/'
#endif

#if defined (_WIN32) || defined (__MSDOS__) || defined (__DJGPP__) || \
  defined (__OS2__)
#define HAVE_DOS_BASED_FILE_SYSTEM
#ifndef DIR_SEPARATOR_2 
#define DIR_SEPARATOR_2 '\\'
#endif
#endif

#ifndef DIR_SEPARATOR_2
# define IS_DIR_SEPARATOR(ch) ((ch) == DIR_SEPARATOR)
#else /* DIR_SEPARATOR_2 */
# define IS_DIR_SEPARATOR(ch) \
        (((ch) == DIR_SEPARATOR) || ((ch) == DIR_SEPARATOR_2))
#endif /* DIR_SEPARATOR_2 */

#define XMALLOC(type, num)      ((type *) xmalloc ((num) * sizeof(type)))
#define XFREE(stale) do { \
  if (stale) { free ((void *) stale); stale = 0; } \
} while (0)

const char *program_name = NULL;

void * xmalloc (size_t num);
char * xstrdup (const char *string);
char * basename (const char *name);
char * fnqualify(const char *path);
char * strendzap(char *str, const char *pat);
void lt_fatal (const char *message, ...);

int
main (int argc, char *argv[])
{
  char **newargz;
  int i;
  
  program_name = (char *) xstrdup ((char *) basename (argv[0]));
  newargz = XMALLOC(char *, argc+2);
  newargz[0] = "/bin/sh";
  newargz[1] = fnqualify(argv[0]);
  /* we know the script has the same name, without the .exe */
  /* so make sure newargz[1] doesn't end in .exe */
  strendzap(newargz[1],".exe"); 
  for (i = 1; i < argc; i++)
    newargz[i+1] = xstrdup(argv[i]);
  newargz[argc+1] = NULL;
  execv("/bin/sh",newargz);
  return 127;
}

void *
xmalloc (size_t num)
{
  void * p = (void *) malloc (num);
  if (!p)
    lt_fatal ("Memory exhausted");

  return p;
}

char * 
xstrdup (const char *string)
{
  return string ? strcpy ((char *) xmalloc (strlen (string) + 1), string) : NULL
;
}

char *
basename (const char *name)
{
  const char *base;

#if defined (HAVE_DOS_BASED_FILE_SYSTEM)
  /* Skip over the disk name in MSDOS pathnames. */
  if (isalpha (name[0]) && name[1] == ':') 
    name += 2;
#endif

  for (base = name; *name; name++)
    if (IS_DIR_SEPARATOR (*name))
      base = name + 1;
  return (char *) base;
}

char * 
fnqualify(const char *path)
{
  size_t size;
  char *p;
  char tmp[LT_PATHMAX + 1];

  assert(path != NULL);

  /* Is it qualified already? */
#if defined (HAVE_DOS_BASED_FILE_SYSTEM)
  if (isalpha (path[0]) && path[1] == ':')
    return xstrdup (path);
#endif
  if (IS_DIR_SEPARATOR (path[0]))
    return xstrdup (path);

  /* prepend the current directory */
  /* doesn't handle '~' */
  if (getcwd (tmp, LT_PATHMAX) == NULL)
    lt_fatal ("getcwd failed");
  size = strlen(tmp) + 1 + strlen(path) + 1; /* +2 for '/' and '\0' */
  p = XMALLOC(char, size);
  sprintf(p, "%s%c%s", tmp, DIR_SEPARATOR, path);
  return p;
}

char *
strendzap(char *str, const char *pat) 
{
  size_t len, patlen;

  assert(str != NULL);
  assert(pat != NULL);

  len = strlen(str);
  patlen = strlen(pat);

  if (patlen <= len)
  {
    str += len - patlen;
    if (strcmp(str, pat) == 0)
      *str = '\0';
  }
  return str;
}

static void
lt_error_core (int exit_status, const char * mode, 
          const char * message, va_list ap)
{
  fprintf (stderr, "%s: %s: ", program_name, mode);
  vfprintf (stderr, message, ap);
  fprintf (stderr, ".\n");

  if (exit_status >= 0)
    exit (exit_status);
}

void
lt_fatal (const char *message, ...)
{
  va_list ap;
  va_start (ap, message);
  lt_error_core (EXIT_FAILURE, "FATAL", message, ap);
  va_end (ap);
}
