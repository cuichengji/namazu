/*
 * 
 * cgi.c -
 * 
 * $Id: cgi.c,v 1.61.4.25 2013-03-30 13:30:17 opengl2772 Exp $
 * 
 * Copyright (C) 1997-1999 Satoru Takabayashi All rights reserved.
 * Copyright (C) 2000-2008 Namazu Project All rights reserved.
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
#include <ctype.h>
#include <assert.h>

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
#include "usage.h"
#include "message.h"
#include "cgi.h"
#include "output.h"
#include "field.h"
#include "hlist.h"
#include "i18n.h"
#include "idxname.h"
#include "var.h"
#include "util.h"
#include "system.h"

/*
 *
 * Private functions
 *
 */

static int validate_idxname ( const char * idxname );
static void remove_ending_slashes ( char *str );
static struct cgivar * add_cgivar ( struct cgivar *ptr, const char *name, char *value );
static void free_cgi_vars ( struct cgivar *cv );
static char * get_query_string ( void );
static struct cgivar * get_cgi_vars ( const char *qs );
static int process_cgi_vars ( struct cgiarg *ca );
static int apply_cgifunc ( const struct cgivar *cv, struct cgiarg *ca );
static void process_cgi_var_query ( char *value, struct cgiarg *ca );
static void process_cgi_var_subquery ( char *value, struct cgiarg *ca );
static void process_cgi_var_format ( char *value, struct cgiarg *ca );
static void process_cgi_var_sort ( char *value, struct cgiarg *ca );
static void process_cgi_var_max ( char *value, struct cgiarg *ca );
static void process_cgi_var_whence ( char *value, struct cgiarg *ca );
static void process_cgi_var_lang ( char *value, struct cgiarg *ca );
static void process_cgi_var_result ( char *value, struct cgiarg *ca );
static void process_cgi_var_reference ( char *value, struct cgiarg *ca );
static void process_cgi_var_submit ( char *value, struct cgiarg *ca );
static void process_cgi_var_idxname ( char *value, struct cgiarg *ca );

/*
 * Table for cgi vars and corresponding functions. 
 * This table must be under function prototypes.
 */
static struct cgivar_func cgifunctab[] = {
    { "query",     process_cgi_var_query },
    { "key",       process_cgi_var_query },  /* backward comat. */
    { "subquery",  process_cgi_var_subquery },
    { "format",    process_cgi_var_format }, /* backward comat. */
    { "sort",      process_cgi_var_sort },
    { "max",       process_cgi_var_max },
    { "whence",    process_cgi_var_whence },
    { "lang",      process_cgi_var_lang },
    { "result",    process_cgi_var_result },
    { "reference", process_cgi_var_reference },
    { "idxname",   process_cgi_var_idxname },
    { "dbname",    process_cgi_var_idxname },  /* backward comat. */
    { "submit",    process_cgi_var_submit },
    { NULL,        NULL }   /* sentry */
};

/*
 * Validate idxname. (if it contain '/', it's invalid)
 */
static int 
validate_idxname(const char * idxname)
{
    int win32 = 0;
#if  defined(_WIN32) || defined(__EMX__)
    win32 = 1;
#endif

    if (*idxname == '\0' || *idxname == '/' || (win32 && *idxname == '\\')) {
        printf("%s %s; %s" CRLF CRLF, MSG_MIME_HEADER,
            "text/html", _("charset=ISO-8859-1"));
        printf("<html><body>\n");
	puts_entitize(idxname);
	printf(" : ");
        printf(_("Invalid idxname."));
        printf("\n</body></html>\n");
        exit_nmz(EXIT_FAILURE);
    }
    while (*idxname) {
        if (nmz_strprefixcasecmp("../", idxname) == 0 ||
	    strcmp("..", idxname) == 0 ||
            (win32 && nmz_strprefixcasecmp("..\\", idxname) == 0) || 
            (win32 && nmz_strprefixcasecmp("..." , idxname) == 0)) 
        {
            printf("%s %s; %s" CRLF CRLF, MSG_MIME_HEADER,
                "text/html", _("charset=ISO-8859-1"));
            printf("<html><body>\n");
	    puts_entitize(idxname);
	    printf(" : ");
            printf(_("Invalid idxname."));
            printf("\n</body></html>\n");
            exit_nmz(EXIT_FAILURE);
        }
	/* Skip until next '/' */
	while (*idxname && *idxname != '/' && !(win32 && *idxname == '\\')) {
	    idxname++;
	}
	/* Skip '/' */
	if (*idxname) {
	    idxname++;
	}
    }
    return 1;
}

static void 
remove_ending_slashes(char *str)
{
    int win32 = 0;
#if  defined(_WIN32) || defined(__EMX__)
    win32 = 1;
#endif

    str = str + strlen(str) - 1;

    while (*str == '/' || (win32 && *str == '\\')) {
        *str = '\0';
        str--;
    }
}

static struct cgivar *
add_cgivar(struct cgivar *ptr, const char *name, char *value)
{
    struct cgivar *tmp;

    tmp = malloc(sizeof(struct cgivar));
    if (tmp == NULL) {
	 printf("add_cgivar_malloc");
	 return NULL;
    }
    tmp->name = malloc(strlen(name) + 1);
    if (tmp->name == NULL) {
	 printf("add_cgivar_malloc");
         free(tmp);
	 return NULL;
    }

    tmp->value = malloc(strlen(value) + 1);
    if (tmp->value == NULL) {
	 printf("add_cgivar_malloc");
         free(tmp->name);
         free(tmp);
	 return NULL;
    }

    strcpy(tmp->name, name);
    strcpy(tmp->value, value);
    tmp->next = ptr;
    return tmp;
}

static void 
free_cgi_vars(struct cgivar *cv)
{
    if (cv == NULL)
	return;
    free(cv->name);
    free(cv->value);
    free_cgi_vars(cv->next);
    free(cv);
}

static char *
get_query_string(void) 
{
    size_t contlen;
    char *script_name    = "";
    char *query_string   = "";

    if ((query_string = getenv("QUERY_STRING"))) {
        /* 
	 * get QUERY_STRING from environmental variables.
	 */
        contlen = strlen(query_string);
        if (contlen > CGI_QUERY_MAX) {
	    die("%s", _("Too long QUERY_STRING"));
        }
	script_name = getenv("SCRIPT_NAME");
        if (script_name == NULL) {
            return NULL;
        }
    } else if (!(nmz_strprefixcasecmp(getenv("SERVER_SOFTWARE"), "Microsoft-"))
            || !(nmz_strprefixcasecmp(getenv("SERVER_SOFTWARE"), "AnWeb"))
            || !(nmz_strprefixcasecmp(getenv("SERVER_SOFTWARE"), "Oracle-iPlanet-"))
            || !(nmz_strprefixcasecmp(getenv("SERVER_SOFTWARE"), "iPlanet-"))) {
	query_string = "";
	script_name = getenv("SCRIPT_NAME");
        if (script_name == NULL) {
            return NULL;
        }
    } else {
	/* Must not be reached here. */
	char *server = getenv("SERVER_SOFTWARE");
	if (!server) {
		nmz_warn_printf("unknown SERVER_SOFTWARE : %sn", server);
	}
	assert(0);
    }
    return query_string;
}

static struct cgivar *
get_cgi_vars(const char *querystring)
{
    struct cgivar *cv = NULL; /* SHOULD BE NULL for sentinel! */

    while (1) {
	size_t len;
	const char *tmp;
        char *pSemicolon;
	char name[BUFSIZE];
	char value[BUFSIZE];

        name[BUFSIZE - 1] = '\0';

	tmp = strchr(querystring, '=');
	if (tmp == NULL) {
	    break;
	}
	len = tmp - querystring;
	if (len >= BUFSIZE) {
	    len = BUFSIZE - 1;
	    nmz_warn_printf("%s", "truncating a CGI paramater name.\n");
	}
	strncpy(name, querystring, len);
	*(name + len) = '\0';
	querystring += len;

	querystring++;
	tmp = strchr(querystring, '&');
        pSemicolon = strchr(querystring, ';');
        if (tmp == NULL || (pSemicolon && (tmp > pSemicolon))) {
            tmp = pSemicolon;
        }
        if (tmp == NULL) {
	    tmp = querystring + strlen(querystring);  /* last point: '\0' */
	}
	len = tmp - querystring;
	if (len >= BUFSIZE) {
	    len = BUFSIZE - 1;
	    nmz_warn_printf("%s", "truncating a CGI paramater value.\n");
	}
	strncpy(value, querystring, len);
	*(value + len) = '\0';
	nmz_decode_uri(value);
	querystring += len;

	cv = add_cgivar(cv, name, value);

	if (cv == NULL) {
	    fprintf(stderr, "an error occurred at add_cgivar.\n");
	    exit_nmz(EXIT_FAILURE);
	}

	if (*querystring == '\0') {
	    break;
	}
	querystring++;
    }
    return cv;
}

static int 
process_cgi_vars(struct cgiarg *ca)
{
    char *qs;
    struct cgivar *cv;

    qs = get_query_string();
    if (qs == NULL) {
	return 1; /* NOT CGI */
    }
    cv = get_cgi_vars(qs);

    for (; cv != NULL; cv = cv->next) {
	if (!apply_cgifunc(cv, ca)) {
	    /* Message for httpd's error_log */
	    nmz_warn_printf("unknown cgi var: %s=%s\n", cv->name, cv->value);
	}
    }
    free_cgi_vars(cv);
    return 0;
}

static int 
apply_cgifunc(const struct cgivar *cv, struct cgiarg *ca) 
{
    struct cgivar_func *cf = cgifunctab;

    for (; cf->name != NULL; cf++) {
	if (strcmp(cv->name, cf->name) == 0) {
	    cf->func(cv->value, ca);
	    return 1;  /* applied */
	}
    }
    return 0; /* not applied */
}

static void 
process_cgi_var_query(char *value, struct cgiarg *ca)
{
    if (strlen(value) > QUERY_MAX) {
	die(nmz_strerror(ERR_TOO_LONG_QUERY));
    }
#ifdef MSIE4MACFIX
#define MSIE4MAC "Mozilla/4.0 (compatible; MSIE 4.01; Mac"

    if (nmz_strprefixcasecmp(value, "%1B") == 0) {
	char *agent = getenv("HTTP_USER_AGENT");
	if (agent && nmz_strprefixcasecmp(agent, MSIE4MAC) == 0) {
	    nmz_decode_uri(value);
	}
    }
#endif /* MSIE4MACFIX */

    strcpy(ca->query, value);
}

static void 
process_cgi_var_subquery(char *value, struct cgiarg *ca)
{
    if (strlen(value) > QUERY_MAX) {
	die(nmz_strerror(ERR_TOO_LONG_QUERY));
    }
#ifdef MSIE4MACFIX
#define MSIE4MAC "Mozilla/4.0 (compatible; MSIE 4.01; Mac"

    if (nmz_strprefixcasecmp(value, "%1B") == 0) {
	char *agent = getenv("HTTP_USER_AGENT");
	if (agent && nmz_strprefixcasecmp(agent, MSIE4MAC) == 0) {
	    nmz_decode_uri(value);
	}
    }
#endif /* MSIE4MACFIX */

    strcpy(ca->subquery, value);
}

/*
 * This function is for backward compatibility with 1.3.0.x
 */
static void 
process_cgi_var_format(char *value, struct cgiarg *ca)
{
    if (strcmp(value, "short") == 0) {
	set_templatesuffix("short");
    } else if (strcmp(value, "long") == 0) {
	set_templatesuffix("normal");
    }
}

static void 
process_cgi_var_sort(char *value, struct cgiarg *ca)
{
    if (nmz_strprefixcasecmp(value, "score") == 0) {
	nmz_set_sortmethod(SORT_BY_SCORE);
	nmz_set_sortorder(DESCENDING);
    } if (nmz_strprefixcasecmp(value, "later") == 0) {  /* backward compat. */
	nmz_set_sortmethod(SORT_BY_DATE);
	nmz_set_sortorder(DESCENDING);
    } if (nmz_strprefixcasecmp(value, "earlier") == 0) { /* backward compat. */
	nmz_set_sortmethod(SORT_BY_DATE);
	nmz_set_sortorder(ASCENDING);
    } else if (nmz_strprefixcasecmp(value, "date:late") == 0) {
	nmz_set_sortmethod(SORT_BY_DATE);
	nmz_set_sortorder(DESCENDING);
    } else if (nmz_strprefixcasecmp(value, "date:early") == 0) {
	nmz_set_sortmethod(SORT_BY_DATE);
	nmz_set_sortorder(ASCENDING);
    } else if (nmz_strprefixcasecmp(value, "field:") == 0) {
	size_t n;
	char field[BUFSIZE];

	value += strlen("field:");
	n = strspn(value, FIELD_SAFE_CHARS);
	strncpy(field, value, n);
	field[n] = '\0';  /* Hey, don't forget this after strncpy()! */
	nmz_set_sortfield(field);

	value += n;
	nmz_set_sortmethod(SORT_BY_FIELD);
	if (nmz_strprefixcasecmp(value, ":ascending") == 0) {
	    nmz_set_sortorder(ASCENDING);
	    value += strlen(":ascending");
	} else if (nmz_strprefixcasecmp(value, ":descending") == 0) {
	    nmz_set_sortorder(DESCENDING);
	    value += strlen(":descending");
	}
    } 
}

static void 
process_cgi_var_max(char *value, struct cgiarg *ca)
{
    int max;

    if (sscanf(value, "%d", &max) != 1) {
        return;
    }

    if (max < 0)
	max = 0;
    if (max > RESULT_MAX)
	max = RESULT_MAX;

    set_maxresult(max);
}

static void 
process_cgi_var_whence(char *value, struct cgiarg *ca)
{
    int whence;

    if (sscanf(value, "%d", &whence) != 1) {
        return;
    }

    if (whence < 0) {
	whence = 0;
    }
    set_listwhence(whence);
}

static void 
process_cgi_var_lang(char *value, struct cgiarg *ca)
{
    nmz_set_lang(value);
}

static void 
process_cgi_var_result(char *value, struct cgiarg *ca)
{
    set_templatesuffix(value);
}

static void 
process_cgi_var_reference(char *value, struct cgiarg *ca)
{
    if (strcmp(value, "off") == 0) {
	set_refprint(0);
    }
    
}

static void 
process_cgi_var_submit(char *value, struct cgiarg *ca)
{
    /* Do nothing; */
}

static void 
process_cgi_var_idxname(char *value, struct cgiarg *ca)
{
    char *pp;

    for (pp = value; *pp ;) {
	char name[BUFSIZE] = "", tmp[BUFSIZE] = "", *x;

	if ((x = (char *)strchr(pp, (int)','))) {
	    *x = '\0';
	    strncpy(name, pp, BUFSIZE);
	    name[BUFSIZE - 1] = '\0';
	    pp = x + 1;
	} else {
	    strncpy(name, pp, BUFSIZE);
	    name[BUFSIZE - 1] = '\0';
	    pp += strlen(pp);
	}
	validate_idxname(name);
	remove_ending_slashes(name);

	strncpy(tmp, nmz_get_defaultidx(), BUFSIZE - 1);
	strncat(tmp, "/", BUFSIZE - strlen(tmp) - 1);
	strncat(tmp, name, BUFSIZE - strlen(tmp) - 1);
	tmp[BUFSIZE - 1] = '\0';
	if (nmz_add_index(tmp) != SUCCESS) {
	    nmz_warn_printf("invalid idxname: %s", name);
	}
    }
}

/*
 *
 * Public functions
 *
 */

/* initialize CGI mode. actually, to be invoked from commandline
 * with no arguments also trhough this function */
void 
init_cgi(char *query, char *subquery)
{
    struct cgiarg ca;  /* passed for process_cgi_var_*() functions 
		   for modifying important variables. */

    ca.query    = query;
    ca.subquery = subquery;

    if (process_cgi_vars(&ca)) {
	show_mini_usage();   /* if it is NOT CGI, show usage and exit */
	exit_nmz(EXIT_FAILURE);
    }

    if (nmz_get_idxnum() == 0) {
	/* Use defaultidx for taget. */
	if (nmz_add_index(nmz_get_defaultidx()) != SUCCESS) {
	    nmz_warn_printf("invalid idxname: %s", nmz_get_defaultidx());
	}
    } 
}
