/*
 * 
 * idxname.c - Idx handling routines.
 *
 * $Id: idxname.c,v 1.25.8.10 2009-02-17 08:45:14 opengl2772 Exp $
 * 
 * Copyright (C) 1997-1999 Satoru Takabayashi All rights reserved.
 * Copyright (C) 2000-2009 Namazu Project All rights reserved.
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

#ifdef HAVE_ERRNO_H
#  include <errno.h>
#endif

#ifdef HAVE_STDLIB_H
#  include <stdlib.h>
#endif
#include <ctype.h>

#ifdef HAVE_STRING_H
#  include <string.h>
#else
#  include <strings.h>
#endif

#include "libnamazu.h"
#include "search.h"
#include "alias.h"
#include "var.h"
#include "idxname.h"
#include "util.h"

static struct nmz_indices indices = {0}; /* Initialize member `num' with 0 */

/*
 * Default directory to place index. This setting can be
 * changed with nmz_set_defaultidx().
 */
static char defaultidx[BUFSIZE] = OPT_INDEXDIR;

/*
 *
 * Public functions
 *
 */

enum nmz_stat 
nmz_add_index(const char *idxname)
{
    int newidxnum = indices.num;

    if (newidxnum >= INDEX_MAX) {
        nmz_warn_printf("Too many indices.\n");
        return FAILURE;
    }
    indices.names[newidxnum] = malloc(strlen(idxname) + 1);
    if (indices.names[newidxnum] == NULL)
        return FAILURE;
    strcpy(indices.names[newidxnum], idxname);
    indices.hitnumlists[newidxnum] = NULL;
    indices.num = newidxnum + 1;

    return SUCCESS;
}

void 
nmz_free_idxnames(void)
{
    int i;
    for (i = 0; i < indices.num; i++) {
        free(indices.names[i]);
        nmz_free_hitnums(indices.hitnumlists[i]);
    }
    indices.num = 0;
}

/*
 * Except duplicated indices with a simple O(n^2) algorithm.
 */
void 
nmz_uniq_idxnames(void)
{
    int i, j, k;

    for (i = 0; i < indices.num - 1; i++) {
        for (j = i + 1; j < indices.num; j++) {
            if (strcmp(indices.names[i], indices.names[j]) == 0) {
                free(indices.names[j]);
                for (k = j + 1; k < indices.num; k++) {
                    indices.names[k - 1] = indices.names[k];
                }
                indices.num--;
                j--;
            }
        }
    }
}

/*
 * Expand index name aliases defined in namazurc.
 * e.g., Alias quux /home/foobar/NMZ/quux
 */
int 
nmz_expand_idxname_aliases(void)
{
    int i;

    for (i = 0; i < indices.num; i++) {
        struct nmz_alias *list = nmz_get_aliases();
        while (list != NULL) {
            if (strcmp(indices.names[i], list->alias) == 0) {
                free(indices.names[i]);
                indices.names[i] = malloc(strlen(list->real) + 1);
                if (indices.names[i] == NULL) {
                    nmz_set_dyingmsg(nmz_msg("%s", strerror(errno)));
                    return FAILURE;
                }
                strcpy(indices.names[i], list->real);
            }
            list = list->next;
        }
    }
    return 0;
}

/*
 * Complete an abbreviated index name to completed one.
 * e.g.,  +foobar -> (defaultidx)/foobar
 */
int 
nmz_complete_idxnames(void)
{
    int i;

    for (i = 0; i < indices.num; i++) {
        if (*indices.names[i] == '+' && 
        nmz_isalnum((unsigned char)*(indices.names[i] + 1))) {
            char *tmp;
            tmp = malloc(strlen(defaultidx) 
                  + 1 + strlen(indices.names[i]) + 1);
            if (tmp == NULL) {
                nmz_set_dyingmsg(nmz_msg("%s", strerror(errno)));
                return FAILURE;
            }
            strcpy(tmp, defaultidx);
            strcat(tmp, "/");
            strcat(tmp, indices.names[i] + 1);  /* +1 means '+' */
            free(indices.names[i]);
            indices.names[i] = tmp;
        }
    }
    return 0;
}

/*
 * Get the name of the index specified by id.
 */
char *
nmz_get_idxname(int id)
{
    return indices.names[id];
}

/*
 * Get the total number of indices to search.
 */
int 
nmz_get_idxnum()
{
    return indices.num;
}

/*
 * Set the total hit number of the index specified by id.
 */
void
nmz_set_idx_totalhitnum(int id, int hitnum)
{
    indices.totalhitnums[id] = hitnum;
}

/*
 * Get the total hit number of the index specified by id.
 */
int
nmz_get_idx_totalhitnum(int id)
{
    return indices.totalhitnums[id];
}

/*
 * Get the hitnumlist of the index specified by id.
 */
struct nmz_hitnumlist *
nmz_get_idx_hitnumlist(int id)
{
    return indices.hitnumlists[id];
}

void
nmz_set_idx_hitnumlist(int id, struct nmz_hitnumlist *hnlist)
{
    indices.hitnumlists[id] = hnlist;
}

/*
 * Push something and return pushed list.
 */
struct nmz_hitnumlist *
nmz_push_hitnum(struct nmz_hitnumlist *hn, 
	    const char *str,
	    int hitnum, 
	    enum nmz_stat stat
)
{
    struct nmz_hitnumlist *hnptr = hn, *prevhnptr = hn;
    while (hnptr != NULL) {
        prevhnptr = hnptr;
        hnptr = hnptr->next;
    }
    if ((hnptr = malloc(sizeof(struct nmz_hitnumlist))) == NULL) {
        nmz_set_dyingmsg(nmz_msg("%s", strerror(errno)));
        return NULL;
    }
    if (prevhnptr != NULL)
        prevhnptr->next = hnptr;
    hnptr->hitnum = hitnum;
    hnptr->stat  = stat;
    hnptr->phrase = NULL;
    hnptr->next  = NULL;
    if ((hnptr->word = malloc(strlen(str) +1)) == NULL) {
        nmz_set_dyingmsg(nmz_msg("%s", strerror(errno)));
        return NULL;
    }
    strcpy(hnptr->word, str);

    if (hn == NULL)
        return hnptr;
    return hn;
}


void 
nmz_set_defaultidx(const char *idx)
{
    strncpy(defaultidx, idx, BUFSIZE - 1);
    defaultidx[BUFSIZE - 1] = '\0';
}

char *
nmz_get_defaultidx(void)
{
    return defaultidx;
}
