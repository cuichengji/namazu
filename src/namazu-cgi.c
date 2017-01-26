/*
 * 
 * namazu-cgi.c - search client of Namazu
 *
 * $Id: namazu-cgi.c,v 1.16.8.16 2010-12-18 19:45:07 opengl2772 Exp $
 * 
 * Copyright (C) 1997-1999 Satoru Takabayashi All rights reserved.
 * Copyright (C) 2000-2010 Namazu Project All rights reserved.
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

#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <fcntl.h>
#include <ctype.h>

#ifdef HAVE_SYS_STAT_H
#	include <sys/stat.h>
#endif

#include <signal.h>
#include <stdarg.h>

#if defined (_WIN32) && !defined (__CYGWIN__)
/*
 * It's not Unix, really.  See?  Capital letters. 
 */
#include <windows.h>
#define	SIGALRM	14	/* alarm clock */
#endif

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

#include "namazu.h"
#include "libnamazu.h"
#include "util.h"
#include "codeconv.h"
#include "usage.h"
#include "rcfile.h"
#include "output.h"
#include "search.h"
#include "cgi.h"
#include "hlist.h"
#include "idxname.h"
#include "i18n.h"
#include "message.h"
#include "system.h"
#include "result.h"
#include "charset.h"

/*
 * Extern variables.
 */

NMZ_HANDLE handle_charset = (NMZ_HANDLE)0;

/*
 *
 * Private functions
 *
 */

static void suicide ( int signum );
static void combine_pathname( char *dest, const char *command, const char *name );

extern int suicide_time;

static void 
suicide (int signum)
{
    die("processing time exceeds a limit: %d", suicide_time);
}

/*
 * Make the pathname `dest' by conjuncting `command' and `name'.
 */
static void 
combine_pathname(char *dest, const char *command, const char *name)
{
    int i;

    int win32 = 0;
#if  defined(_WIN32) || defined(__EMX__)
    win32 = 1;
#endif

    strcpy(dest, command);
    for (i = (int)strlen(dest) - 1; i >= 0; i--) {
	if (dest[i] == '/' || (win32 && dest[i] == '\\')) {
	    break;
	}
    }
    i++;
    strcpy(dest + i, name);
    return;
}

/*
 *
 * Public functions
 *
 */

int 
main(int argc, char **argv)
{
    char query[BUFSIZE] = "", subquery[BUFSIZE] = "";
    char *localedir = getenv("NAMAZULOCALEDIR");

    /*
     *
     * create resource.
     *
     */
    handle_charset = create_charset_list();

    /*
     * To support a binary package for Windows, we should
     * allow to change LOCALEDIR with the environment
     * variable `NAMAZULOCALEDIR' after installation is
     * done.
     */
    if (localedir != NULL) {
	bindtextdomain(PACKAGE, localedir);
    } else {
	bindtextdomain(PACKAGE, LOCALEDIR);
    }
    textdomain(PACKAGE);

    nmz_set_lang("");

    /* Both environment variables are required. */
    if (!((getenv("QUERY_STRING") || getenv("SERVER_SOFTWARE"))
     && getenv("SCRIPT_NAME"))) {
	show_version();
	puts("");
	die("environment variable QUERY_STRING and SCRIPT_NAME are required");
    }

#if !defined (_WIN32) || defined (__CYGWIN__)
    /* 
     * Set a suicide timer for safety.
     * namazu.cgi will suicide automatically when SUICIDE_TIME reached.
     */
    signal(SIGALRM, suicide);
    alarm(suicide_time);
#endif

    /*
     * Setting up CGI mode.
     */
    set_cgimode(1);
    set_refprint(1);
    set_htmlmode(1);
    set_pageindex(1);	 /* Print page index */
    set_formprint(1);	 /* Print "<form> ... </form>"  */
    set_uridecode(0);        /* Do not decode URI in results. */

    {
	/*
	 * Load .namazurc located in the directory
	 * where namazu.cgi command is if it exists.
	 */
	char fname[BUFSIZE];
	combine_pathname(fname, argv[0], ".namazurc");
	if (nmz_is_file_exists(fname)) {
	    set_namazurc(fname);
	}
    }

    if (load_rcfiles() != SUCCESS) {
	die(nmz_get_dyingmsg());
    }

#if !defined (_WIN32) || defined (__CYGWIN__)
    alarm(suicide_time);
#endif
    nmz_set_output_warn_to_file(1);

    /*
     * NOTE: This processing must be place after load_rcfiles().
     *       Because the default index can be set in namazurc.
     */
    init_cgi(query, subquery);

    if (namazu_core(query, subquery) == ERR_FATAL) {
        die(nmz_get_dyingmsg());
    }

    /*
     *
     * free resource.
     *
     */
    nmz_free_handle(handle_charset);

    return EXIT_SUCCESS;
}
