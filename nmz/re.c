/*
 * 
 * re.c -
 * 
 * $Id: re.c,v 1.32.8.18 2013-01-15 17:11:04 opengl2772 Exp $
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
 * This file must be encoded in EUC-JP encoding
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

#ifdef HAVE_ERRNO_H
#  include <errno.h>
#endif

#ifdef HAVE_STRING_H
#  include <string.h>
#else
#  include <strings.h>
#endif

#include "libnamazu.h"
#include "regex.h"
#include "util.h"
#include "hlist.h"
#include "replace.h"
#include "re.h"
#include "l10n-ja.h"
#include "var.h"

#define STEP 256

static NmzResult nmz_regex_grep_standard ( struct re_pattern_buffer *rp, FILE *fp );
static NmzResult nmz_regex_grep_field ( struct re_pattern_buffer *rp, FILE *fp, const char * field );

/*
 *
 * Public functions
 *
 */

/*
 * FIXME: Dirty coding...
 */
NmzResult 
nmz_regex_grep(const char *expr, FILE *fp, const char *field, int field_mode)
{
    char tmpexpr[BUFSIZE] = "";
    struct re_pattern_buffer *rp;
    NmzResult val;

    val.num  = 0;
    val.data = NULL;
    val.stat = SUCCESS;

    if (nmz_is_lang_ja()) {
        /* japanese only */
        nmz_re_mbcinit(MBCTYPE_EUC);
    } else {
        nmz_re_mbcinit(MBCTYPE_ASCII);
    }

    rp = ALLOC(struct re_pattern_buffer);
    MEMZERO((char *)rp, struct re_pattern_buffer, 1);
    rp->buffer = 0;
    rp->allocated = 0;

    strncpy(tmpexpr, expr, BUFSIZE - 1); /* save orig_expr */
    nmz_debug_printf("REGEX: '%s'\n", tmpexpr);

    nmz_re_compile_pattern(tmpexpr, strlen(tmpexpr), rp);

    if (!field_mode) {
        val = nmz_regex_grep_standard(rp, fp);
    } else {
        val = nmz_regex_grep_field(rp, fp, field);
    }

    nmz_re_free_pattern(rp);

    return val;
}

static NmzResult 
nmz_regex_grep_standard(struct re_pattern_buffer *rp, FILE *fp)
{
    char buf[BUFSIZE] = "";
    int i, n, maxmatch, maxhit;
    NmzResult val, tmp;

    val.num  = 0;
    val.data = NULL;
    val.stat = SUCCESS;
    tmp.num  = 0;
    tmp.data = NULL;
    tmp.stat = SUCCESS;

    maxmatch = nmz_get_maxmatch();
    maxhit = nmz_get_maxhit();

    for (i = n = 0; fgets(buf, BUFSIZE - 1, fp); i++) {
        if (buf[strlen(buf) - 1] != '\n') {  /* too long */
            i--;
            continue;
        }
        buf[strlen(buf) - 1] = '\0';  /* LF to NULL */
        if (strlen(buf) == 0) {
            continue;
        }
        nmz_strlower(buf);
        if (nmz_re_search(rp, buf, strlen(buf), 0, strlen(buf), (struct re_registers *)NULL) != -1) { 
            /* Matched */
            tmp = nmz_get_hlist(i);
            if (tmp.stat == ERR_FATAL) {
                nmz_free_hlist(val);
	        return tmp;
            }
            if (tmp.num > maxhit) {
                nmz_free_hlist(tmp);
                nmz_free_hlist(val);
                val.data = NULL;
                val.stat = ERR_TOO_MUCH_HIT;
                break;
            }

            if (tmp.num > 0) {
                n++;
                if (n > maxmatch) {
                    nmz_free_hlist(tmp);
                    nmz_free_hlist(val);
                    val.data = NULL;
                    val.stat = ERR_TOO_MUCH_MATCH;
                    return val;
                }

                val = nmz_ormerge(val, tmp);
		if (val.stat == ERR_FATAL) {
		    return val;
                }
                if (val.num > maxhit) {
                    nmz_free_hlist(val);
                    val.data = NULL;
                    val.stat = ERR_TOO_MUCH_HIT;
                    break;
                }
            }

	    if (nmz_is_debugmode()) {
                char buf2[BUFSIZE];

                fseek(Nmz.w, nmz_getidxptr(Nmz.wi, i), 0);
                fgets(buf2, BUFSIZE, Nmz.w);
                nmz_chomp(buf2);
                nmz_debug_printf("re: %s, (%d:%s), %d, %d\n", 
                        buf2, i, buf, tmp.num, val.num);
	    }
        }
    }

    return val;
}

static NmzResult 
nmz_regex_grep_field(struct re_pattern_buffer *rp, FILE *fp, const char *field)
{
    char buf[BUFSIZE] = "";
    int i, n, size = 0, maxhit, uri_mode = 0;
    NmzResult val;
    FILE *date_index;

    val.num  = 0;
    val.data = NULL;
    val.stat = SUCCESS;

    date_index = fopen(NMZ.t, "rb");
    if (date_index == NULL) {
        nmz_set_dyingmsg(nmz_msg("%s: %s", NMZ.t, strerror(errno)));
        val.stat = ERR_FATAL;
        return val; /* error */
    }

    {
        nmz_malloc_hlist(&val, size += STEP);
	if (val.stat == ERR_FATAL) {
            fclose(date_index);
	    return val;
        }
	val.num = 0; /* set 0 for no matching case */
        if (strcmp(field, "uri") == 0) {
            uri_mode = 1;
        }
    }

    maxhit = nmz_get_maxhit();

    for (i = n = 0; fgets(buf, BUFSIZE - 1, fp); i++) {
        if (buf[strlen(buf) - 1] != '\n') {  /* too long */
            i--;
            continue;
        }
        buf[strlen(buf) - 1] = '\0';  /* LF to NULL */
        if (strlen(buf) == 0) {
            continue;
        }
        if (uri_mode) {  /* consider the REPLACE directive in namazurc */ 
            nmz_replace_uri(buf);
        }
        nmz_strlower(buf);
        if (nmz_re_search(rp, buf, strlen(buf), 0, strlen(buf), (struct re_registers *)NULL) != -1) { 
            /* Matched */
            struct nmz_data data;

            if (fseek(date_index, i * sizeof(data.date), 0) != 0) {
                nmz_set_dyingmsg(nmz_msg("%s: %s", NMZ.t, strerror(errno)));
                fclose(date_index);
                nmz_free_hlist(val);
                val.data = NULL;
                val.stat = ERR_FATAL;
                return val; /* error */
            }
            nmz_fread(&data.date, sizeof(data.date), 1, date_index);

            if (data.date == -1) {
                continue;
            }

            n++;
            if (n > maxhit) {
                fclose(date_index);
                nmz_free_hlist(val);
                val.data = NULL;
                val.stat = ERR_TOO_MUCH_HIT;
                return val;
            }
            {
                if (n > size) {
                    nmz_realloc_hlist(&val, size += STEP);
		    if (val.stat == ERR_FATAL) {
                        fclose(date_index);
		        return val;
                    }
                }
                val.data[n-1].date = data.date;
                val.data[n-1].docid = i;
                val.data[n-1].score = 1;  /* score = 1 */
                val.num = n;
            }

	    if (nmz_is_debugmode()) {
                nmz_debug_printf("field: [%d]<%s> id: %d\n", 
                        val.num, buf, i);
	    }
        }
    }

    fclose(date_index);

    return val;
}
