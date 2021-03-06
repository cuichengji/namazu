/* Java CLASSPATH handling.
   Copyright (C) 2001-2003 Free Software Foundation, Inc.
   Written by Bruno Haible <haible@clisp.cons.org>, 2001.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software Foundation,
   Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.  */

#ifdef HAVE_CONFIG_H
# include <config.h>
#endif

/* Specification.  */
#include "classpath.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "xsetenv.h"
#include "xalloc.h"

/* Separator in PATH like lists of pathnames.  */
#if defined _WIN32 || defined __WIN32__ || defined __EMX__ || defined __DJGPP__
  /* Win32, OS/2, DOS */
# define PATH_SEPARATOR ';'
#else
  /* Unix */
# define PATH_SEPARATOR ':' 
#endif

/* Return the new CLASSPATH value.  The given classpaths are prepended to
   the current CLASSPATH value.   If use_minimal_classpath, the current
   CLASSPATH is ignored.  */
char *
new_classpath (const char * const *classpaths, unsigned int classpaths_count,
	       bool use_minimal_classpath)
{
  const char *old_classpath;
  unsigned int length;
  unsigned int i;
  char *result;
  char *p;

  old_classpath = (use_minimal_classpath ? NULL : getenv ("CLASSPATH"));
  if (old_classpath == NULL)
    old_classpath = "";

  length = 0;
  for (i = 0; i < classpaths_count; i++)
    length += strlen (classpaths[i]) + 1;
  length += strlen (old_classpath);
  if (classpaths_count > 0 && old_classpath[0] == '\0')
    length--;

  result = (char *) xmalloc (length + 1);
  p = result;
  for (i = 0; i < classpaths_count; i++)
    {
      memcpy (p, classpaths[i], strlen (classpaths[i]));
      p += strlen (classpaths[i]);
      *p++ = PATH_SEPARATOR;
    }
  if (old_classpath[0] != '\0')
    {
      memcpy (p, old_classpath, strlen (old_classpath));
      p += strlen (old_classpath);
    }
  else
    {
      if (classpaths_count > 0)
	p--;
    }
  *p = '\0';

  return result;
}

/* Set CLASSPATH and returns a safe copy of its old value.  */
char *
set_classpath (const char * const *classpaths, unsigned int classpaths_count,
	       bool use_minimal_classpath, bool verbose)
{
  const char *old_CLASSPATH = getenv ("CLASSPATH");
  char *result = (old_CLASSPATH != NULL ? xstrdup (old_CLASSPATH) : NULL);
  char *new_CLASSPATH =
    new_classpath (classpaths, classpaths_count, use_minimal_classpath);

  if (verbose)
    printf ("CLASSPATH=%s ", new_CLASSPATH);

  xsetenv ("CLASSPATH", new_CLASSPATH, 1);

  free (new_CLASSPATH);

  return result;
}

/* Restore CLASSPATH to its previous value.  */
void
reset_classpath (char *old_classpath)
{
  if (old_classpath != NULL)
    {
      xsetenv ("CLASSPATH", old_classpath, 1);
      free (old_classpath);
    }
  else
    unsetenv ("CLASSPATH");
}
