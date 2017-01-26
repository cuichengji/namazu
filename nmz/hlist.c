/*
 * 
 * hlist.c -
 * 
 * $Id: hlist.c,v 1.51.4.22 2008-03-06 15:38:08 opengl2772 Exp $
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
#include <math.h>

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

#include "libnamazu.h"
#include "util.h"
#include "hlist.h"
#include "field.h"
#include "var.h"
#include "idxname.h"
#include "search.h"
#include "query.h"
#include "score.h"

static int document_number = 0;  /* Number of documents covered in a target index */
static char field_for_sort[BUFSIZE] = "";  /* field_for_sort name used with sorting */

/*
 *
 * Private functions
 *
 */

static void memcpy_hlist(NmzResult, NmzResult, int);
static void set_rank(NmzResult);
static int  field_sort(NmzResult);
static int  field_scmp(const void*, const void*);
static int  field_ncmp(const void*, const void*);
static int  date_cmp(const void*, const void*);
static int  score_cmp(const void*, const void*);
static int  intcmp(int v1, int v2);

static void 
memcpy_hlist(NmzResult to, NmzResult from, int n)
{
    memcpy(to.data + n,  from.data,  from.num * sizeof (to.data[0]));
}

static void 
set_rank(NmzResult hlist)
{
    int i;

    /* Set rankings in descending order. */
    for (i = 0 ; i < hlist.num; i++) {
        hlist.data[i].rank = hlist.num - i;
    }
}

static int 
field_sort(NmzResult hlist) 
{
    int i, numeric = 1;

    for (i = 0; i < hlist.num; i++) {
	char buf[BUFSIZE];
	size_t leng;

	nmz_get_field_data(hlist.data[i].idxid, 
			   hlist.data[i].docid, field_for_sort, buf);
	nmz_chomp(buf);
	leng = strlen(buf);

	if (numeric == 1 && ! nmz_isnumstr(buf)) {
	    numeric = 0;
	}

	hlist.data[i].field = malloc(leng + 1);
	if (hlist.data[i].field == NULL) {
            int j;
            for (j = 0; j < i; j++) {
	        free(hlist.data[j].field);
	        hlist.data[j].field = NULL;
            }
	    nmz_set_dyingmsg(nmz_msg("%s", strerror(errno)));
	    return FAILURE;
	}
	strcpy(hlist.data[i].field, buf);
    } 

    if (numeric == 1) {
	qsort(hlist.data, hlist.num, sizeof(hlist.data[0]), field_ncmp);
	
    } else {
	qsort(hlist.data, hlist.num, sizeof(hlist.data[0]), field_scmp);
    }

    for (i = 0; i < hlist.num; i++) {
	free(hlist.data[i].field);
	hlist.data[i].field = NULL;
    }
    return 0;
}

/* 
 * Compare a pair of hlist.data[].field as string in descending order.
 */
static int 
field_scmp(const void *p1, const void *p2)
{
    struct nmz_data *v1, *v2;
    int r;

    v1 = (struct nmz_data *) p1;
    v2 = (struct nmz_data *) p2;

    r = strcmp(v2->field, v1->field);
    if (r == 0) {
	r = intcmp(v2->rank, v1->rank);
    }
    return r;
}

/* 
 * Compare a pair of hlist.data[].field as number in descending order.
 */
static int 
field_ncmp(const void *p1, const void *p2)
{
    struct nmz_data *v1, *v2;
    int r;

    v1 = (struct nmz_data *) p1;
    v2 = (struct nmz_data *) p2;

    r = intcmp(atoi(v2->field), atoi(v1->field));
    if (r ==0) {
	r = intcmp(v2->rank, v1->rank);
    }
    return r;
}


/* 
 * Compare a pair of hlist.data[].score as number in descending order.
 */
static int 
score_cmp(const void *p1, const void *p2)
{
    struct nmz_data *v1, *v2;
    int r;
    
    v1 = (struct nmz_data *) p1;
    v2 = (struct nmz_data *) p2;

    r = intcmp(v2->score, v1->score);
    if (r == 0) {
	r = intcmp(v2->rank, v1->rank);
    }
    return r;
    /* Return (r = v2->score - v1->score) ? r : v2->rank - v1->rank; */
}

/* 
 * Compare a pair of hlist.data[].date as number in descending order.
 */
static int 
date_cmp(const void *p1, const void *p2)
{
    struct nmz_data *v1, *v2;
    int r;

    v1 = (struct nmz_data *) p1;
    v2 = (struct nmz_data *) p2;

    r = intcmp(v2->date, v1->date);
    if (r == 0) {
	r = intcmp(v2->rank, v1->rank);
    } 
    return r;
}

/*
 * This is a safe routine for comparing two integers.  It
 * could be simply v1 - v2 but it would produce an incorrect
 * answer if v2 is large and positive and v1 is large and
 * negative or vice verse. 
 *
 * See page 36 of "The Practice of Programming" by Brian
 * W. Kernighan and Rob Pike for details.
 */
static int
intcmp(int v1, int v2)
{
    if (v1 < v2) {
	return -1;
    } else if (v1 == v2) {
	return 0;
    } else {
	return 1;
    }
}

/*
 *
 * Public functions
 *
 */

/*
 * Merge the left and  right with AND rule.
 */
NmzResult 
nmz_andmerge(NmzResult left, NmzResult right, int *ignore)
{
    int i, j, v;

    if (left.stat == ERR_TOO_MUCH_MATCH || left.stat == ERR_TOO_MUCH_HIT) {
	nmz_free_hlist(left);
	return right;
    }

    if (right.stat == ERR_TOO_MUCH_MATCH || right.stat == ERR_TOO_MUCH_HIT) {
	nmz_free_hlist(right);
	return left;
    }

    if (left.stat != SUCCESS || left.num <= 0) {
	nmz_free_hlist(right);
	return left;
    }
    if (right.stat != SUCCESS || right.num <= 0) {
	nmz_free_hlist(left);
	return right;
    }

    for (v = 0, i = 0, j = 0; i < left.num; i++) {
	for (;; j++) {
	    if (j >= right.num)
		goto OUT;
	    if (left.data[i].docid < right.data[j].docid)
		break;
	    if (left.data[i].docid == right.data[j].docid) {

                if (v != i) {
                    nmz_copy_hlist(left, v, left, i);
                }

                if (nmz_is_tfidfmode()) {
                    left.data[v].score = 
			left.data[i].score + right.data[j].score;
                } else {
                    /* Assign a smaller number, left or right*/
                    left.data[v].score = 
			left.data[i].score < right.data[j].score ?
                        left.data[i].score : right.data[j].score;
                }
		v++;
		j++;
		break;
	    }
	}
    }
  OUT:
    nmz_free_hlist(right);
    left.num = v;
    if (left.stat != SUCCESS || left.num <= 0)
	nmz_free_hlist(left);
    return left;
}


/*
 * Merge the left and  right with NOT rule.
 */
NmzResult 
nmz_notmerge(NmzResult left, NmzResult right, int *ignore)
{
    int i, j, v, f;

    if (ignore && *ignore && left.num > 0) {
	nmz_free_hlist(right);
	return left;
    }
    if (ignore && *ignore && right.num > 0) {
	nmz_free_hlist(left);
	return right;
    }

    if (right.stat != SUCCESS || right.num <= 0) {
	nmz_free_hlist(right);
	return left;
    }
    if (left.stat != SUCCESS || left.num <= 0) {
	nmz_free_hlist(right);
	return left;
    }

    for (v = 0, i = 0, j = 0; i < left.num; i++) {
	for (f = 0; j < right.num; j++) {
	    if (left.data[i].docid < right.data[j].docid)
		break;
	    if (left.data[i].docid == right.data[j].docid) {
		j++;
		f = 1;
		break;
	    }
	}
	if (!f) {
            if (v != i) {
	        nmz_copy_hlist(left, v, left, i);
            }
	    v++;
	}
    }
    nmz_free_hlist(right);
    left.num = v;
    if (left.stat != SUCCESS || left.num <= 0)
	nmz_free_hlist(left);
    return left;
}


/*
 * merge the left and  right with OR rule
 */
NmzResult 
nmz_ormerge(NmzResult left, NmzResult right)
{
    int i, j, v, n;
    NmzResult val;

    val.num  = 0;
    val.data = NULL;
    val.stat = SUCCESS;

    if ((left.stat  != SUCCESS || left.num <= 0) && 
	(right.stat != SUCCESS || right.num <= 0)) 
    {
	nmz_free_hlist(right);
	return left;
    }
    if (left.stat != SUCCESS || left.num <= 0) {
	nmz_free_hlist(left);
	return right;
    }
    if (right.stat != SUCCESS || right.num <= 0){
	nmz_free_hlist(right);
	return left;
    }

    n = left.num + right.num;

    nmz_malloc_hlist(&val, n);
    if (val.stat == ERR_FATAL) {
	nmz_free_hlist(left);
	nmz_free_hlist(right);
        return val;
    }

    for (v = 0, i = 0, j = 0; i < left.num; i++) {
	for (; j < right.num; j++) {
	    if (left.data[i].docid < right.data[j].docid) {
                break;
            } else if (left.data[i].docid == right.data[j].docid) {

                if (nmz_is_tfidfmode()) {
                    left.data[i].score = 
			left.data[i].score + right.data[j].score;
                } else {
                    /* Assign a large number, left or right */
                    left.data[i].score = 
			left.data[i].score > right.data[j].score ?
                        left.data[i].score : right.data[j].score;
                }
		j++;
		break;
	    } else {
		nmz_copy_hlist(val, v, right, j);
		v++;
	    }
	}
	nmz_copy_hlist(val, v, left, i);
	v++;
    }

    for (; j < right.num; j++) {
	nmz_copy_hlist(val, v, right, j);
	v++;
    }

    nmz_free_hlist(left);
    nmz_free_hlist(right);
    val.num = v;
    return val;
}

void 
nmz_malloc_hlist(NmzResult * hlist, int n)
{
    hlist->num  = 0;
    hlist->data = NULL;
    hlist->stat = SUCCESS;

    if (n <= 0) return;
    hlist->data = malloc(n * sizeof(struct nmz_data));
    if (hlist->data == NULL) {
	 nmz_set_dyingmsg(nmz_msg("%s", strerror(errno)));
	 hlist->stat = ERR_FATAL;
	 return;
    }

    hlist->num  = n;
    hlist->stat = SUCCESS;
}

void 
nmz_realloc_hlist(NmzResult * hlist, int n)
{
    if (hlist->stat != SUCCESS || n <= 0) return;
    hlist->data = realloc(hlist->data, n * sizeof(struct nmz_data));
    if (hlist->data == NULL) {
	 nmz_set_dyingmsg(nmz_msg("%s", strerror(errno)));
	 hlist->stat = ERR_FATAL;
    }
}

void 
nmz_free_hlist(NmzResult hlist)
{
    if (hlist.stat != SUCCESS || hlist.num <= 0) return;
    free(hlist.data);
}

void 
nmz_copy_hlist(NmzResult to, int n_to, NmzResult from, int n_from)
{
    to.data[n_to] = from.data[n_from];
}

void 
nmz_set_idxid_hlist(NmzResult hlist, int id)
{
    int i;
    for (i = 0; i < hlist.num; i++) {
        hlist.data[i].idxid = id;
    }
}

NmzResult 
nmz_merge_hlist(NmzResult *hlists)
{
    int i, n;
    NmzResult value;

    value.num  = 0;
    value.data = NULL;
    value.stat = SUCCESS;

    if (nmz_get_idxnum() == 1) {
	return hlists[0];
    }

    for(i = n = 0; i < nmz_get_idxnum(); i++) {
        if (hlists[i].stat == SUCCESS && hlists[i].num > 0) {
            n += hlists[i].num;
        }
    }
    nmz_malloc_hlist(&value, n);
    if (value.stat == ERR_FATAL) {
        for(i = 0; i < nmz_get_idxnum(); i++) {
            if (hlists[i].stat != SUCCESS || hlists[i].num <= 0)
                continue;
            nmz_free_hlist(hlists[i]);
        }
        return value;
    }

    for(i = n = 0; i < nmz_get_idxnum(); i++) {
        if (hlists[i].stat != SUCCESS || hlists[i].num <= 0) 
            continue;
        memcpy_hlist(value, hlists[i], n);
        n += hlists[i].num;
        nmz_free_hlist(hlists[i]);
    }
    value.stat = SUCCESS;
    value.num = n;
    return value;
}

/*
 * Get date info from NMZ.t and do the missing number processing.
 */
NmzResult 
nmz_do_date_processing(NmzResult hlist)
{
    FILE *date_index;
    int i, v;

    date_index = fopen(NMZ.t, "rb");
    if (date_index == NULL) {
	nmz_set_dyingmsg(nmz_msg("%s: %s", NMZ.t, strerror(errno)));
	hlist.stat = ERR_FATAL;
        return hlist; /* error */
    }

    for (i = 0; i < hlist.num; i++) {
        if (fseek(date_index,
                hlist.data[i].docid * sizeof(hlist.data[i].date), 0) != 0)
	{
	    nmz_set_dyingmsg(nmz_msg("%s: %s", NMZ.t, strerror(errno)));
	    hlist.stat = ERR_FATAL;
            fclose(date_index);
            return hlist; /* error */
        }
        nmz_fread(&hlist.data[i].date, 
		  sizeof(hlist.data[i].date), 1, date_index);
    }

    fclose(date_index);

    for (v = 0, i = 0; i < hlist.num; i++) {
        if (hlist.data[i].date == -1) {  
            /* The missing number, this document has been deleted */
        } else {
            if (v != i) {
                nmz_copy_hlist(hlist, v, hlist, i);
            }
            v++;
        }
    }
    hlist.num = v;

    return hlist;
}

/*
 * Get the hit list.
 */
NmzResult 
nmz_get_hlist(int index)
{
    NmzResult hlist;

    hlist.num  = 0;
    hlist.data = NULL;
    hlist.stat = SUCCESS;

    if (fseek(Nmz.i, nmz_getidxptr(Nmz.ii, index), 0) != 0) {
	hlist.stat = ERR_FATAL;
	return hlist; /* error */
    }

    {
        int n, *buf, i;
        double idf = 1.0;
	int sum = 0;
	int hit;
	int bersize;
	int totalsize;

        nmz_get_unpackw(Nmz.i, &bersize);

	hit = bersize;
	buf = malloc(hit * sizeof(int));
	if (buf == NULL) {
	    nmz_set_dyingmsg(nmz_msg("%s", strerror(errno)));
	    hlist.data = NULL;
	    hlist.stat = ERR_FATAL;
	    return hlist;
	}

        n = 0;
        totalsize = 0;
        while (totalsize < bersize) {
            totalsize += nmz_get_unpackw(Nmz.i, &buf[n]);
            n++;
        }
        n /= 2;

        if (nmz_is_tfidfmode() &&
	    (nmz_get_querytokennum() > 1
	     /* 0th token is a phrase. */
	     || strchr(nmz_get_querytoken(0), '\t') != NULL)) 
        {
            idf = log((double)document_number / n) / log(2);
	    nmz_debug_printf("idf: %f (N:%d, n:%d)\n", idf, document_number, n);
        }

	nmz_malloc_hlist(&hlist, n);
	if (hlist.stat == ERR_FATAL) {
	    free(buf);
	    return hlist;
        }
	
	for (i = 0; i < n; i++) {
	    hlist.data[i].docid = *(buf + i * 2) + sum;
	    sum = hlist.data[i].docid;
	    hlist.data[i].score = *(buf + i * 2 + 1);
	    if (nmz_is_tfidfmode()) {
		hlist.data[i].score = (int)(hlist.data[i].score * idf) + 1;
	    }
	}
        hlist.num = n;
	free(buf);
        hlist = nmz_do_date_processing(hlist);
    } 
    return hlist;
}


/*
 * Interface to do appropriate sorting.
 */
int 
nmz_sort_hlist(NmzResult hlist, enum nmz_sortmethod method)
{
    set_rank(hlist); /* conserve current order for STABLE sorting */

    if (method == SORT_BY_FIELD) {
	if (field_sort(hlist) != SUCCESS)
	    return FAILURE;
    } else if (method == SORT_BY_DATE) {
	qsort(hlist.data, hlist.num, sizeof(hlist.data[0]), date_cmp);
    } else if (method == SORT_BY_SCORE) {
	qsort(hlist.data, hlist.num, sizeof(hlist.data[0]), score_cmp);
    } 
    return 0;
}

/* 
 * Reverse the given hlist.
 * original of this routine was contributed by Furukawa-san [1997-11-13]
 */
int 
nmz_reverse_hlist(NmzResult hlist)
{
    int m, n;
    struct nmz_data tmp;

    m = 0;
    n = hlist.num - 1;
    while (m < n) {
        /* swap */
        tmp = hlist.data[m];
        hlist.data[m] = hlist.data[n];
        hlist.data[n] = tmp;

        m++;
        n--;
    }

    return 0;
}

void 
nmz_set_docnum(int n)
{
    document_number = n;
}

void 
nmz_set_sortfield(const char *field)
{
    strncpy(field_for_sort, field, BUFSIZE - 1);
    field_for_sort[BUFSIZE - 1] = '\0';
}

char *
nmz_get_sortfield(void)
{
    return field_for_sort;
}

int
nmz_get_docnum()
{
    return document_number;
}
