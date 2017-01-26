/*
 * 
 * namazu.c - search client of Namazu
 *
 * $Id: namazu-cmd.c,v 1.17.4.17 2010-12-18 19:45:07 opengl2772 Exp $
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
#ifdef HAVE_SUPPORT_H
#  include "support.h"
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

#ifdef HAVE_ERRNO_H
#  include <errno.h>
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
#include "getopt.h"
#include "util.h"
#include "codeconv.h"
#include "usage.h"
#include "rcfile.h"
#include "output.h"
#include "search.h"
#include "hlist.h"
#include "idxname.h"
#include "i18n.h"
#include "message.h"
#include "var.h"
#include "result.h"
#include "system.h"
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

static int ck_atoi ( char const *str, int *out );
static void stdio2file ( const char * fname );
static int parse_options ( int argc, char **argv );

/*
 * Imported from GNU grep-2.3 [1999-11-08] by satoru-t
 */
/* Convert STR to a positive integer, storing the result in *OUT.
   If STR is not a valid integer, return -1 (otherwise 0). */
static int
ck_atoi (char const *str, int *out)
{
    char const *p;
    for (p = str; *p; p++)
	if (*p < '0' || *p > '9')
	    return -1;

    *out = atoi (nmz_optarg);
    return 0;
}

/*
 * Redirect stdio to specified file
 */
static void
stdio2file(const char * fname)
{
/*
 *   Old bad routine.
 *
 *   int fd;
 *   if (-1 == (fd = open(fname, O_CREAT | O_TRUNC | O_WRONLY, 00600))) {
 *	die("%s", strerror(errno));
 *	return 1;
 *    }
 *    close(STDOUT);
 *    dup(fd);
 *    close(STDERR);
 *    dup(fd);
 *    close(fd);
 */
    if (freopen(fname, "wb", stdout) == NULL) {
	die("%s", strerror(errno));
    }
}

/*
 * Command line options.
 */
static const char *short_options = "01:234:5acCedf:FhHlL:n:o:qrRsSUvw:";
static struct option long_options[] = {
    { "norc",             no_argument,       NULL, 1 },
    { "help",             no_argument,       NULL, '0' },
    { "result",           required_argument, NULL, '1' },
    { "late",             no_argument,       NULL, '2' },
    { "early",            no_argument,       NULL, '3' },
    { "sort",             required_argument, NULL, '4' },
    { "ascending",        no_argument,       NULL, '5' },
    { "all",              no_argument,       NULL, 'a' },
    { "count",            no_argument,       NULL, 'c' },
    { "show-config",      no_argument,       NULL, 'C' },
    { "debug",            no_argument,       NULL, 'd' },
    { "config",           required_argument, NULL, 'f' },
    { "form",             no_argument,       NULL, 'F' },
    { "html",             no_argument,       NULL, 'h' },
    { "page",             no_argument,       NULL, 'H' },
    { "list",             no_argument,       NULL, 'l' },
    { "lang",             required_argument, NULL, 'L' },
    { "max",              required_argument, NULL, 'n' },
    { "output",           required_argument, NULL, 'o' },
    { "quiet",            no_argument,       NULL, 'q' },
    { "no-references",    no_argument,       NULL, 'r' },
    { "no-replace",       no_argument,       NULL, 'R' },
    { "short",            no_argument,       NULL, 's' },
    { "no-decode-uri",    no_argument,       NULL, 'U' },
    { "version",          no_argument,       NULL, 'v' },
    { "whence",           required_argument, NULL, 'w' },
    { NULL, 0, NULL, 0 }
};

/*
 * Parse command line options
 */
static int 
parse_options(int argc, char **argv)
{
    int tmp;
    int opt_show_config = 0;

    for (;;) {
        int ch = nmz_getopt_long(argc, argv, short_options, long_options, NULL);
        if (ch == -1) {
            break;
	}
	switch (ch) {
        case 1:
            set_namazunorc("all");
            break;
	case '0':
	    show_usage();
	    exit_nmz(EXIT_SUCCESS);
	    break;
	case '1':  /* --result */
            if (nmz_optarg == NULL) {
                die("%s: invalid argument for -1 --result", nmz_optarg);
            }
	    set_templatesuffix(nmz_optarg);
	    break;
	case '2':
	    nmz_set_sortmethod(SORT_BY_DATE);
	    nmz_set_sortorder(DESCENDING);
	    break;	  
	case '3':	  
	    nmz_set_sortmethod(SORT_BY_DATE);
	    nmz_set_sortorder(ASCENDING);
	    break;
	case '4':  /* --sort */
	{
            if (nmz_optarg == NULL) {
                die("%s: invalid argument for -4 --sort", nmz_optarg);
            }
	    if (strcasecmp(nmz_optarg, "score") == 0) {
                nmz_set_sortmethod(SORT_BY_SCORE);
	    } else if (strcasecmp(nmz_optarg, "date") == 0) {
                nmz_set_sortmethod(SORT_BY_DATE);
	    } else if (nmz_strprefixcasecmp(nmz_optarg, "field:") == 0) {
                nmz_set_sortmethod(SORT_BY_FIELD);
                nmz_set_sortfield(nmz_optarg + strlen("field:"));
            } else {
                die("%s: invalid argument for -4 --sort", nmz_optarg);
            }
	}
	break;
	case '5':  /* --ascending */
	    nmz_set_sortorder(ASCENDING);
	    break;
	case 'f':  /* --config */
            if (nmz_optarg == NULL) {
                die("%s: invalid argument for -f --config", nmz_optarg);
            }
	    set_namazurc(nmz_optarg);
	    break;
	case 'n':
	    if (ck_atoi(nmz_optarg, &tmp)) {
		die("%s: invalid argument for -n, --max", nmz_optarg);
	    }
	    set_maxresult(tmp);
	    break;
	case 'w':
	    if (ck_atoi(nmz_optarg, &tmp)) {
		die("%s: invalid argument for -w, --whence", nmz_optarg);
	    }
	    set_listwhence(tmp);
	    break;
	case 'd':
	    nmz_set_debugmode(1);
	    break;
	case 's':
	    set_templatesuffix("short");
	    break;
	case 'l':
	case 'S':  /* 'S' for backward compatibility */
	    set_listmode(1);
	    break;
	case 'q':
	    set_quietmode(1);
	    break;
	case 'c':
	    set_countmode(1);
	    break;
	case 'h':
	    set_htmlmode(1);
	    set_uridecode(0);  /* Do no decode URI in results. */
	    break;
	case 'H':
	    set_pageindex(1);
	    break;
	case 'F':
	    set_formprint(1);
	    break;
	case 'a':
	    set_allresult(1);
	    break;
	case 'R':
	    set_urireplace(0);
	    break;
	case 'r':
	    set_refprint(0);
	    break;
	case 'U':
	    set_uridecode(0); /* Do not deocode URI in results. */
	    break;
	case 'v':
	    show_version();
	    exit_nmz(EXIT_SUCCESS);
	    break;
	case 'C':
	    opt_show_config = 1;
	    break;
	case 'o':  /* --output */
            if (nmz_optarg == NULL) {
                die("%s: invalid argument for -o --output", nmz_optarg);
            }
	    stdio2file(nmz_optarg);
	    break;
	}
    } 
    if (opt_show_config) {
	if (load_rcfiles() != SUCCESS) {
	    die(nmz_get_dyingmsg());
	}
	show_config();
	exit_nmz(EXIT_SUCCESS);
    }

    return nmz_optind;
}

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

    if (getenv("QUERY_STRING") && getenv("SCRIPT_NAME")) {
	/* 
	 * If invoked as CGI, print a help message and exit.
	 *
	 * NOTE: Since "namazu" command and "namazu.cgi" had
	 * been same until 1.9.13, there might be a lot of
	 * people trying to use "namazu" command as CGI. But
	 * since 1.9.14, they are different and we cannot
	 * use "namazu" command as CGI any longer.  
	 */
        printf("%s %s; %s" CRLF CRLF, MSG_MIME_HEADER,
            "text/html", _("charset=ISO-8859-1"));
        printf("<html><body>\n");
	printf("You should use \"namazu.cgi\" instead of \"namazu\" command.");
        printf("\n</body></html>\n");
	exit_nmz(EXIT_FAILURE);
    } else if (argc == 1) {
	show_mini_usage();
	exit_nmz(EXIT_FAILURE);
    } else {
        int i = 0;

	set_refprint(1);

	i = parse_options(argc, argv); 
	if (i == argc) {
	    show_mini_usage();
	    exit_nmz(EXIT_FAILURE);
	}

	if (strlen(argv[i]) > QUERY_MAX) {
	    die(nmz_strerror(ERR_TOO_LONG_QUERY));
	}

        strncpy(query, argv[i++], BUFSIZE - 1);
        if (i < argc) {
	    int curidx = nmz_get_idxnum();
            for (curidx = 0; i < argc && curidx < INDEX_MAX; i++) {
	        if (nmz_add_index(argv[i]) != SUCCESS) {
		    die("invalid idxname: %s", argv[i]);
		}
            }
        } 
    }

    if (load_rcfiles() != SUCCESS) {
	die(nmz_get_dyingmsg());
    }

    /* 
     * If no index is explicitly specified, search the default index.
     * NOTE: This processing must be place after load_rcfiles().
     *       Because default index can be set in namazurc.
     */
    if (nmz_get_idxnum() == 0) {
	/* Use defaultidx for the taget index. */
	if (nmz_add_index(nmz_get_defaultidx()) != SUCCESS) {
	    die("invalid idxname: %s", nmz_get_defaultidx());
	}
    }

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
