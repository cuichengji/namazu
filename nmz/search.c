/*
 * 
 * $Id: search.c,v 1.86.4.30 2013-01-15 17:11:04 opengl2772 Exp $
 * 
 * Copyright (C) 1997-1999 Satoru Takabayashi All rights reserved.
 * Copyright (C) 2000-2013 Namazu Project All rights reserved.
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
#include <string.h>
#include <ctype.h>
#include <time.h>
#ifdef __EMX__
#include <sys/types.h>
#endif

#ifdef HAVE_SYS_STAT_H
#	include <sys/stat.h>
#endif

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

#include "libnamazu.h"
#include "util.h"
#include "field.h"
#include "parser.h"
#include "hlist.h"
#include "re.h"
#include "wakati.h"
#include "search.h"
#include "l10n-ja.h"
#include "codeconv.h"
#include "var.h"
#include "seed.h"
#include "idxname.h"
#include "query.h"
#include "score.h"

enum nmz_perm { ALLOW, DENY };
static int cur_idxnum = -1;

/*
 *
 * Private functions
 *
 */

void nmz_free_hitnums ( struct nmz_hitnumlist *hn );
static void show_status ( int l, int r );
static int get_file_size ( const char *fname );
static void lrget ( int *l, int *r );
static NmzResult prefix_match ( const char * key, int v );
static enum nmz_searchmethod detect_search_mode ( const char *key );
static NmzResult do_word_search ( const char *key, NmzResult val );
static NmzResult do_prefix_match_search ( const char *key, NmzResult val );
static int hash ( const char *str );
static NmzResult cmp_phrase_hash ( int hash_key, NmzResult val, FILE *phrase, FILE *phrase_index );
static int open_phrase_index_files ( FILE **phrase, FILE **phrase_index );
static NmzResult do_phrase_search ( const char *key, NmzResult val );
static void do_regex_preprocessing ( char *expr );
static NmzResult do_regex_search ( const char *expr, NmzResult val );
static void get_regex_part ( char *expr, const char *str );
static NmzResult do_field_search ( const char *fieldpat, NmzResult val );
static void delete_beginning_backslash ( char *str );
static int is_locked ( void );
static enum nmz_perm parse_access ( const char *line, const char *rhost, const char *raddr, enum nmz_perm operm );
static enum nmz_perm check_access ( void );
static enum nmz_stat open_index_files ( void );
static void close_index_files ( void );
static void do_logging ( const char * query, int n );
static NmzResult nmz_search_sub ( NmzResult hlist, const char *query, int n );
static void make_fullpathname_index ( int n );
static void remove_quotes( char *str );
static enum nmz_stat normalize_idxnames( void );
static int issymbol ( int c );
static void escape_meta_characters( char *expr, size_t bufsize );
static void nmz_regex_strlower( char *str );

/*
 * Show the status for debug use
 */
static void 
show_status(int l, int r)
{
    char buf[BUFSIZE];

    fseek(Nmz.w, nmz_getidxptr(Nmz.wi, l), 0);
    fgets(buf, BUFSIZE - 1, Nmz.w);
    nmz_chomp(buf);

    nmz_debug_printf("l:%d: %s", l, buf);
    fseek(Nmz.w, nmz_getidxptr(Nmz.wi, r), 0);
    fgets(buf, BUFSIZE - 1, Nmz.w);
    nmz_chomp(buf);

    nmz_debug_printf("r:%d: %s", r, buf);
}

/*
 * Get the size of the file fname.
 */
static int 
get_file_size (const char *fname) 
{
    struct stat st;

    stat(fname, &st);
    nmz_debug_printf("size of %s: %d\n", fname, (int)st.st_size);
    return ((int)(st.st_size));
}


/*
 * Get the left and right value of search range
 */
static void 
lrget(int *l, int *r)
{
    *l = 0;
    *r = get_file_size(NMZ.ii) / sizeof(int) - 1;

    if (nmz_is_debugmode()) {
        show_status(*l, *r);
    }
}

/*
 * Prefix match search
 */
static NmzResult 
prefix_match(const char *key, int v)
{
    int i, j, maxmatch, maxhit;
    char buf[BUFSIZE], tmpkey[BUFSIZE];
    NmzResult val, tmp;
    size_t n;

    val.num  = 0;
    val.data = NULL;
    val.stat = SUCCESS;
    tmp.num  = 0;
    tmp.data = NULL;
    tmp.stat = SUCCESS;

    strncpy(tmpkey, key, BUFSIZE - 1);
    tmpkey[strlen(tmpkey) - 1] = '\0';
    n = strlen(tmpkey);

    for (i = v; i >= 0; i--) {
        fseek(Nmz.w, nmz_getidxptr(Nmz.wi, i), 0);
        fgets(buf, BUFSIZE - 1, Nmz.w);
        if (strncmp(tmpkey, buf, n) != 0) {
            break;
        }
    }
    if (nmz_is_debugmode()) {
        v = i;
    }

    maxmatch = nmz_get_maxmatch();
    maxhit = nmz_get_maxhit();

    for (j = 0, i++;; i++) {
        /* 
         * Return if too much word would be hit
         * because treat 'a*' completely is too consuming 
         */
        if (fseek(Nmz.w, nmz_getidxptr(Nmz.wi, i), 0) != 0) {
            break;
        }
        if (fgets(buf, BUFSIZE - 1, Nmz.w) == NULL) {
            break;
        }
        nmz_chomp(buf);
        if (strncmp(tmpkey, buf, n) == 0) {
            tmp = nmz_get_hlist(i);
            if (tmp.stat == ERR_FATAL) {
                return tmp;
            }
            if (tmp.num > maxhit) {
                nmz_free_hlist(val);
                val.data = NULL;
                val.stat = ERR_TOO_MUCH_HIT;
                break;
            }
            if (tmp.num > 0) {
                j++;
                if (j > maxmatch) {
                    nmz_free_hlist(val);
                    val.data = NULL;
                    val.stat = ERR_TOO_MUCH_MATCH;
                    break;
                }
                val = nmz_ormerge(val, tmp);
                if (val.stat == ERR_FATAL)
                    return val;
                if (val.num > maxhit) {
                    nmz_free_hlist(val);
                    val.data = NULL;
                    val.stat = ERR_TOO_MUCH_HIT;
                    break;
                }
            }
            nmz_debug_printf("fw: %s, %d, %d\n", buf, tmp.num, val.num);
        } else
            break;
    }
    nmz_debug_printf("range: %d - %d\n", v + 1, i - 1);
    return val;
}

/*
 * Detect search mode
 */
static enum nmz_searchmethod 
detect_search_mode(const char *key) {
    if (strlen(key) <= 1)
        return WORD_MODE;
    if (nmz_isfield(key)) { /* field search */
        nmz_debug_printf("do FIELD search\n");
        return FIELD_MODE;
    }
    if (*key == '/' && key[strlen(key) - 1] == '/') {
        if (nmz_is_regex_searchmode()) {
            nmz_debug_printf("do REGEX search\n");
            return REGEX_MODE;    /* regex match */
        } else {
            nmz_debug_printf("disabled REGEX search\n");
            return WORD_MODE;
        }
    } else if (*key == '*' 
               && key[strlen(key) - 1] == '*'
               && *(key + strlen(key) - 2) != '\\' ) 
    {
        nmz_debug_printf("do REGEX (INTERNAL_MATCH) search\n");
        return REGEX_MODE;    /* internal match search (treated as regex) */
        /* [*keyword*] is always enabled */
    } else if (key[strlen(key) - 1] == '*'
        && *(key + strlen(key) - 2) != '\\')
    {
        nmz_debug_printf("do PREFIX_MATCH search\n");
        return PREFIX_MODE;    /* prefix match search */
    } else if (*key == '*') {
        nmz_debug_printf("do REGEX (SUFFIX_MATCH) search\n");
        return REGEX_MODE;    /* suffix match  (treated as regex)*/
        /* [*keyword] is always enabled */
    }
    
    if (strchr(key, '\t')) {
        nmz_debug_printf("do PHRASE search\n");
        return PHRASE_MODE;
    } else {
        nmz_debug_printf("do WORD search\n");
        return WORD_MODE;
    }
}

static NmzResult 
do_word_search(const char *key, NmzResult val)
{
    int v;

    if ((v = nmz_binsearch(key, 0)) != -1) {
        /* If found, get list */
        val = nmz_get_hlist(v);
        if (val.stat == ERR_FATAL)
            return val;
        if (val.num > nmz_get_maxhit()) {
            nmz_free_hlist(val);
            val.data = NULL;
            val.stat = ERR_TOO_MUCH_HIT;
            return val;
        }
    } else {
        val.num  = 0;  /* no hit */
        val.stat = SUCCESS; /* no hit but success */
        val.data = NULL;
    }
    return val;
}

static NmzResult 
do_prefix_match_search(const char *key, NmzResult val)
{
    int v;

    if ((v = nmz_binsearch(key, 1)) != -1) { /* 2nd argument must be 1  */
        /* If found, do foward match */
        val = prefix_match(key, v);
        if (val.stat != SUCCESS)
            return val;
    } else {
        val.num  = 0;  /* no hit */
        val.stat = SUCCESS; /* no hit but success */
        val.data = NULL;
    }
    return val;
}


/*
 * Calculate the hash value of the string str.
 */
static int 
hash(const char *str)
{
    int hash = 0, i, j;
    uchar *ustr = (uchar *)str;  /* for 8 bit chars handling */

    for (i = j = 0; *ustr; i++) {
        if (!issymbol(*ustr)) { /* except symbol */
            hash ^= nmz_seed[j & 0x3][*ustr];
            j++;
        }
        ustr++;
    }
    return (hash & 65535);
}

/*
 * Get the phrase hash and compare it with NmzResult
 */
static NmzResult 
cmp_phrase_hash(int hash_key, NmzResult val, 
                          FILE *phrase, FILE *phrase_index)
{
    int i, j, v, n, *list;
    long ptr;

    if (val.num == 0) {
        return val;
    }
    if (val.stat != SUCCESS) {
        nmz_debug_printf("cmp_phrase_hash: val.stat [%d]\n", val.stat);
        return val;
    }
    ptr = nmz_getidxptr(phrase_index, hash_key);
    if (ptr < 0) {
        nmz_free_hlist(val);
        val.data = NULL;
        val.num = 0;
        return val;
    }
    fseek(phrase, ptr, 0);
    nmz_get_unpackw(phrase, &n);

    list = malloc(n * sizeof(int));
    if (list == NULL) {
        nmz_set_dyingmsg(nmz_msg("%s", strerror(errno)));
        val.stat = ERR_FATAL;
        return val;
    }

    {
        int docid, sum = 0;
        n = nmz_read_unpackw(phrase, list, n);
        for (i = j = v = 0; i < n; i++) {
            docid = *(list + i) + sum;
            sum = docid;
            for (; j < val.num && docid >= val.data[j].docid; j++) {
                if (docid == val.data[j].docid) {
                    if (v != j) {
                        nmz_copy_hlist(val, v, val, j);
                    }
                    v++;
                }
            }
        }
    }
    if (v == 0) {
        nmz_free_hlist(val);
        val.data = NULL;
    }
    val.num = v;
    free(list);
    return val;
}

static int 
open_phrase_index_files(FILE **phrase, FILE **phrase_index)
{
    *phrase = fopen(NMZ.p, "rb");
    if (*phrase == NULL) {
        nmz_debug_printf("%s: %s", NMZ.p, strerror(errno));
        return 1;
    }

    *phrase_index = fopen(NMZ.pi, "rb");
    if (*phrase_index == NULL) {
        nmz_debug_printf("%s: %s", NMZ.pi, strerror(errno));
        fclose(*phrase);
        return 1;
    }
    return 0;
}


/*
 * FIXME: this function is too long and difficult to understand. (but works)
 */
static NmzResult 
do_phrase_search(const char *key, NmzResult src)
{
    int i, h = 0;
    char *p, tmpkey[BUFSIZE] = "", *words[QUERY_TOKEN_MAX + 1], *prevword = NULL;
    FILE *phrase, *phrase_index;
    struct nmz_hitnumlist *pr_hitnum = NULL; /* phrase hitnum */
    /* FIXME: very ad hoc.(for OpenBSD) */
    NmzResult val = src;

    strncpy(tmpkey, key, BUFSIZE - 1);
    p = tmpkey;
    if (strchr(p, '\t') == NULL) {  /* if only one word */
        val = do_word_search(p, val);
        return val;
    }

    if (open_phrase_index_files(&phrase, &phrase_index)) {
        val.stat = ERR_PHRASE_SEARCH_FAILED;  /* can't open phrase index */
        return val;
    }
        
    while (*p == '\t') {  /* beggining tabs are skipped */
        p++;
    }
    for (i = 0; ;) {
        char *q;

        if (*p == '\t') {
            p++;
            continue;
        }
        if (strlen(p) > 0) {
            words[i] = p;
            i++;
        }
        q = strchr(p, '\t');
        if (q) {
            *q = '\0';
        } else {
            break;
        }
        p = q + 1;
    }
    words[i] = NULL;

    for (i = 0; words[i] != NULL; i++) {
        char *word, word_mix[BUFSIZE];
        NmzResult tmp;

        tmp.num  = 0;
        tmp.data = NULL;
        tmp.stat = SUCCESS;

        word = words[i];
        tmp = do_word_search(word, val);
        if (tmp.stat == ERR_FATAL) {
            fclose(phrase);
            fclose(phrase_index);
            return tmp;
        }

        pr_hitnum = nmz_push_hitnum(pr_hitnum, word, tmp.num, tmp.stat);
        if (pr_hitnum == NULL) {
            fclose(phrase);
            fclose(phrase_index);
            tmp.stat = ERR_FATAL;
            return tmp;
        }

        if (i == 0) {
            val = tmp;
        } else if (val.num == 0) { /* phrase search is failed halfway */
            continue;
        } else {
            val = nmz_andmerge(val, tmp, (int *)NULL);

            strcpy(word_mix, prevword);
            strcat(word_mix, word);
            h = hash(word_mix);
            val = cmp_phrase_hash(h, val, phrase, phrase_index);
            nmz_debug_printf("\nhash:: <%s, %s>: h:%d, val.num:%d\n",
                prevword, word, h, val.num);
            if (val.stat == ERR_FATAL) {
                fclose(phrase);
                fclose(phrase_index);
                return val;
            }
        }
        prevword = word;
    }

    /* Set phrase hit numbers using phrase member */
    {
        struct nmz_hitnumlist *cur, *tmp;

        /* Get current hitnum list */
        cur = nmz_get_idx_hitnumlist(cur_idxnum);

        /* Push dummy element */
        cur = nmz_push_hitnum(cur, "", 0, SUCCESS);
        if (cur == NULL) {
            fclose(phrase);
            fclose(phrase_index);
            val.stat = ERR_FATAL;
            return val;
        }
        nmz_set_idx_hitnumlist(cur_idxnum, cur);

        /* Get the last element */
        tmp = cur;
        while (1) {
            if (tmp->next == NULL) {
                break;
            }
            tmp = tmp->next;
        }

        /* 
         * Then store phrase information.
         */
        tmp->phrase = pr_hitnum;
        tmp->hitnum = val.num;  /* total hit of phrases */
    }
    
    fclose(phrase);
    fclose(phrase_index);

    return val;
}

static void 
do_regex_preprocessing(char *expr)
{
    if (*expr == '*' && expr[strlen(expr) - 1] != '*') {
        /* If suffix match such as '*bar', enforce it into regex */
        memmove(expr, expr + 1, strlen(expr));
        escape_meta_characters(expr, BUFSIZE * 2);
        strncat(expr, "$", BUFSIZE * 2 - strlen(expr) - 1);
        expr[BUFSIZE * 2 - 1] = '\0';
    } else if (*expr != '*' && expr[strlen(expr) - 1] == '*') {
        /* If prefix match such as 'bar*', enforce it into regex */
        expr[strlen(expr) - 1] = '\0';
        escape_meta_characters(expr, BUFSIZE * 2);
        strncat(expr, ".*", BUFSIZE * 2 - strlen(expr) - 1);
        expr[BUFSIZE * 2 - 1] = '\0';
    } else if (*expr == '*' && expr[strlen(expr) - 1] == '*') {
        /* If internal match such as '*foo*', enforce it into regex */
        memmove(expr, expr + 1, strlen(expr));
        expr[strlen(expr) - 1] = '\0';
        escape_meta_characters(expr, BUFSIZE * 2);
    } else if (*expr == '/' && expr[strlen(expr) - 1] == '/') {
        if (nmz_is_regex_searchmode()) {
            nmz_debug_printf("do REGEX search\n");
            /* Genuine regex */
            /* Remove the both of '/' chars at begging and end of string */
            memmove(expr, expr + 1, strlen(expr));
            expr[strlen(expr) - 1]= '\0';
        } else {
            nmz_debug_printf("disabled REGEX search\n");
            escape_meta_characters(expr, BUFSIZE * 2);
        }
        return;
    } else {
        /* field search */
        if ((*expr == '"' && expr[strlen(expr) - 1] == '"')
            || (*expr == '{' && expr[strlen(expr) - 1] == '}')) 
        {
            /* Delimiters of field search */
            memmove(expr, expr + 1, strlen(expr)); 
            expr[strlen(expr) - 1] = '\0';
        }
        escape_meta_characters(expr, BUFSIZE * 2);
    }
}

static void
escape_meta_characters(char *expr, size_t bufsize)
{
    char buf[BUFSIZE * 4] = "", *bufp, *exprp;

    bufp = buf;
    exprp = expr;
    /* Escape meta characters */
    while (*exprp) {
        /* japanese only */
        if (!nmz_isalnum((unsigned char)*exprp) && !nmz_iseuc(*exprp)) {
            *bufp = '\\';
            bufp++;
        }
        *bufp = *exprp;
        bufp++;
        exprp++;
    }
    *bufp = '\0';
    strncpy(expr, buf, bufsize - 1);
    expr[bufsize - 1] = '\0';
}

static NmzResult 
do_regex_search(const char *expr, NmzResult val)
{
    FILE *fp;
    char tmpexpr[BUFSIZE * 2]; /* because of escaping meta characters */

    strcpy(tmpexpr, expr);
    do_regex_preprocessing(tmpexpr);

    fp = fopen(NMZ.w, "rb");
    if (fp == NULL) {
        nmz_warn_printf("%s: %s", NMZ.w, strerror(errno));
        val.stat = ERR_REGEX_SEARCH_FAILED;  /* can't open regex index */
        return val;
    }
    val = nmz_regex_grep(tmpexpr, fp, "", 0);
    fclose(fp);
    return val;

}

/*
 * Get a regular expression part from the string str like "from:/foobar/"
 * and set the expr to "/foobar/".
 */
static void 
get_regex_part(char *expr, const char *str)
{
    str = (char *)strchr(str, (int)':') + 1;
    strcpy(expr, str);
}

static NmzResult 
do_field_search(const char *fieldpat, NmzResult val)
{
    char expr[BUFSIZE * 2], /* For escaping meta characters */
        *field_name, file_name[BUFSIZE];
    FILE *fp;

    field_name = nmz_get_field_name(fieldpat);
    get_regex_part(expr, fieldpat);
    do_regex_preprocessing(expr);

    strcpy(file_name, NMZ.field); /* make pathname */
    strcat(file_name, field_name);

    fp = fopen(file_name, "rb");
    if (fp == NULL) {
        val.stat = ERR_FIELD_SEARCH_FAILED;
        return val;
    }
    val = nmz_regex_grep(expr, fp, field_name, 1); /* last argument must be 1 */
    fclose(fp);
    return val;
}

static void 
delete_beginning_backslash(char *str)
{
    if (*str == '\\') {
        memmove(str, str + 1, strlen(str));
    }
}

/*
 * Check the existence of lockfile.
 */
static int 
is_locked(void)
{
    FILE *lock;

    if ((lock = fopen(NMZ.lock, "rb"))) {
        fclose(lock);
        return 1;
    }
    return 0;
}


static enum nmz_perm 
parse_access(const char *line, const char *rhost, const char *raddr, enum nmz_perm operm)
{
    enum nmz_perm perm = operm;

    /* Skip white spaces */
    line += strspn(line, " \t");

    if (*line == '\0' || *line == '#') {
        /* Ignore blank line or comment line */
        return perm;
    }
    if (nmz_strprefixcasecmp(line, "allow") == 0) {
        line += strlen("allow");
        line += strspn(line, " \t");
        if (strcasecmp(line, "all") == 0) {
            perm = ALLOW;
        } else if (*raddr != '\0' && nmz_strprefixcmp(line, raddr) == 0) {
            /* IP Address : forward match */
            perm = ALLOW;
        } else if (*rhost != '\0' && nmz_strsuffixcmp(line, rhost) == 0) {
            /* Hostname : backword match */
            perm = ALLOW;
        }
    } else if (nmz_strprefixcasecmp(line, "deny") == 0) {
        line += strlen("deny");
        line += strspn(line, " \t");
        if (strcasecmp(line, "all") == 0) {
            perm = DENY;
        } else if (*raddr != '\0' && nmz_strprefixcmp(line, raddr) == 0) {
            /* IP Address : forward match */
            perm = DENY;
        } else if (*rhost != '\0' && nmz_strsuffixcmp(line, rhost) == 0) {
            /* Hostname : backword match */
            perm = DENY;
        }
    }
    return perm;
}

static enum nmz_perm 
check_access(void)
{
    char buf[BUFSIZE];
    char *rhost, *raddr;
    FILE *fp;
    enum nmz_perm perm = ALLOW;
    
    rhost = nmz_getenv("REMOTE_HOST");
    raddr = nmz_getenv("REMOTE_ADDR");

    if (*rhost == '\0' && *raddr == '\0') { /* not from remote */
        return perm;
    }

    fp = fopen(NMZ.access, "rb");
    if (fp == NULL) {
        return perm;
    }
    while (fgets(buf, BUFSIZE, fp)) {
        nmz_chomp(buf);
        perm = parse_access(buf, rhost, raddr, perm);
    }
    fclose(fp);
    return perm;
}

/*
 * Opening files at once
 */
static enum nmz_stat
open_index_files(void)
{
    Nmz.i = fopen(NMZ.i, "rb");
    if (Nmz.i == NULL) {
        nmz_debug_printf("%s: %s", NMZ.i, strerror(errno));
        return ERR_CANNOT_OPEN_INDEX;
    }
    Nmz.wi = fopen(NMZ.wi, "rb"); /* Check NMZ.wi at first to recognize index format */
    if (Nmz.wi == NULL) {
        nmz_debug_printf("%s: %s", NMZ.wi, strerror(errno));
        fclose(Nmz.i);
        return ERR_OLD_INDEX_FORMAT;
    }
    Nmz.ii = fopen(NMZ.ii, "rb");
    if (Nmz.ii == NULL) {
        nmz_debug_printf("%s: %s", NMZ.ii, strerror(errno));
        fclose(Nmz.wi);
        fclose(Nmz.i);
        return ERR_CANNOT_OPEN_INDEX;
    }
    Nmz.w = fopen(NMZ.w, "rb");
    if (Nmz.w == NULL) {
        nmz_debug_printf("%s: %s", NMZ.w, strerror(errno));
        fclose(Nmz.ii);
        fclose(Nmz.wi);
        fclose(Nmz.i);
        return ERR_CANNOT_OPEN_INDEX;
    }

    return SUCCESS;
}

/*
 * Closing files at once
 */
static void 
close_index_files(void)
{
    fclose(Nmz.i);
    fclose(Nmz.ii);
    fclose(Nmz.w);
    fclose(Nmz.wi);
}


/*
 * Do logging, separated with TAB characters 
 * FIXME: It does not consider a LOCK mechanism!
 */
static void 
do_logging(const char *query, int n)
{
    FILE *slog;
    char *rhost;
    char *time_string;
    time_t t;

    t = time(&t);
    time_string = ctime(&t);

    slog = fopen(NMZ.slog, "a");
    if (slog == NULL) {
        nmz_warn_printf("%s: %s", NMZ.slog, strerror(errno));
        return;
    }
    rhost = nmz_getenv("REMOTE_HOST");
    if (*rhost == '\0') {
        rhost = nmz_getenv("REMOTE_ADDR");
    }
    if (*rhost == '\0')
        rhost = "LOCALHOST";
    fprintf(slog, "%s\t%d\t%s\t%s", query, n, rhost, time_string);

    fclose(slog);
}

static NmzResult 
nmz_search_sub(NmzResult hlist, const char *query, int n)
{
    enum nmz_stat nstat;
    cur_idxnum = n;

    if (check_access() != ALLOW) { /* if access denied */
        hlist.stat = ERR_NO_PERMISSION;
        return hlist;
    }

    if (is_locked()) {
        hlist.stat = ERR_INDEX_IS_LOCKED;
        return hlist;
    }

    if ((nstat = open_index_files()) != SUCCESS) {
        /* If open failed */
        hlist.stat = nstat;
        return hlist;
    }

    nmz_set_docnum(get_file_size(NMZ.t) / sizeof(int));

    nmz_init_parser();
    hlist = nmz_expr(); /* Do searching! */

    if (hlist.stat == ERR_FATAL) {
        return hlist;
    }

    if (hlist.stat == SUCCESS && hlist.num > 0) {  /* if hit */
        nmz_set_idxid_hlist(hlist, n);
    }
    nmz_set_idx_totalhitnum(cur_idxnum, hlist.num);
    close_index_files();

    if (nmz_is_loggingmode()) {
        do_logging(query, hlist.num);
    }
    return hlist;
}

static void 
make_fullpathname_index(int n)
{
    char *base;

    base = nmz_get_idxname(n);

    nmz_pathcat(base, NMZ.i);
    nmz_pathcat(base, NMZ.ii);
    nmz_pathcat(base, NMZ.w);
    nmz_pathcat(base, NMZ.wi);
    nmz_pathcat(base, NMZ.p);
    nmz_pathcat(base, NMZ.pi);
    nmz_pathcat(base, NMZ.lock);
    nmz_pathcat(base, NMZ.slog);
    nmz_pathcat(base, NMZ.field);
    nmz_pathcat(base, NMZ.t);
    nmz_pathcat(base, NMZ.access);
    nmz_pathcat(base, NMZ.warnlog);
}

/*
 * Remove quotation marks at begging and end of string.
 */
static 
void remove_quotes(char *str) 
{
    if ((strlen(str) >= 3 && (*str == '"' && str[strlen(str) - 1] == '"'))
        || (*str == '{' && str[strlen(str) - 1] == '}')) 
    {
        memmove(str , str + 1, strlen(str)); 
        str[strlen(str) - 1]= '\0';
    } 
}

/*
 * Normalize index names. Expand aliases and complete abbreviated names.
 */
static enum nmz_stat
normalize_idxnames(void)
{
    if (nmz_expand_idxname_aliases() != SUCCESS) {
        return FAILURE;
    }
    if (nmz_complete_idxnames() != SUCCESS) {
        return FAILURE;
    }

    nmz_uniq_idxnames();

    if (nmz_is_debugmode()) {
        int i;
        for (i = 0; i < nmz_get_idxnum(); i++) {
            nmz_debug_printf("Index name [%d]: %s\n", i, nmz_get_idxname(i));
        }
    }
    return SUCCESS;
}

static int 
issymbol(int c)
{
    if (c >= 0x00 && c < 0x80 && !nmz_isalnum(c)) {
        return 1;
    } else {
        return 0;
    }
}

/*
 *
 * Public functions
 *
 */

/*
 * Main routine of binary search
 */
int 
nmz_binsearch(const char *key, int prefix_match_mode)
{
    int l, r, x, e = 0, i;
    char term[BUFSIZE], tmpkey[BUFSIZE] = "";

    strncpy(tmpkey, key, BUFSIZE - 1);
    lrget( &l, &r);

    if (prefix_match_mode) {  /* truncate a '*' character at the end */
        tmpkey[strlen(tmpkey) - 1] = '\0';
    }

    while (r >= l) {
        x = (l + r) / 2;

        /* Over BUFSIZE (maybe 1024) size keyword is nuisance */
        fseek(Nmz.w, nmz_getidxptr(Nmz.wi, x), 0);
        fgets(term, BUFSIZE - 1, Nmz.w);
        nmz_chomp(term);

        nmz_debug_printf("searching: %s", term);
        for (e = 0, i = 0; *(term + i) != '\0' && *(tmpkey + i) != '\0' ; i++)
        {
            /*
             * compare in unsigned. 
             * because they could be 8 bit characters (0x80 or upper).
             */
            if ((uchar)*(term + i) > (uchar)*(tmpkey + i)) {
                e = -1;
                break;
            }
            if ((uchar)*(term + i) < (uchar)*(tmpkey + i)) {
                e = 1;
                break;
            }
        }

        if (*(term + i) == '\0' && *(tmpkey + i)) {
            e = 1;
        } else if (! prefix_match_mode && *(term + i) != '\0' 
                   && (*(tmpkey + i) == '\0')) {
            e = -1;
        }

        /* If hit, return */
        if (e == 0) {
            return x;
        }

        if (e < 0) {
            r = x - 1;
        } else {
            l = x + 1;
        }
    }
    return -1;
}

/*
 * Flow of searching.
 */
NmzResult 
nmz_search(const char *query)
{
    int i, ret;
    NmzResult hlist, tmp[INDEX_MAX];

    hlist.num  = 0;
    hlist.data = NULL;
    hlist.stat = SUCCESS;
    for (i = 0; i < INDEX_MAX; i++) {
        tmp[i].num  = 0;
        tmp[i].data = NULL;
        tmp[i].stat = SUCCESS;
    }

    if (normalize_idxnames() != SUCCESS) {
        hlist.stat = ERR_FATAL;
        return hlist;
    }

    ret = nmz_make_query(query);
    if (ret != SUCCESS) {
        nmz_set_dyingmsg(nmz_msg(nmz_strerror(ret)));
        hlist.stat = ERR_FATAL;
        return hlist;
    }

    for (i = 0; i < nmz_get_idxnum(); i++) {
        make_fullpathname_index(i);
        tmp[i] = nmz_search_sub(tmp[i], query, i);

        if (tmp[i].stat != SUCCESS) {
            tmp[i].num = 0;
            if (tmp[i].stat == ERR_FATAL) {
                hlist.data = NULL;
                hlist.stat = tmp[i].stat;
                return hlist; /* FIXME: need freeing memory? */
            }

            {
                /* 
                 * Save the error state for later error messaging.
                 */
                struct nmz_hitnumlist *cur = NULL;
                cur = nmz_push_hitnum(cur, "", 0, tmp[i].stat);
                if (cur == NULL) {
                    hlist.stat = ERR_FATAL;
                    return hlist;
                }
                nmz_set_idx_hitnumlist(cur_idxnum, cur);
            }

            /*
             * Reset state with SUCCESS. Because at this time, 
             * trivial errors such as ERR_TOO_MUCH_MATCH are 
             * recorded in cur->stat.
             * FIXME: Very acrobatic logic.
             */
            tmp[i].stat = SUCCESS; 
        }
    }

    hlist = nmz_merge_hlist(tmp);

    /* score recomputation */
    nmz_recompute_score(&hlist);

    if (hlist.stat == SUCCESS && hlist.num > 0) { /* HIT!! */
        /* Sort by date at first*/
        if (nmz_sort_hlist(hlist, SORT_BY_DATE) != SUCCESS) {
            hlist.stat = ERR_FATAL;
            return hlist;
        }
        if (nmz_get_sortmethod() != SORT_BY_DATE) {
            if (nmz_sort_hlist(hlist, nmz_get_sortmethod()) != SUCCESS) {
                hlist.stat = ERR_FATAL;
                return hlist;
            }
        }
        if (nmz_get_sortorder() == ASCENDING) {  /* default is descending */
            if (nmz_reverse_hlist(hlist)) {
                hlist.stat = ERR_FATAL;
                return hlist; 
            }
        }
    }

    return hlist;
}



NmzResult 
nmz_do_searching(const char *key, NmzResult src)
{
    enum nmz_searchmethod mode;
    char tmpkey[BUFSIZE] = "";
    /* FIXME: very ad hoc.(for OpenBSD) */
    NmzResult val = src;

    strncpy(tmpkey, key, BUFSIZE - 1);

    nmz_debug_printf("before nmz_regex_strlower: [%s]", tmpkey);
    nmz_regex_strlower(tmpkey);
    nmz_debug_printf("after nmz_regex_strlower:  [%s]", tmpkey);

    mode = detect_search_mode(tmpkey);
    if (mode == ERROR_MODE) {
        val.stat = ERR_FATAL;
        return val;
    }

    if (mode == WORD_MODE || mode == PHRASE_MODE) {
        remove_quotes(tmpkey);
        /* If under Japanese mode, do wakatigaki (word segmentation) */
        if (nmz_is_lang_ja()) {
            if (nmz_wakati(tmpkey)) {
                val.stat = ERR_FATAL;
                return val;
            }
            /* Re-examine because tmpkey is wakatied. */
            if (strchr(tmpkey, '\t')) {
                mode = PHRASE_MODE;
            } else {
                mode = WORD_MODE;
            }
        }
    }

    delete_beginning_backslash(tmpkey);

    if (mode == PREFIX_MODE) {
        val = do_prefix_match_search(tmpkey, val);
    } else  if (mode == REGEX_MODE) {
        val = do_regex_search(tmpkey, val);
    } else if (mode == PHRASE_MODE) {
        val = do_phrase_search(tmpkey, val);
    } else if (mode == FIELD_MODE) {
        val = do_field_search(tmpkey, val);
    } else {
        val = do_word_search(tmpkey, val);
    }

    if (mode != PHRASE_MODE) {
        struct nmz_hitnumlist *cur;
        cur = nmz_get_idx_hitnumlist(cur_idxnum);
        cur = nmz_push_hitnum(cur, key, val.num, val.stat);
        if (cur == NULL) {
            val.stat = ERR_FATAL;
            return val;
        }
        nmz_set_idx_hitnumlist(cur_idxnum, cur);
    }

    return val;
}

void 
nmz_free_hitnums(struct nmz_hitnumlist *hn)
{
    struct nmz_hitnumlist *tmp;

    for (; hn != NULL; hn = tmp) {
        tmp = hn->next;
        free(hn->word);
        if (hn->phrase != NULL) { /* it has phrases */
            nmz_free_hitnums(hn->phrase);
        }
        free(hn);
    }
}

static void nmz_regex_strlower(char *str)
{
    if (strlen(str) >= 2 && *str == '/' && str[strlen(str) - 1] == '/') {
        if (nmz_is_regex_searchmode()) {
            /* keep \W \S \D \A \Z \B \G */
            char bak = '\0';

            while (*str) {
                if (bak != '\\') {
                    /* Using ascii dependent lower same as mknmz. */
                    bak = *str = _nmz_tolower(*str);
                } else {
                    bak = '\0';
                }
                str++;
            }
            return;
        }
    }

    nmz_strlower(str);
}
