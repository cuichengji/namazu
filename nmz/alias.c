/*
 * 
 * alias.c - 
 *
 * $Id: alias.c,v 1.15.8.5 2008-03-06 14:47:31 opengl2772 Exp $
 * 
 * Copyright (C) 1997-1999 Satoru Takabayashi All rights reserved.
 * Copyright (C) 2000-2008 Namazu Project All rights reserved.
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

#ifdef HAVE_ERRNO_H
#  include <errno.h>
#endif

#include <assert.h>

#ifdef HAVE_STRING_H
#  include <string.h>
#else
#  include <strings.h>
#endif

#include "alias.h"
#include "util.h"
#include "libnamazu.h"
#include "i18n.h"

static struct nmz_alias  *aliases  = NULL;

/*
 *
 * Public functions
 *
 */

/* 
 * Add a new element to the end of `aliases' list.
 */ 
enum nmz_stat 
nmz_add_alias(const char *alias, const char *real)
{
    struct nmz_alias *newp;

    newp = malloc(sizeof(struct nmz_alias));
    if (newp == NULL) {
	 nmz_set_dyingmsg(nmz_msg("%s", strerror(errno)));
	 return FAILURE;
    }
    newp->alias = malloc(strlen(alias) + 1);
    if (newp->alias == NULL) {
	 nmz_set_dyingmsg(nmz_msg("%s", strerror(errno)));
         free(newp);
	 return FAILURE;
    }

    newp->real = malloc(strlen(real) + 1);
    if (newp->real == NULL) {
	 nmz_set_dyingmsg(nmz_msg("%s", strerror(errno)));
         free(newp->alias);
         free(newp);
	 return FAILURE;
    }

    strcpy(newp->alias, alias);
    strcpy(newp->real, real);

    newp->next = NULL;
    if (aliases == NULL) {
	aliases = newp;
    } else {
	struct nmz_alias *ptr = aliases;

	while (ptr->next != NULL) {
	    ptr  = ptr->next;
	}
	assert(ptr->next == NULL);
	ptr->next = newp;
    }

    return SUCCESS;
}

void 
nmz_free_aliases(void)
{
    struct nmz_alias *list, *next;
    list = aliases;

    while (list) {
	next = list->next;
	free(list->alias);
	free(list->real);
	free(list);
	list = next;
    }
}

/*
 * It's very dangerous to use!
 */
struct nmz_alias *
nmz_get_aliases(void)
{
    return aliases;
}
