/*
 * 
 * $Id: rcfile.c,v 1.31.4.20 2009-02-16 17:43:43 opengl2772 Exp $
 * 
 * Copyright (C) 1997-1999 Satoru Takabayashi All rights reserved.
 * Copyright (C) 2000-2009 Namazu Project All rights reserved.
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
 */

#ifdef HAVE_CONFIG_H
#  include "config.h"
#endif
#ifdef HAVE_SUPPORT_H
#  include "support.h"
#endif

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

#ifdef HAVE_ERRNO_H
#  include <errno.h>
#endif

#ifdef HAVE_STRING_H
#  include <string.h>
#else
#  include <strings.h>
#endif

#include "namazu.h"
#include "libnamazu.h"
#include "rcfile.h"
#include "util.h"
#include "regex.h"
#include "re.h"
#include "codeconv.h"
#include "i18n.h"
#include "var.h"
#include "alias.h"
#include "replace.h"
#include "search.h"
#include "idxname.h"
#include "output.h"
#include "score.h"
#include "charset.h"

/*
 * Extern variables.
 */

extern NMZ_HANDLE handle_charset;

/*
 * Default directory to place namazurc.
 */
static char *namazurcdir = OPT_CONFDIR;

/*
 * User specified namazurc. This can be set with set_namazurc().
 */
static char user_namazurc[BUFSIZE] = "";

static char namazunorc[BUFSIZE] = "";

static char *errmsg  = NULL;

/* suicide time (sec) */
int suicide_time = SUICIDE_TIME;

/* 
 * Storing loaded rcfile names for show_config().
 *
 * 3 is the max number of rcfiles may be loaded.
 *
 *  1. $(sysconfdir)/$(PACKAGE)/namazurc
 *     - This can be overriden by environmentl variable NAMAZURC.
 *
 *  2.  ~/.namazurc
 *
 *  3. user-specified namazurc set by namazu --config=file option.
 * 
 */
static struct {
    char fnames[3][BUFSIZE];
    int num;
} loaded_rcfiles = { {"", "", ""}, 0 };

/* Forward declaration. */

typedef struct _StrList StrList;

/* Simple string list. */
struct _StrList {
    char *value;
    StrList *next;
};


/*
 *
 * Private functions
 *
 */

static char *getenv_namazurc ( void );
static size_t get_rc_arg ( const char *line, char *arg );
static void replace_home ( char *str );
static StrList * add_strlist(StrList *list, const char *arg);
static void free_strlist(StrList *list);
static StrList *get_rc_args ( const char *line );
static enum nmz_stat parse_rcfile ( const char *line, int lineno );
static enum nmz_stat apply_rc ( int lineno, const char *directive, StrList *args );
static void add_loaded_rcfile( const char *fname );
static enum nmz_stat load_rcfile( const char *fname );
static enum nmz_stat process_rc_blank ( const char *directive, const StrList *args );
static enum nmz_stat process_rc_comment ( const char *directive, const StrList *args );
static enum nmz_stat process_rc_debug ( const char *directive, const StrList *args );
static enum nmz_stat process_rc_index ( const char *directive, const StrList *args );
static enum nmz_stat process_rc_alias ( const char *directive, const StrList *args );
static enum nmz_stat process_rc_replace ( const char *directive, const StrList *args );
static enum nmz_stat process_rc_logging ( const char *directive, const StrList *args );
static enum nmz_stat process_rc_scoring ( const char *directive, const StrList *args );
static enum nmz_stat process_rc_doclength ( const char *directive, const StrList *args );
static enum nmz_stat process_rc_freshness ( const char *directive, const StrList *args );
static enum nmz_stat process_rc_urilength ( const char *directive, const StrList *args );
static enum nmz_stat process_rc_lang ( const char *directive, const StrList *args );
static enum nmz_stat process_rc_emphasistags ( const char *directive, const StrList *args );
static enum nmz_stat process_rc_template ( const char *directive, const StrList *args );
static enum nmz_stat process_rc_maxhit ( const char *directive, const StrList *args );
static enum nmz_stat process_rc_maxmatch ( const char *directive, const StrList *args );
static enum nmz_stat process_rc_contenttype ( const char *directive, const StrList *args );
static enum nmz_stat process_rc_suicidetime ( const char *directive, const StrList *args );
static enum nmz_stat process_rc_regexsearch ( const char *directive, const StrList *args );
static enum nmz_stat process_rc_charset ( const char *directive, const StrList *args );

struct conf_directive {
    char *name;
    int  argnum;
    int  plus;   /* argnum or more arguments are required. */
    enum nmz_stat (*func)(const char *directive, const StrList *args);
};

static struct conf_directive directive_tab[] = {
    { "BLANK",         0, 0, process_rc_blank },
    { "COMMENT",       0, 0, process_rc_comment },
    { "DEBUG",         1, 0, process_rc_debug },
    { "INDEX",         1, 0, process_rc_index },
    { "ALIAS",         2, 1, process_rc_alias },
    { "REPLACE",       2, 0, process_rc_replace },
    { "LOGGING",       1, 0, process_rc_logging },
    { "SCORING",       1, 0, process_rc_scoring },
    { "SCORE_DOCLENGTH", 1, 0, process_rc_doclength },
    { "SCORE_FRESHNESS", 1, 0, process_rc_freshness },
    { "SCORE_URILENGTH", 1, 0, process_rc_urilength },
    { "LANG",          1, 0, process_rc_lang },
    { "EMPHASISTAGS",  2, 0, process_rc_emphasistags },
    { "TEMPLATE",      1, 0, process_rc_template },
    { "MAXHIT",        1, 0, process_rc_maxhit },
    { "MAXMATCH",      1, 0, process_rc_maxmatch },
    { "CONTENTTYPE",   1, 0, process_rc_contenttype },
    { "SUICIDE_TIME",  1, 0, process_rc_suicidetime },
    { "REGEX_SEARCH",  1, 0, process_rc_regexsearch },
    { "CHARSET",       2, 0, process_rc_charset },
    { NULL,            0, 0, NULL }
};



static enum nmz_stat
process_rc_blank(const char *directive, const StrList *args)
{
    /* Do nothing */
    return SUCCESS;
}

static enum nmz_stat
process_rc_comment(const char *directive, const StrList *args)
{
    /* Do nothing */
    return SUCCESS;
}

static enum nmz_stat
process_rc_debug(const char *directive, const StrList *args)
{
    char *arg1 = args->value;

    if (strcasecmp(arg1, "ON") == 0) {
        nmz_set_debugmode(1);
    } else if (strcasecmp(arg1, "OFF") == 0) {
        nmz_set_debugmode(0);
    }
    return SUCCESS;
}

static enum nmz_stat
process_rc_index(const char *directive, const StrList *args)
{
    char *arg1 = args->value;

    nmz_set_defaultidx(arg1);
    return SUCCESS;
}

/*
 * FIXME: one-to-multiple alias should be allowed.
 */
static enum nmz_stat
process_rc_alias(const char *directive, const StrList *args)
{
    char *arg1 = args->value;
    char *arg2 = args->next->value;

    if (nmz_add_alias(arg1, arg2) != SUCCESS) {
        return FAILURE;
    }
    return SUCCESS;
}

static enum nmz_stat
process_rc_replace(const char *directive, const StrList *args)
{
    char *arg1 = args->value;
    char *arg2 = args->next->value;

    if (nmz_add_replace(arg1, arg2) != SUCCESS) {
        return FAILURE;
    }
    return SUCCESS;
}

static enum nmz_stat
process_rc_logging(const char *directive, const StrList *args)
{
    char *arg1 = args->value;

    if (strcasecmp(arg1, "ON") == 0) {
        nmz_set_loggingmode(1);
    } else if (strcasecmp(arg1, "OFF") == 0) {
        nmz_set_loggingmode(0);
    }

    return SUCCESS;
}

static enum nmz_stat
process_rc_scoring(const char *directive, const StrList *args)
{
    char *arg1 = args->value;

    nmz_set_scoring(arg1);
    return SUCCESS;
}

static enum nmz_stat
process_rc_doclength(const char *directive, const StrList *args)
{
    char *arg1 = args->value;

    nmz_set_doclength(arg1);
    return SUCCESS;
}

static enum nmz_stat
process_rc_freshness(const char *directive, const StrList *args)
{
    char *arg1 = args->value;

    nmz_set_freshness(arg1);
    return SUCCESS;
}

static enum nmz_stat
process_rc_urilength(const char *directive, const StrList *args)
{
    char *arg1 = args->value;

    nmz_set_urilength(arg1);
    return SUCCESS;
}

static enum nmz_stat
process_rc_lang(const char *directive, const StrList *args)
{
    char *arg1 = args->value;

    /*
     * It works if environment variable LANG is not set.
     */
    if (getenv("LANG") == NULL) {
        nmz_set_lang(arg1);
    }
    return SUCCESS;
}

static enum nmz_stat
process_rc_emphasistags(const char *directive, const StrList *args)
{
    char *arg1 = args->value;
    char *arg2 = args->next->value;

    set_emphasis_tags(arg1, arg2); /* order: start, end */
    return SUCCESS;
}

static enum nmz_stat
process_rc_template(const char *directive, const StrList *args)
{
    char *arg1 = args->value;

    set_templatedir(arg1);
    return SUCCESS;
}

static enum nmz_stat
process_rc_maxhit(const char *directive, const StrList *args)
{
    int arg1 = atoi(args->value);

    nmz_set_maxhit(arg1);
    return SUCCESS;
}

static enum nmz_stat
process_rc_maxmatch(const char *directive, const StrList *args)
{
    int arg1 = atoi(args->value);

    nmz_set_maxmatch(arg1);
    return SUCCESS;
}

static enum nmz_stat
process_rc_contenttype(const char *directive, const StrList *args)
{
    char *arg1 = args->value;

    set_contenttype(arg1);

    return SUCCESS;
}

static enum nmz_stat
process_rc_suicidetime(const char *directive, const StrList *args)
{
    int arg1 = atoi(args->value);

    suicide_time = arg1;
    return SUCCESS;
}

static enum nmz_stat
process_rc_regexsearch(const char *directive, const StrList *args)
{
    char *arg1 = args->value;

    if (strcasecmp(arg1, "ON") == 0) {
        nmz_set_regex_searchmode(1);
    } else if (strcasecmp(arg1, "OFF") == 0) {
        nmz_set_regex_searchmode(0);
    }

    return SUCCESS;
}

static enum nmz_stat
process_rc_charset(const char *directive, const StrList *args)
{
    char *arg1 = args->value;
    char *arg2 = args->next->value;

    if (nmz_add_strlist(handle_charset, arg1, arg2) != SUCCESS) {
        return FAILURE;
    }
    return SUCCESS;
}

/* 
 * Get the environment variable of NAMAZURC, NAMAZUCONF or
 * NAMAZUCONFPATH.  and return it. Original of this code is
 * contributed by Kaz SHiMZ <kshimz@sfc.co.jp> [1998-02-27] 
 */
static char *
getenv_namazurc(void)
{
    char *env_namazurc;

    env_namazurc = getenv("NAMAZURC");
    if (env_namazurc != NULL) {
        return env_namazurc;
    }

    /* For backward compatibility. */
    env_namazurc = getenv("NAMAZUCONF");
    if (env_namazurc != NULL) {
        return env_namazurc;
    }

    /* For backward compatibility. */
    env_namazurc = getenv("NAMAZUCONFPATH");
    if (env_namazurc != NULL) {
        return env_namazurc;
    }

    return NULL;
}

static size_t 
get_rc_arg(const char *line, char *arg)
{
    arg[BUFSIZE - 1] = '\0';
    *arg = '\0';
    if (*line != '"') {
        size_t n = strcspn(line, " \t");
        if (n >= BUFSIZE) n = BUFSIZE - 1;
        strncpy(arg, line, n);
        arg[n] = '\0';     /* Hey, don't forget this after strncpy()! */
        return n;
    } else {  /* double quoted argument */
        size_t n;
        line++;
        n = 1;
        do {
            size_t nn = strcspn(line, "\"\\");
            if (nn >= (BUFSIZE - strlen(arg))) nn = BUFSIZE - strlen(arg) - 1;
            strncat(arg, line, nn);
            n += nn;
            line += nn;
            arg[n] = '\0';
            if (n >= BUFSIZE) return n;
            if (*line == '\0') {  /* terminator not matched */
                errmsg = _("can't find string terminator");
                return 0;
            }
            if  (*line == '"') {  /* ending */
                n++;
                return n;
            }
            if (*line == '\\') {  /* escaping character */
                strncat(arg, line + 1, 1);
                n += 2;
                line += 2;
            }
        } while (1);
        return n;
    }
}

static void 
replace_home(char *str)
{
    char tmp[BUFSIZE] = "";

    if (str == NULL || *str == '\0') {
        return;
    }

    strcpy(tmp, str);
    if (nmz_strprefixcmp(tmp, "~/") == 0) {
        char *home;
        /* Checke a home directory */
        if ((home = getenv("HOME")) != NULL) {
            strncpy(tmp, home, BUFSIZE - 1);
            strncat(tmp, "/", BUFSIZE - strlen(tmp) - 1);
            strncat(tmp, str + strlen("~/"), BUFSIZE - strlen(tmp) - 1);
            strncpy(str, tmp, BUFSIZE - 1);
            return;
        }
    }

    return;
}

/*
 * Add a new element to the list and return it.
 */
static StrList * 
add_strlist(StrList *list, const char *arg)
{
    StrList *newp;

    newp = malloc(sizeof(StrList));
    if (newp == NULL) {
        return NULL;
    }

    newp->value = malloc(strlen(arg) + 1);
    if (newp->value == NULL) {
        free(newp);
        return NULL;
    }
    strcpy(newp->value, arg);
    newp->next = NULL;

    if (list == NULL) {
        return newp;
    } else {
        StrList *ptr = list;

        while (ptr->next != NULL) {
            ptr = ptr->next;
        }
        assert(ptr->next == NULL);
        ptr->next = newp;
        return list;
    }
    assert(0);
    /* NOTREACHED */
}

static void 
free_strlist(StrList *list)
{
    StrList *next, *ptr;

    for (ptr = list; ptr != NULL; ptr = next) {
        next = ptr->next;
        free(ptr->value);
        free(ptr);
    }
}


/*
 * Get the directive and the following args and return them as a list.
 *
 * NOTE: the string `line' should be chomped before calling the function.
 */
static StrList *
get_rc_args(const char *line)
{
    StrList *list = NULL;
    size_t n;

    /* Skip white spaces in the beginning of this line */
    n = strspn(line, " \t");    /* skip white spaces */
    line += n;
    /* Determine whether or not this line is only a blank */
    if (*line == '\0') {
        return add_strlist(list, "BLANK");
    }

    /* Determine whether or not this line is only a comment */
    if (*line == '#') {
        return add_strlist(list, "COMMENT");
    }

    /* Get a directive name. */
    {
        char directive[BUFSIZE] = "";
        n = strspn(line, DIRECTIVE_CHARS);
        if (n == 0) {
            errmsg = _("invalid directive name");
            return 0;
        }
        if (n >= BUFSIZE) n = BUFSIZE - 1;
        strncpy(directive, line, n);
        directive[n] = '\0';  /* Hey, don't forget this after strncpy()! */
        list = add_strlist(list, directive);
        line += n;
    }

    /* Skip a delimiter after a directive */
    n = strspn(line, " \t");    /* skip white spaces */
    line += n;
    if (n == 0) {
        errmsg = _("can't find arguments");
        return 0;
    }

    while (1) {
        char arg[BUFSIZE] = "";
        n = get_rc_arg(line, arg);
        if (n == 0) { /* cannot get arg1 */
            return NULL;
        }
        line += n;

        /* Replace ~/ */
        replace_home(arg);

        list = add_strlist(list, arg);

        /* Skip a delimiter after the arg */
        n = strspn(line, " \t");    /* skip white spaces */
        line += n;

        if (*line == '\0' || *line == '#') {  /* allow comment at the ending */
            /* This line has only one argument (arg) */
            break;
        }
    }

    return list;
}

static enum nmz_stat 
parse_rcfile(const char *line, int lineno) 
{
    StrList *d_args; /* directive + arguments */
    StrList *args;
    char *directive;

   /* 
    * d_args are allocated in the func. 
    * So we should free it later.
    */
    d_args = get_rc_args(line); 
    if (d_args == NULL) { 
        return FAILURE; /* error */
    }
    directive = d_args->value; /* the first arg is a directive. */
    args = d_args->next;

    if (apply_rc(lineno, directive, args) != SUCCESS) {
        return FAILURE;
    }

    /* 
     * NOTE: Cannot turn is_debugmode() on with -d option because
     * rcfile is loaded before command line options are parsed.
     * But we can set debugmode by setting "Debug on" in the TOP of 
     * namazurc.
     */
    if (nmz_is_debugmode() &&
        (strcasecmp(directive, "COMMENT") != 0) &&
        (strcasecmp(directive, "BLANK") != 0))
    {
        StrList *ptr;
        int i;

        nmz_debug_printf("%4d: Directive:  [%s]\n", lineno, directive);

        for (ptr = args, i = 1 ; ptr != NULL; i++) {
            nmz_debug_printf("      Argument %d: [%s]\n", i, ptr->value);
            ptr = ptr->next;
        }
    }

    free_strlist(d_args);
    return SUCCESS;
}

static enum nmz_stat 
apply_rc(int lineno, const char *directive, StrList *args)
{
    int argnum = 0;
    StrList *ptr;
    struct conf_directive *dtab = directive_tab;

    for (ptr = args; ptr != NULL; ptr = ptr->next) {
        argnum++;
    }

    for (; dtab->name != NULL;  dtab++) {
        if (strcasecmp(dtab->name, directive) == 0) {
            /* 
             * Check whether the number of argument is right.
             */
            if (argnum == dtab->argnum ||
                (dtab->plus && argnum > dtab->argnum)) 
            {
                /* 
                 * If number of argument is correct, apply
                 * appropriate function and return with its
                 * return value.
                 */
                return dtab->func(directive, args);
            } else if (argnum < dtab->argnum) {
                errmsg = _("too few arguments");
                return FAILURE;
            } else if (argnum > dtab->argnum) {
                errmsg = _("too many arguments");
                return FAILURE;
            } else {
                assert(0);
                /* NOTREACHED */
                return FAILURE;
            }
        }
    }

    errmsg = _("unknown directive");
    return FAILURE;
}

static void 
add_loaded_rcfile(const char *fname) 
{
    int no = loaded_rcfiles.num;

    strcpy(loaded_rcfiles.fnames[no], fname);
    loaded_rcfiles.num++;
}

/* 
 * Load the namazurc specified with fname.
 */
static enum nmz_stat 
load_rcfile(const char *fname)
{
    FILE *fp;
    char buf[BUFSIZE] = "";
    int lineno = 1;

    fp = fopen(fname, "rb");
    if (fp == NULL) { /* open failed */
        nmz_set_dyingmsg(nmz_msg("%s: %s", fname, strerror(errno)));
        return FAILURE;
    }

    while (fgets(buf, BUFSIZE, fp) != NULL) {
        int current_lineno = lineno;

        do {
            lineno++;
            nmz_chomp(buf);
            if (buf[strlen(buf) - 1] == '\\') { /* ending with \ */
                int remaining;

                buf[strlen(buf) - 1] = '\0'; /* Remove ending \ */
                remaining = (int)(BUFSIZE - strlen(buf) - 1);
                if (remaining == 0) {
                    nmz_chomp(buf);
                    break;
                }
                if (fgets(buf + strlen(buf), remaining, fp) == NULL) {
                    nmz_chomp(buf);
                    break;
                }
            } else {
                break;
            }
        } while (1);

        nmz_codeconv_internal(buf);  /* for Shift_JIS encoding */
        if (parse_rcfile(buf, current_lineno) != SUCCESS) {
            nmz_set_dyingmsg(nmz_msg(_("%s:%d: syntax error: %s"),  
				     fname, current_lineno, errmsg));
            fclose(fp);
            return FAILURE;
        }
    }
    fclose(fp);

    add_loaded_rcfile(fname); /* For show_config() */
    nmz_debug_printf("load_rcfile: %s loaded\n", fname);

    return SUCCESS;
}


/*
 *
 * Public functions
 *
 */

void
set_namazurc(const char *arg)
{
    strncpy(user_namazurc, arg, BUFSIZE - 1);
    user_namazurc[BUFSIZE - 1] = '\0';
}

void
set_namazunorc(const char *arg)
{
    strncpy(namazunorc, arg, BUFSIZE - 1);
    namazunorc[BUFSIZE - 1] = '\0';
    nmz_strlower(namazunorc);
}

/*
 * Load namazurcs:
 *
 *  1. $(sysconfdir)/$(PACKAGE)/namazurc
 *     - This can be overriden by environmentl variable NAMAZURC.
 *
 *  2.  ~/.namazurc
 *
 *  3. user-specified namazurc set by namazu --config=file option.
 *
 * If multiple files exists, read all of them.
 */
enum nmz_stat 
load_rcfiles(void)
{
    char *env_norc, _norc[BUFSIZE] = "";

    if ((env_norc = getenv("NAMAZUNORC"))) {
        strncpy(_norc, env_norc, BUFSIZE - 1);
        _norc[BUFSIZE - 1] = '\0';
        nmz_strlower(_norc);

        if (namazunorc[0] == '\0') {
            set_namazunorc(_norc);
        }
    }

    nmz_debug_printf("NAMAZUNORC: '%s'", _norc);
    nmz_debug_printf("namazunorc: '%s'", namazunorc);

    /*
     *  1. $(sysconfdir)/$(PACKAGE)/namazurc
     *     - This can be overriden by environmentl variable NAMAZURC.
     */
    if (strcmp("all", namazunorc) != 0 && strcmp("sysconfig", namazunorc) != 0) {
        char *env = getenv_namazurc();
        if (env != NULL) {
            if (load_rcfile(env) != SUCCESS) {
                return FAILURE;
            }
        } else {
            char fname[BUFSIZE] = "";
            strncpy(fname, namazurcdir, BUFSIZE - 1);
            strncat(fname, "/namazurc",
                BUFSIZE - strlen(fname) - 1);
            /* 
             * Load the file only if it exists.
             */
            if (nmz_is_file_exists(fname)) {
                if (load_rcfile(fname) != SUCCESS) {
                    return FAILURE;
                }
            }
        }
    }

    /*
     *  2. ~/.namazurc
     */
    if (strcmp("all", namazunorc) != 0 && strcmp("home", namazunorc) != 0) {
        char *home = getenv("HOME");
        if (home != NULL) {
            char fname[BUFSIZE] = "";
            strncpy(fname, home, BUFSIZE - 1);
            strncat(fname, "/.namazurc",
                BUFSIZE - strlen(fname) - 1);
            /* 
             * Load the file only if it exists.
             */
            if (nmz_is_file_exists(fname)) {
                if (load_rcfile(fname) != SUCCESS) {
                    return FAILURE;
                }
            }
        }
    }

    /*
     *  3. user-specified namazurc set by namazu --config=file option.
     */
    if (user_namazurc[0] != '\0') {
        if (load_rcfile(user_namazurc) != SUCCESS) {
            return FAILURE;
        }
    }

    return SUCCESS;
}

void 
show_config(void)
{
    int i;

    if (loaded_rcfiles.num >= 1) {
        for (i =0; i < loaded_rcfiles.num; i++) {
            printf(_("Loaded rcfile: %s\n"), loaded_rcfiles.fnames[i]);
        }
        printf("--\n");
    }

    printf(_("\
Index:        %s\n\
Logging:      %s\n\
Lang:         %s\n\
Scoring:      %s\n\
Template:     %s\n\
MaxHit:       %d\n\
MaxMatch:     %d\n\
EmphasisTags: %s\t%s\n\
"), nmz_get_defaultidx(), nmz_is_loggingmode() ? "on" : "off",
           nmz_get_lang(), nmz_is_tfidfmode() ? "tfidf" : "simple",
	   get_templatedir(), 
	   nmz_get_maxhit(), nmz_get_maxmatch(),
	   get_emphasis_tag_start(), get_emphasis_tag_end()
	   );

    /* Show aliases. */
    {
        struct nmz_alias *list = nmz_get_aliases();
        while (list) {
            printf(_("Alias:   %-20s\t%s\n"), 
                list->alias, list->real);
            list = list->next;
        }
    }

    /* Show replaces. */
    {
        struct nmz_replace *list = nmz_get_replaces();
        while (list) {
            printf(_("Replace: %-20s\t%s\n"), 
                list->pat, list->rep);
            list = list->next;
        }
    }

    /*    exit(0);*/
    return;
}

