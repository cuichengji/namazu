/*
 * 
 * replace.c - 
 *
 * $Id: replace.c,v 1.15.8.9 2009-08-31 23:03:07 opengl2772 Exp $
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

#include <stdio.h>
#ifdef HAVE_STDLIB_H
#  include <stdlib.h>
#endif
#include <assert.h>

#ifdef HAVE_ERRNO_H
#  include <errno.h>
#endif

#ifdef HAVE_STRING_H
#  include <string.h>
#else
#  include <strings.h>
#endif

#include "replace.h"
#include "libnamazu.h"
#include "i18n.h"
#include "regex.h"
#include "re.h"
#include "util.h"

static struct nmz_replace *replaces = NULL;

/*
 *
 * Public functions
 *
 */

void 
nmz_free_replaces(void)
{
    struct nmz_replace *list, *next;
    list = replaces;

    while (list) {
	next = list->next;
	free(list->pat);
	free(list->rep);
	if (list->pat_re != NULL) {
	    nmz_re_free_pattern(list->pat_re);
	}
	free(list);
	list = next;
    }
}

/*
 * Replace a URI
 */
int 
nmz_replace_uri(char *uri)
{
    int npat, nrep, i, j;
    char tmp[BUFSIZE] = "";
    struct nmz_replace *list = replaces;
    int is_regex_matching = 0;

    if (uri[0] == '\0') {
        return 0;
    }
    strncpy(tmp, uri, BUFSIZE - 1);

    while (list) {
	struct re_registers regs;
	int mlen;
	struct re_pattern_buffer *re;

	re = list->pat_re;
	regs.allocated = 0;

	if (re == NULL) {
	    /* Compiled regex is no available, we will apply the straight
	     * string substitution.
	     */
	    is_regex_matching = 0;
	} else if (0 < (mlen = nmz_re_match (re, tmp, strlen (tmp), 0, &regs)))
	{
	    /* We got a match.  Try to replace the string. */
	    char repl[BUFSIZE];
	    char *subst = list->rep;
	    /* Assume we are doing regexp match for now; if any of the
	     * substitution fails, we will switch back to the straight
	     * string substitution.
	     */
	    is_regex_matching = 1;
	    for (i = j = 0; subst[i] && j < BUFSIZE - 1; i++) {
		/* I scans through RHS of sed-style substitution.
		 * j points at the string being built.
		 */
		if ((subst[i] == '\\') &&
		    ('0' <= subst[++i]) &&
		    (subst[i] <= '9')) 
		{
		    /* A backslash followed by a digit---regexp substitution.
		     * Note that a backslash followed by anything else is
		     * silently dropped (including a \\ sequence) and is
		     * passed on to the else clause.
		     */
		    int regno = subst[i] - '0';
		    int ct;
		    if (re->re_nsub <= regno) {
			/* Oops; this is a bad substitution.  Just give up
			 * and use straight string substitution for backward
			 * compatibility.
			 */
			is_regex_matching = 0;
			break;
		    }
		    for (ct = regs.beg[regno]; ct < regs.end[regno]; ct++)
			repl[j++] = tmp[ct];
		} else {
		    /* Either ordinary character, 
		     * or an unrecognized \ sequence.
		     * Just copy it.
		     */
		    repl[j++] = subst[i];
		}
	    }
	    if (is_regex_matching) {
		/* Good.  Regexp substitution worked and we now have a good
		 * string in repl.
		 * The part that matched and being replaced is 0 to mlen-1
		 * in tmp; tmp[mlen] through the end of it should be
		 * concatenated to the end of the resulting string.
		 */
		repl[j] = 0;
		strncpy(uri, repl, BUFSIZE - 1);
		strncpy(uri + j, tmp + mlen,
			BUFSIZE - (j + strlen(tmp + mlen)) - 1);
	    }
	    nmz_re_free_registers (&regs);
	}
	if (is_regex_matching) {
	    return 0;
	}
	/* Otherwise, we fall back to string substitution */

	npat = (int)strlen(list->pat);
	nrep = (int)strlen(list->rep);

	if (strncmp(list->pat, tmp, npat) == 0) {
	    strcpy(uri, list->rep);
	    for (i = npat, j = nrep; tmp[i] && j < BUFSIZE - 1 ; i++, j++) {
		uri[j] = tmp[i];
	    }
	    uri[j] = '\0';
	    return 1;
	}
	list = list->next;
    }
    return 0;
}

/* 
 * Add a new element to the end of `replaces' list.
 */ 
enum nmz_stat 
nmz_add_replace(const char *pat, const char *rep)
{
    struct nmz_replace *newp;
    
    newp = malloc(sizeof(struct nmz_replace));
    if (newp == NULL) {
	 nmz_set_dyingmsg(nmz_msg("%s", strerror(errno)));
	 return FAILURE;
    }

    newp->pat = malloc(strlen(pat) + 1);
    if (newp->pat == NULL) {
	 nmz_set_dyingmsg(nmz_msg("%s", strerror(errno)));
         free(newp);
	 return FAILURE;
    }

    newp->rep = malloc(strlen(rep) + 1);
    if (newp->rep == NULL) {
	 nmz_set_dyingmsg(nmz_msg("%s", strerror(errno)));
         free(newp->pat);
         free(newp);
	 return FAILURE;
    }

    newp->pat_re = ALLOC(struct re_pattern_buffer);
    MEMZERO((char *)newp->pat_re, struct re_pattern_buffer, 1);
    newp->pat_re->buffer = 0;
    newp->pat_re->allocated = 0;

    strcpy(newp->pat, pat);
    strcpy(newp->rep, rep);

    if (nmz_re_compile_pattern (newp->pat, strlen (newp->pat), newp->pat_re)) {
	/* Re_comp fails; set NULL to pat_re  */
	nmz_re_free_pattern(newp->pat_re);
	newp->pat_re = NULL;
    }

    newp->next = NULL;
    if (replaces == NULL) {
	replaces = newp;
    } else {
	struct nmz_replace *ptr = replaces;

	while (ptr->next != NULL) {
	    ptr  = ptr->next;
	}
	assert(ptr->next == NULL);
	ptr->next = newp;
    }

    return SUCCESS;
}

/*
 * It's very dangerous to use!
 */
struct nmz_replace *
nmz_get_replaces(void)
{
    return replaces;
}

