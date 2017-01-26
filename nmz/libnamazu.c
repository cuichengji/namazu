/*
 * 
 * libnamazu.c - Namazu library api
 *
 * $Id: libnamazu.c,v 1.35.8.12 2010-12-18 19:45:07 opengl2772 Exp $
 * 
 * Copyright (C) 1997-1999 Satoru Takabayashi All rights reserved.
 * Copyright (C) 2000-2010 Namazu Project All rights reserved.
 * Copyright (C) 1999 NOKUBI Takatsugu All rights reserved.
 * This is free software with ABSOLUTELY NO WARRANTY.
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
 * 02111-1307, USA
 * 
 * 
 */

#ifdef HAVE_CONFIG_H
#  include "config.h"
#endif
#ifdef HAVE_SUPPORT_H
#  include "support.h"
#endif

#include <stdio.h>
#ifdef HAVE_STDLIB_H
#  include <stdlib.h>
#endif

#include <sys/types.h>
#include <fcntl.h>
#include <ctype.h>

#ifdef HAVE_SYS_STAT_H
#	include <sys/stat.h>
#endif

#include <signal.h>
#include <stdarg.h>

#ifdef HAVE_UNISTD_H
#include <unistd.h>
#else
# ifdef _WIN32
# include <io.h>
# endif
#endif

#ifdef HAVE_STRING_H
#  include <string.h>
#else
#  include <strings.h>
#endif

#include "libnamazu.h"
#include "util.h"
#include "codeconv.h"
#include "search.h"
#include "hlist.h"
#include "field.h"
#include "i18n.h"
#include "regex.h"
#include "var.h"
#include "alias.h"
#include "replace.h"
#include "idxname.h"

static enum nmz_sortmethod  sortmethod  = SORT_BY_SCORE;
static enum nmz_sortorder   sortorder   = DESCENDING;
static int  maxhit      = 10000;  /* Ignore if pages matched more than this. */
static int  maxmatch    = 1000;   /* Ignore if words matched more than this. */
static int  debugmode   = 0;
static int  loggingmode = 1;   /* do logging with NMZ.slog */
static int  regex_searchmode = 1; /* enable regex search */
static char dyingmsg[BUFSIZE] = "";
static int  output_warn_to_file = 0; /* output warning to file or stderr */


/*
 *
 * Public functions
 *
 */


/*
 * Free all internal data.
 */ 
void
nmz_free_internal(void)
{
    nmz_free_idxnames();
    nmz_free_aliases();
    nmz_free_replaces();
    nmz_free_field_cache();
}

void 
nmz_set_sortmethod(enum nmz_sortmethod method)
{
    sortmethod = method;
}

enum nmz_sortmethod 
nmz_get_sortmethod(void)
{
    return sortmethod;
}

void 
nmz_set_sortorder(enum nmz_sortorder order)
{
    sortorder = order;
}

enum nmz_sortorder 
nmz_get_sortorder(void)
{
    return sortorder;
}

void
nmz_set_maxhit(int max)
{
    maxhit = max;
}

int
nmz_get_maxhit(void)
{
    return maxhit;
}

void
nmz_set_maxmatch(int max)
{
    maxmatch = max;
}

int
nmz_get_maxmatch(void)
{
    return maxmatch;
}

void 
nmz_set_debugmode(int mode)
{
    debugmode = mode;
}

int 
nmz_is_debugmode(void)
{
    return debugmode;
}

void 
nmz_set_loggingmode(int mode)
{
    loggingmode = mode;
}

int 
nmz_is_loggingmode(void)
{
    return loggingmode;
}

void
nmz_set_output_warn_to_file(int mode)
{
    output_warn_to_file = mode;
}

int
nmz_is_output_warn_to_file(void)
{
    return output_warn_to_file;
}

void 
nmz_set_regex_searchmode(int mode)
{
    regex_searchmode = mode;
}

int 
nmz_is_regex_searchmode(void)
{
    return regex_searchmode;
}

/*
 * This function is used for formating a string with printf
 * notation and store the string in the static variable
 * `msg'.  and return its pointer. So, thhe string can only
 * be used until the next call to the function.  
 *
 * NOTE: Mainly used with nmz_set_dyingmsg() macro.
 */
char *
nmz_msg(const char *fmt, ...)
{
    static char msg[BUFSIZE] = "";
    va_list args;
    
    va_start(args, fmt);
    vsnprintf(msg, BUFSIZE - 1, fmt, args);
    va_end(args);

    return msg;
}

/*
 * This function is not used directly but used only through
 * nmz_set_dyingmsg() macro. That's for getting __FILE__ and
 * __LINE__ information and including them in the
 * dyingmsg in debug mode. It makes debug easy.  
 */
char *
nmz_set_dyingmsg_sub(const char *fmt, ...)
{
    va_list args;
    
    va_start(args, fmt);
    vsnprintf(dyingmsg, BUFSIZE - 1, fmt, args);
    va_end(args);

    return dyingmsg;
}


char *
nmz_get_dyingmsg(void)
{
    return dyingmsg;
}
