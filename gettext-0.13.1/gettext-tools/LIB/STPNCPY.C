/* Copyright (C) 1993, 1995-1997, 2002 Free Software Foundation, Inc.

   NOTE: The canonical source of this file is maintained with the GNU C Library.
   Bugs can be reported to bug-glibc@gnu.org.

   This program is free software; you can redistribute it and/or modify it
   under the terms of the GNU General Public License as published by the
   Free Software Foundation; either version 2, or (at your option) any
   later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307,
   USA.  */

/* This is almost copied from strncpy.c, written by Torbjorn Granlund.  */

#ifdef HAVE_CONFIG_H
# include <config.h>
#endif

/* Specification.  */
#include "stpncpy.h"

#ifndef __GNU_LIBRARY__

#ifdef _LIBC
# include <string.h>
#else
# include <sys/types.h>
/* We cannot generally use the name 'stpncpy' since AIX 4 defines an unusable
   variant of the function but we cannot use it.  */
# undef stpncpy
# define stpncpy gnu_stpncpy
#endif

#ifndef weak_alias
# define __stpncpy stpncpy
#endif

/* Copy no more than N characters of SRC to DEST, returning the address of
   the terminating '\0' in DEST, if any, or else DEST + N.  */
char *
__stpncpy (char *dest, const char *src, size_t n)
{
  char c;
  char *s = dest;

  if (n >= 4)
    {
      size_t n4 = n >> 2;

      for (;;)
	{
	  c = *src++;
	  *dest++ = c;
	  if (c == '\0')
	    break;
	  c = *src++;
	  *dest++ = c;
	  if (c == '\0')
	    break;
	  c = *src++;
	  *dest++ = c;
	  if (c == '\0')
	    break;
	  c = *src++;
	  *dest++ = c;
	  if (c == '\0')
	    break;
	  if (--n4 == 0)
	    goto last_chars;
	}
      n -= dest - s;
      goto zero_fill;
    }

 last_chars:
  n &= 3;
  if (n == 0)
    return dest;

  for (;;)
    {
      c = *src++;
      --n;
      *dest++ = c;
      if (c == '\0')
	break;
      if (n == 0)
	return dest;
    }

 zero_fill:
  while (n-- > 0)
    dest[n] = '\0';

  return dest - 1;
}
#ifdef weak_alias
weak_alias (__stpncpy, stpncpy)
#endif

#endif
