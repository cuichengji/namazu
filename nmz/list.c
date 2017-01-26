/*
 * 
 * list.c - 
 *
 * $Id: list.c,v 1.1.4.3 2008-03-06 15:38:09 opengl2772 Exp $
 * 
 * Copyright (C) 2007-2008 Tadamasa Teranishi All rights reserved.
 *               2007-2008 Namazu Project All rights reserved.
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

#include "list.h"
#include "util.h"

#define HANDLE_TYPE_MASK_NONE      0xFFFFFFFF
#define HANDLE_TYPE_MASK_LIST      0xFF0000FF
#define HANDLE_TYPE_MASK_STRLIST   0xFFFF00FF
#define HANDLE_TYPE_LIST           0xF10000D2
#define HANDLE_TYPE_STRLIST        (0x00810000 | HANDLE_TYPE_LIST)
#define HANDLE_TYPE_DOUBLE_STRLIST (0x00004200 | HANDLE_TYPE_STRLIST)
#define HANDLE_TYPE_SINGLE_STRLIST (0x0000EF00 | HANDLE_TYPE_STRLIST)
#define HANDLE_TYPE_ALREADY_FREE   0xF7C1E382	

#define check_handle_type(t, m, x)	\
{					\
    struct _base_handle  *bh;		\
					\
    bh = (struct _base_handle *)x;	\
    assert(bh != NULL);			\
    assert((bh->type & m) == t);	\
}

/*
 *
 * ex)
 *
 * new:(double)
 *   NMZ_HANDLE handle;
 *   handle = nmz_create_strlist(
 *       NMZ_STRLIST_KEY_CASE_INSENSITIVE
 *   );
 *
 * new:(single)
 *   NMZ_HANDLE handle;
 *   handle = nmz_create_strlist(
 *       NMZ_STRLIST_SINGLE |
 *       NMZ_STRLIST_VALUE_CASE_INSENSITIVE
 *   );
 *
 * delete:
 *   nmz_free_hadle(handle);
 *
 * clear:
 *   nmz_clear_handle(handle);
 *
 * add:(double)
 *   nmz_add_strlist(handle, key, value);
 *
 * add:(single)
 *   nmz_add_single_strlist(handle, value);
 *
 * access:
 *   nmz_first_list(handle);
 *   key = nmz_get_key_strlist(handle);
 *   value = nmz_get_value_strlist(handle);
 *
 *   while(nmz_next_list(handle)) {
 *       key = nmz_get_key_strlist(handle);
 *       value = nmz_get_value_strlist(handle);
 *   }
 *
 * search:(double)
 *   if ((value = nmz_find_first_strlist(handle, key))) {
 *       // find 1st value.
 *       while((value = nmz_find_next_strlist(handle, key)) {
 *           // find
 *       }
 *   }
 *
 */

static int _is_support_handle_type(NMZ_HANDLE handle);
static void _clear_strlist(NMZ_HANDLE handle);
static void _freeall_strlist(NMZ_HANDLE handle);
static void _free_single_str_node(void *x);
static void _free_double_str_node(void *x);

/*
 *
 * HANDLE
 *
 */

struct _base_handle {
    unsigned int type;
    void (*clear)(NMZ_HANDLE handle);
    void (*freeall)(NMZ_HANDLE handle);
    void (*freenode)(void *p);
};

/*
 *
 * BASE LIST
 *
 */

struct _node {
    struct _node *next;         /* It must be the first member */
};

typedef struct _base_list {
    struct _base_handle common; /* It must be the first member */
    struct _node *current_node;
    struct _node *head;
    int          num;
} _BASELIST;

/*
 *
 * STRING LIST
 *
 */

struct _single_str_node {
    struct _single_str_node *next; /* It must be the first member */
    char *value;
};

struct _double_str_node {
    struct _double_str_node *next; /* It must be the first member */
    char *value;                   /* do not modify */
    char *key;
};

typedef struct _str_list {
    _BASELIST baselist; /* It must be the first member */

    unsigned int config;
    struct _node *tail;

    struct _node *current_find;
    int (*cmp)();
} _STRLIST;


/*
 *
 * Static functions
 *
 */

static int
_is_support_handle_type(NMZ_HANDLE handle)
{
    struct _base_handle  *bh;

    if (handle == (NMZ_HANDLE)0) {
        return 0;
    }

    bh = (struct _base_handle *)handle;
    if (bh->type == HANDLE_TYPE_DOUBLE_STRLIST ||
        bh->type == HANDLE_TYPE_SINGLE_STRLIST
    ) {
        return 1;
    }
    return 0;
}

/*
 *
 * Public functions
 *
 * GENERIC LIST
 *
 */
enum nmz_stat
nmz_first_list(NMZ_HANDLE handle)
{
    _BASELIST *baselist;

    check_handle_type(HANDLE_TYPE_LIST, HANDLE_TYPE_MASK_LIST, handle);
    baselist = (_BASELIST *)handle;

    baselist->current_node = baselist->head;
    if (baselist->current_node == NULL) {
        return FAILURE;
    }
    return SUCCESS;
}

enum nmz_stat
nmz_next_list(NMZ_HANDLE handle)
{
    _BASELIST *baselist;

    check_handle_type(HANDLE_TYPE_LIST, HANDLE_TYPE_MASK_LIST, handle);
    baselist = (_BASELIST *)handle;
    if (baselist->current_node == NULL) {
        return FAILURE;
    }

    baselist->current_node = baselist->current_node->next;
    if (baselist->current_node == NULL) {
        return FAILURE;
    }
    return SUCCESS;
}

/*
 *
 * Public functions
 *
 * STRING LIST
 *
 */

static void
_free_single_str_node(void *x)
{
    struct _single_str_node *p = (struct _single_str_node *)x;

    if (p == NULL) {
        return;
    }

    free(p->value);
    p->value = NULL;
}

static void
_free_double_str_node(void *x)
{
    struct _double_str_node *p = (struct _double_str_node *)x;

    if (p == NULL) {
        return;
    }

    free(p->key);
    p->key = NULL;
    free(p->value);
    p->value = NULL;
}

NMZ_HANDLE
nmz_create_strlist(unsigned int config)
{
    _STRLIST *list;

    if ((list = (_STRLIST *)calloc(sizeof(_STRLIST), 1)) == NULL) {
        return (NMZ_HANDLE)0;
    }

    if (config & NMZ_STRLIST_SINGLE) {
        list->baselist.common.type = HANDLE_TYPE_SINGLE_STRLIST;
        list->baselist.common.clear = _clear_strlist;
        list->baselist.common.freeall = _freeall_strlist;
        list->baselist.common.freenode = _free_single_str_node;
    } else {
        list->baselist.common.type = HANDLE_TYPE_DOUBLE_STRLIST;
        list->baselist.common.clear = _clear_strlist;
        list->baselist.common.freeall = _freeall_strlist;
        list->baselist.common.freenode = _free_double_str_node;
    }
    list->baselist.num = 0;
    list->baselist.head = NULL;
    list->baselist.current_node = NULL;

    list->config = config;
    list->tail = NULL;
    list->current_find = NULL;

    if (list->config & NMZ_STRLIST_KEY_CASE_INSENSITIVE) {
        list->cmp = strcasecmp;
    } else {
        list->cmp = strcmp;
    }

    return (NMZ_HANDLE)list;
}

static void
_clear_strlist(NMZ_HANDLE handle)
{
    struct _single_str_node *p;
    _STRLIST *list;

    check_handle_type(HANDLE_TYPE_STRLIST, HANDLE_TYPE_MASK_STRLIST, handle);
    list = (_STRLIST *)handle;

    p = (struct _single_str_node *)list->baselist.head;
    while(p) {
        struct _single_str_node *old;

        list->baselist.common.freenode(p);
        old = p;
        p = p->next;
        free(old);
    }

    list->baselist.num = 0;
    list->baselist.head = NULL;
    list->baselist.current_node = NULL;

    list->tail = NULL;
    list->current_find = NULL;
}

static void
_freeall_strlist(NMZ_HANDLE handle)
{
    _STRLIST *list;

    if (handle == (NMZ_HANDLE)0) {
        return;
    }

    check_handle_type(HANDLE_TYPE_STRLIST, HANDLE_TYPE_MASK_STRLIST, handle);
    list = (_STRLIST *)handle;

    _clear_strlist(handle);

    list->baselist.common.type = HANDLE_TYPE_ALREADY_FREE;
    free(list);
}

/*
 * Add a new element to the end of list.
 */
enum nmz_stat
nmz_add_single_strlist(NMZ_HANDLE handle, const char *value)
{
    struct _single_str_node *newp;
    _STRLIST *list;

    check_handle_type(HANDLE_TYPE_SINGLE_STRLIST, HANDLE_TYPE_MASK_NONE, handle);
    list = (_STRLIST *)handle;

    newp = malloc(sizeof(struct _single_str_node));
    if (newp == NULL) {
        nmz_set_dyingmsg(nmz_msg("%s", strerror(errno)));
        return FAILURE;
    }
    if ((newp->value = strdup(value)) == NULL) {
        nmz_set_dyingmsg(nmz_msg("%s", strerror(errno)));
        free(newp);
        return FAILURE;
    }

    if (list->config & NMZ_STRLIST_VALUE_CASE_INSENSITIVE) {
        nmz_strlower(newp->value);
    }

    newp->next = NULL;
    if (list->baselist.head == NULL) {
        list->baselist.head = (struct _node *)newp;
        list->tail = (struct _node *)newp;
        list->baselist.num = 1;
    } else {
        assert(list->tail != NULL);

        list->tail->next = (struct _node *)newp;
        list->tail = (struct _node *)newp;
        list->baselist.num++;
    }

    return SUCCESS;
}

enum nmz_stat
nmz_add_strlist(NMZ_HANDLE handle, const char *key, const char *value)
{
    struct _double_str_node *newp;
    _STRLIST *list;

    check_handle_type(HANDLE_TYPE_DOUBLE_STRLIST, HANDLE_TYPE_MASK_NONE, handle);
    list = (_STRLIST *)handle;

    newp = malloc(sizeof(struct _double_str_node));
    if (newp == NULL) {
        nmz_set_dyingmsg(nmz_msg("%s", strerror(errno)));
        return FAILURE;
    }
    if ((newp->key = strdup(key)) == NULL) {
        nmz_set_dyingmsg(nmz_msg("%s", strerror(errno)));
        free(newp);
        return FAILURE;
    }
    if ((newp->value = strdup(value)) == NULL) {
        nmz_set_dyingmsg(nmz_msg("%s", strerror(errno)));
        free(newp->key);
        free(newp);
        return FAILURE;
    }

    if (list->config & NMZ_STRLIST_KEY_CASE_INSENSITIVE) {
        nmz_strlower(newp->key);
    }
    if (list->config & NMZ_STRLIST_VALUE_CASE_INSENSITIVE) {
        nmz_strlower(newp->value);
    }

    newp->next = NULL;
    if (list->baselist.head == NULL) {
        list->baselist.head = (struct _node *)newp;
        list->tail = (struct _node *)newp;
        list->baselist.num = 1;
    } else {
        assert(list->tail != NULL);

        if (!(list->config & NMZ_STRLIST_KEY_DUPLICATE)) {
            struct _double_str_node *p = 
                (struct _double_str_node *)list->baselist.head;
            while(p) {
                if (!list->cmp(p->key, key)) {
                    free(p->value);
                    p->value = newp->value;
                    free(newp->key);
                    free(newp);
                    return SUCCESS;
                }
                p = p->next;
            }
        }

        list->tail->next = (struct _node *)newp;
        list->tail = (struct _node *)newp;
        list->baselist.num++;
    }

    return SUCCESS;
}

char *
nmz_get_key_strlist(NMZ_HANDLE handle)
{
    _STRLIST *list;

    check_handle_type(HANDLE_TYPE_DOUBLE_STRLIST, HANDLE_TYPE_MASK_NONE, handle);
    list = (_STRLIST *)handle;
    if (list->baselist.current_node == NULL) {
        return NULL;
    }

    return ((struct _double_str_node *)list->baselist.current_node)->key;
}

char *
nmz_get_value_strlist(NMZ_HANDLE handle)
{
    _STRLIST *list;

    /* SINGLE & DOUBLE */
    check_handle_type(HANDLE_TYPE_STRLIST, HANDLE_TYPE_MASK_STRLIST, handle);
    list = (_STRLIST *)handle;
    if (list->baselist.current_node == NULL) {
        return NULL;
    }

    return ((struct _single_str_node *)list->baselist.current_node)->value;
}

char *
nmz_find_first_strlist(NMZ_HANDLE handle, const char *key)
{
    struct _double_str_node *p;
    _STRLIST *list;

    check_handle_type(HANDLE_TYPE_DOUBLE_STRLIST, HANDLE_TYPE_MASK_NONE, handle);
    list = (_STRLIST *)handle;
    if (list->baselist.head == NULL) {
        return NULL;
    }

    p = (struct _double_str_node *)list->baselist.head;
    while(p) {
        if (!list->cmp(p->key, key)) {
            list->current_find = (struct _node *)p;
            return p->value;
        }
        p = p->next;
    }
    
    return NULL;
}

char *
nmz_find_next_strlist(NMZ_HANDLE handle, const char *key)
{
    struct _double_str_node *p;
    _STRLIST *list;

    check_handle_type(HANDLE_TYPE_DOUBLE_STRLIST, HANDLE_TYPE_MASK_NONE, handle);
    list = (_STRLIST *)handle;
    if (list->current_find == NULL) {
        return NULL;
    }

    p = (struct _double_str_node *)list->current_find->next;
    while(p) {
        if (!list->cmp(p->key, key)) {
            list->current_find = (struct _node *)p;
            return p->value;
        }
        p = p->next;
    }
    
    return NULL;
}

/*
 *
 * Public functions
 *
 * HANDLE
 *
 */

void
nmz_clear_strlist(NMZ_HANDLE handle)
{
    struct _base_handle  *bh;

    if (handle == (NMZ_HANDLE)0) {
        return;
    }

    bh = (struct _base_handle *)handle;
    if (_is_support_handle_type(handle)) {
        assert(bh->clear);
        bh->clear(handle);
    } else {
        /* other type */
        nmz_warn_printf("Not support type HANDLE(0x%x).", bh->type);
    }
}

void
nmz_free_handle(NMZ_HANDLE handle)
{
    struct _base_handle  *bh;

    if (handle == (NMZ_HANDLE)0) {
        return;
    }

    bh = (struct _base_handle *)handle;
    if (_is_support_handle_type(handle)) {
        assert(bh->freeall);
        bh->freeall(handle);
    } else {
        /* other type */
        nmz_warn_printf("Not support type HANDLE(0x%x).", bh->type);
    }
}
