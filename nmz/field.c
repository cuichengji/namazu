/*
 * 
 * $Id: field.c,v 1.29.8.11 2007-12-05 16:50:47 opengl2772 Exp $
 * 
 * Copyright (C) 1997-1999 Satoru Takabayashi All rights reserved.
 * Copyright (C) 2000-2007 Namazu Project All rights reserved.
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

#include <ctype.h>
#include <stdio.h>

#ifdef HAVE_ERRNO_H
#  include <errno.h>
#endif

#ifdef HAVE_STRING_H
#  include <string.h>
#else
#  include <strings.h>
#endif

#include "libnamazu.h"
#include "field.h"
#include "util.h"
#include "re.h"
#include "var.h"
#include "replace.h"
#include "idxname.h"

/*
 * Private variables
 */

static int cache_idx = 0, cache_num = 0;
static struct field_cache fc[FIELD_CACHE_SIZE];

/*
 *
 * Private functions
 *
 */

static void apply_field_alias ( char *field );
static int is_field_safe_char ( int c );
static void make_fullpathname_field ( int n );


static void 
apply_field_alias(char *field)
{
    if (strcmp(field, "title") == 0) {
        strcpy(field, "subject");
    } else if (strcmp(field, "author") == 0) {
        strcpy(field, "from");
    } else if (strcmp(field, "path") == 0) {
        strcpy(field, "uri");
    } 
}

static int 
is_field_safe_char(int c)
{
    if ((strchr(FIELD_SAFE_CHARS, c) != NULL)) {
        return 1;
    } else {
        return 0;
    }

}

static void 
make_fullpathname_field(int n)
{
    char *base;

    base = nmz_get_idxname(n);
    nmz_pathcat(base, NMZ.field);
}

/*
 *
 * Public functions
 *
 */


/*
 * Check the key whether field or not.
 */
int 
nmz_isfield(const char *key)
{
    if (*key == '+') {
        key++;
    } else {
        return 0;
    }
    while (*key) {
        if (! is_field_safe_char(*key)) {
            break;
        }
        key++;
    }
    if (nmz_isalpha((unsigned char)*(key - 1)) && *key == ':' ) {
        return 1;
    }
    return 0;
}

/*
 * This function returns a string storing a field name in
 * the fieldpat. The string can only be used until the next
 * call to the function. 
 */
char *
nmz_get_field_name(const char *fieldpat)
{
    static char field_name[BUFSIZE]; /* storing field name */
    char *tmp = field_name;
    int count = 0;

    fieldpat++;  /* ignore beggining '+' mark */
    while (*fieldpat && count < BUFSIZE - 1) {
        if (! is_field_safe_char(*fieldpat)) {
            break;
        }
        *tmp = *fieldpat;
        tmp++;
        fieldpat++;
	count++;
    }
    *tmp = '\0';

    apply_field_alias(field_name);
    return field_name;
}

void 
nmz_get_field_data(int idxid, int docid, const char *field, char *data) 
{
    char fname[BUFSIZE] = "";
    char tmpfield[BUFSIZE] = "";
    int i;
    FILE *fp_field, *fp_field_idx;

    strcpy(data, ""); /* For safety. */

    strncpy(tmpfield, field, BUFSIZE - 1);
    apply_field_alias(tmpfield);  /* This would overwrite `tmpfield' */

    /* 
     * Consult caches.
     * Caching is intended to reduce rereading same data from a disk drive.
     * It works well with this kind of format: <a href="${uri}">${uri}</a>.
     */
    for (i = 0; i < cache_num; i++) {
	if (idxid == fc[i].idxid && docid == fc[i].docid &&
	    strcmp(tmpfield, fc[i].field) == 0)
	{  /* cache hit! */
	    nmz_debug_printf("field cache [%s] hit!\n", tmpfield);
	    strncpy(data, fc[i].data, BUFSIZE - 1);	/* data length should be BUFSIZE - 1 */
	    return;
	}
    }

    /* Make a pathname */
    make_fullpathname_field(idxid);
    strncpy(fname, NMZ.field, BUFSIZE - 1);
    strncat(fname, tmpfield, BUFSIZE - strlen(fname) - 1);
    
    fp_field = fopen(fname, "rb");
    if (fp_field == NULL) {
        nmz_warn_printf("%s: %s", fname, strerror(errno));
	return;
    }

    strncat(fname, ".i", BUFSIZE - strlen(fname) - 1);
    fp_field_idx = fopen(fname, "rb");
    if (fp_field_idx == NULL) {
        nmz_warn_printf("%s: %s", fname, strerror(errno));
        fclose(fp_field);
	return;
    }

    /* 
     * You can rely on that length of a field is shorter than 
     * BUFSIZE [1024] because its length is restricted in 
     * conf.pl: $conf::MAX_FIELD_LENGTH = 200;
     */
    fseek(fp_field, nmz_getidxptr(fp_field_idx, docid), 0);
    fgets(data, BUFSIZE, fp_field);
    nmz_chomp(data);

    fclose(fp_field);
    fclose(fp_field_idx);

    /* Cache */
    fc[cache_idx].idxid = idxid;
    fc[cache_idx].docid = docid;
    strncpy(fc[cache_idx].field, tmpfield, BUFSIZE - 1);
    fc[cache_idx].field[BUFSIZE - 1] = '\0';
    strncpy(fc[cache_idx].data, data, BUFSIZE - 1);
    fc[cache_idx].data[BUFSIZE - 1] = '\0';
    cache_idx = (cache_idx + 1) % FIELD_CACHE_SIZE;
    if (cache_num < FIELD_CACHE_SIZE) {
	cache_num++;
    }
}

void
nmz_free_field_cache(void)
{
       int i;
       for(i = 0; i < cache_num; i++) {
               fc[i].idxid =0;
               fc[i].docid =0;
               strcpy(fc[i].field, "");
               strcpy(fc[i].data, "");
       }
       cache_num = 0;
}
