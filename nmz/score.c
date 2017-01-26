/*
 * 
 * score.c - scoring-related functions of Namazu
 * 
 * $Id: score.c,v 1.3.4.12 2008-03-06 15:38:09 opengl2772 Exp $
 * 
 * Copyright (C) 2001 Hajime BABA  All rights reserved.
 * Copyright (C) 2001-2008 Namazu Project All rights reserved.
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

/* #define SCORE_C_DEBUG    / * for internal use only */

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
#include <time.h>

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
#include "replace.h"
#include "score.h"


/*
 *
 * Static variables
 *
 */

/* Default setting.  NOTE: all of them set FALSE except for IDF factor. */
static int use_idf_factor = 1;
static int use_doclength_factor = 0;
static int use_freshness_factor = 0;
static int use_urilength_factor = 0;

/* Typical document length (bytes).  which is a typical value on the web. */
static int score_doclength = 10000;

/* Typical halflife time (seconds).  93,312,000 s equals 36 months. */
static int score_freshness = 93312000;

/* Typical URI length.  This is an a-priori value. */
static int score_urilength = 1;


/*
 *
 * Private functions
 *
 */

static void 
make_fullpathname_field(int n)
{
    char *base;

    base = nmz_get_idxname(n);
    nmz_pathcat(base, NMZ.field);
}

/* open NMZ.field.size */
static int
get_field_size(int docid, int idxid)
{
    FILE *fp_field, *fp_field_idx;
    char fname[BUFSIZE] = "", buf[BUFSIZE];
    int size;
    
    /* Make a pathname */
    make_fullpathname_field(idxid);
    strncpy(fname, NMZ.field, BUFSIZE - 1);
    strncat(fname, "size", BUFSIZE - strlen(fname) - 1);

    fp_field = fopen(fname, "rb");
    if (fp_field == NULL) {
        nmz_debug_printf("%s: %s", fname, strerror(errno));
        return 0;
    }
    strncat(fname, ".i", BUFSIZE - strlen(fname) - 1);
    fp_field_idx = fopen(fname, "rb");
    if (fp_field_idx == NULL) {
        nmz_warn_printf("%s: %s", fname, strerror(errno));
        fclose(fp_field_idx);
	return 0;
    }

    fseek(fp_field, nmz_getidxptr(fp_field_idx, docid), 0);
    fgets(buf, sizeof(buf), fp_field);
    nmz_chomp(buf);
    sscanf(buf, "%d", &size);
    fclose(fp_field);
    fclose(fp_field_idx);

    return size;
}

/* We can use hlist.d.date instead of get_field_time(), so commented out. */
#if 0
/* open NMZ.t */
static int
get_field_time(int docid, int idxid)
{
    FILE *fp_field;
    char fname[BUFSIZE] = "";
    unsigned int t;
    
    /* Make a pathname */
    make_fullpathname_field(idxid);
    strncpy(fname, NMZ.t, BUFSIZE - 1);
    strncat(fname, "\0", BUFSIZE - strlen(fname) - 1);

    fp_field = fopen(fname, "rb");
    if (fp_field == NULL) {
        nmz_debug_printf("%s: %s", fname, strerror(errno));
        return 0;
    }

    fseek(fp_field, sizeof(int)*docid, 0);
    nmz_fread(&t, sizeof(int), 1, fp_field);
    fclose(fp_field);

    return t;
}
#endif

/* open NMZ.field.uri */
static void
get_field_uri(char *uri, int docid, int idxid)
{
    FILE *fp_field, *fp_field_idx;
    char fname[BUFSIZE] = "", buf[BUFSIZE];
    
    /* Make a pathname */
    make_fullpathname_field(idxid);
    strncpy(fname, NMZ.field, BUFSIZE - 1);
    strncat(fname, "uri", BUFSIZE - strlen(fname) - 1);

    fp_field = fopen(fname, "rb");
    if (fp_field == NULL) {
        nmz_debug_printf("%s: %s", fname, strerror(errno));
        return;
    }
    strncat(fname, ".i", BUFSIZE - strlen(fname) - 1);
    fp_field_idx = fopen(fname, "rb");
    if (fp_field_idx == NULL) {
        nmz_warn_printf("%s: %s", fname, strerror(errno));
        fclose(fp_field_idx);
	return;
    }

    fseek(fp_field, nmz_getidxptr(fp_field_idx, docid), 0);
    fgets(buf, sizeof(buf), fp_field);
    nmz_chomp(buf);
    sscanf(buf, "%s", uri);
    fclose(fp_field);
    fclose(fp_field_idx);
}


/* IDF must be calculated in nmz/hlist.c::nmz_get_hlist() */
#if 0
/* IDF: Inversed Document Frequency */
static double
get_idf(int n) {
    double idf = 1.0;
    int docnum;

    docnum = nmz_get_docnum(); /* the number of total documents */

    if ((nmz_get_querytokennum() > 1) ||
	 /* 0th token is a phrase. */
	(strchr(nmz_get_querytoken(0), '\t') != NULL)) {
	idf = log((double)docnum / (double)n) / log(2);
    }

#ifdef SCORE_C_DEBUG
    nmz_debug_printf("idf: %f (N:%d, n:%d)\n", idf, docnum, n);
#endif

    return idf;
}
#endif


/*
 * Dumping factor f(x) = 1/sqrt(x/x0 + delta), where x > 0.
 * If x0 = 10000 (default), factor table is as follows:
 *
 * size     factor
 * ===============
 * 1        9.9504
 * 10       9.5346
 * 100      7.0711
 * 1000     3.0151
 * 10000    0.9950
 * 100000   0.3161
 * 1000000  0.1000
 * 10000000 0.0316
 *
 * NOTE: This factor function is derived empirically.
 *
 * NOTE#2: To tell the truth, we had better to use the total number
 * of keywords in a document instead of the document length,
 * for the purpose of strict keyword weighting.
 *
 */
static double
get_doclength_factor(int size)
{
    double factor = 1.0;
    /* need to add delta in order to avoid illegal division by zero */
    double delta = 0.01;
    double x, x0;

    x = (double)size;
    x0 = (double)score_doclength;
    factor = 1.0 / sqrt(x/x0 + delta);

#ifdef SCORE_C_DEBUG
    nmz_debug_printf("factor: %.3lf, size: %d\n", factor, size);
#endif
    return factor;
}


/*
 * Dumping factor f(t) = lambda * 2**(-lambda*t/t0), where x > 0.
 *
 * If lastupdate is now, the factor equals 2.0.
 * If lastupdate is 18 month ago, the factor equals 1.0.
 * If lastupdate is 36 month ago, the factor equals 0.5.
 * Every factor is reduced by half with halflife (18 months).
 *
 * NOTE: This factor function is derived from Moore's Law.
 *
 */
static double
get_freshness_factor(int date)
{
    double factor = 1.0;
    double lambda = 2.0;
    double t, t0, power;
    time_t tmp_t;

    t= (double)((int)time(&tmp_t) - date);
    t0 = (double)score_freshness;
    power = - lambda * t / t0;
    factor = lambda * pow(2.0, power);

#ifdef SCORE_C_DEBUG
    nmz_debug_printf("factor: %.3lf, time: %d\n", factor, (int)t);
#endif
    return factor;
}


/*
 * WARNING: Far from the three preceding accomplished functions, 
 * this function is quite cheap, rough, crude, and unsophisticated. :-(
 * However the URI heuristics works good from time to time, so that
 * we provide it tentatively.
 *
 * factor  URI
 * ==================================
 * 2.0     http://www.example.jp/
 * 1.7     http://www.example.jp/a/
 * 1.5     http://www.example.jp/a/b/
 * 1.2     http://www.example.jp/a/b/c/
 * 1.0     http://www.example.jp/a/b/c/d/
 *
 * NOTE: This factor function is derived empirically.
 *
 */
static double
get_urilength_factor(char *uri)
{
    double factor = 1.0;
    int nsep = 0;
    char *tmp, *tmp2;

    nmz_replace_uri(uri);
    tmp = strdup(uri);
    if (tmp == NULL) {
	nmz_set_dyingmsg(nmz_msg("%s", strerror(errno)));
	return factor;
    }
    while ((tmp = strchr(tmp, '/')) != NULL) {
	nsep++;
	tmp++;
    }
    nsep -= 3;

    if (nsep < 1) {
	factor = 2.0*score_urilength;
    } else if (nsep == 1) {
	factor = 1.7*score_urilength;
    } else if (nsep == 2) {
	factor = 1.5*score_urilength;
    } else if (nsep == 3) {
	factor = 1.2*score_urilength;
    } else if (nsep >= 4) {
	factor = 1.0*score_urilength;
    }

    /* a-priori asuumption */
    tmp2 = strrchr(uri, '/');
    if (strcasecmp(tmp2, "/index.html") == 0 ||
	strcasecmp(tmp2, "/index.htm") == 0 ||
	strcasecmp(tmp2, "/") == 0) {
	factor *= 2.0;
    }

#ifdef SCORE_C_DEBUG
    nmz_debug_printf("factor: %.3lf, uri: %s\n", factor, uri);
#endif
    return factor;
}



/*
 * QDS (Query Derived Score) is affected by each queries.
 * It is variable, and NOT intrinsic to each documents.
 */
static double
calc_query_derived_score(struct nmz_data d)
{
    double qds = 0.0;
    double doclength_factor = 1.0;
    
    if (use_doclength_factor) {
	int size = get_field_size(d.docid, d.idxid);
	doclength_factor = get_doclength_factor(size);
    }
    /* NOTE: d.score is derived in nmz/hlist.c (nmz_get_hlist). */
    qds = (double)d.score * doclength_factor;

    return qds;
}


/*
 * DIS (DocID Intrinsic Score) is NOT affected by each queries.
 * It is constant, and intrinsic to each documents.
 */
static double
calc_docid_intrinsic_score(struct nmz_data d)
{
    double dis = 0.0;
    double freshness_factor, urilength_factor;

    freshness_factor = urilength_factor = 1.0;

    /* calculate each factors */
    if (use_freshness_factor) {
	/* int date = get_field_date(d.docid, d.idxid); */
	freshness_factor = get_freshness_factor(d.date);
    }
    if (use_urilength_factor) {
	char uri[BUFSIZE];
	get_field_uri(uri, d.docid, d.idxid);
	urilength_factor = get_urilength_factor(uri);
    }

    /* NOTE: Need to more study for more fairly good scoring. */
    dis = freshness_factor* urilength_factor;

    return dis;
}


/*
 *
 * Public functions
 *
 */

/* Score recomputation.  Must be invoked before score sort: nmz/search.c. */
void
nmz_recompute_score(NmzResult *hlist)
{
    int *orig;
    double *qds, *dis;
    double sum_qds, sum_dis;
    double qds_dis_ratio = 1.0;
    int i;
    
    orig = malloc(sizeof(int) * hlist->num);
    if (orig == NULL) {
	 nmz_set_dyingmsg(nmz_msg("%s", strerror(errno)));
	 return;
    }
    qds =  malloc(sizeof(double) * hlist->num);
    if (qds == NULL) {
	 nmz_set_dyingmsg(nmz_msg("%s", strerror(errno)));
         free(orig);
	 return;
    }
    dis =  malloc(sizeof(double) * hlist->num);
    if (dis == NULL) {
	 nmz_set_dyingmsg(nmz_msg("%s", strerror(errno)));
         free(orig);
         free(qds);
	 return;
    }
    
    /*
     * Now we suppose that the real score consists of QDS and DIS.  
     * The former, QDS (Query Derived Score), is affected by each queries.
     * It is variable, and NOT intrinsic to each documents.
     * And the latter, DIS (DocID Intrinsic Score), is NOT affected by
     * each queries.  It is constant, and intrinsic to each documents.
     */
    sum_qds = sum_dis = 0.0;
    for (i=0; i<hlist->num; i++) {
	orig[i] = hlist->data[i].score;
	qds[i] = calc_query_derived_score(hlist->data[i]);
	dis[i] = calc_docid_intrinsic_score(hlist->data[i]);
	sum_qds += qds[i];
	sum_dis += dis[i];
    }

    /* 
     * The most proper way to add two scores of QDS and DIS we think
     * is to balance the ratio of total amount of both scores.
     * However, if you don't think this strategy (or hypothesis) is fairly
     * good, you can easily multiple some other factor which you want.
     */
    if (use_freshness_factor || use_urilength_factor) {
	qds_dis_ratio = (double)sum_qds / (double)sum_dis;
    } else {
	qds_dis_ratio = 0.0;
    }

    /* Restore new score into original hlist */
    for (i=0; i<hlist->num; i++) {
	/* Multiple qds_dis_ratio to balance each scores */
	hlist->data[i].score = (int)(qds[i] + qds_dis_ratio * dis[i]);

	nmz_debug_printf("orig: %4d, recompute: %4d (qds: %.1f, dis: %.1f)\n",
			 orig[i], hlist->data[i].score, qds[i],
			 qds_dis_ratio * dis[i]);
    }

    free(orig);
    free(qds);
    free(dis);
}


/* Parse directive in namazurc.  Invoked from src/rcfile.c. */
void
nmz_set_scoring(const char *str)
{
    if (strcasecmp(str, "DEFAULT") == 0 ||
	strcmp(str, "") == 0) { /* default */
	use_idf_factor = 1;
	use_doclength_factor = 0;
	use_freshness_factor = 0;
	use_urilength_factor = 0;
    } else if (strcasecmp(str, "ALL") == 0) {
	use_idf_factor = 1;
	use_doclength_factor = 1;
	use_freshness_factor = 1;
	use_urilength_factor = 1; /* experimental. use at your own risk. */
    } else {
	char *tmp = strdup(str);
	while (1) {
	    if (strncasecmp(tmp, "TFIDF", 5) == 0) {
		use_idf_factor = 1;
	    } else if (strncasecmp(tmp, "SIMPLE", 6) == 0) {
		use_idf_factor = 0;
	    } else if (strncasecmp(tmp, "DOCLENGTH", 9) == 0) {
		use_doclength_factor = 1;
	    } else if (strncasecmp(tmp, "FRESHNESS", 9) == 0) {
		use_freshness_factor = 1;
	    } else if (strncasecmp(tmp, "URILENGTH", 9) == 0) {
		use_urilength_factor = 1;
	    }

	    if ((tmp = strchr(tmp, '|')) != NULL) {
		tmp++;
	    } else {
		break;
	    }
	}
    }

    nmz_debug_printf("Scoring: tfidf: %d, dl: %d, freshness: %d, uri: %d\n",
		     use_idf_factor, use_doclength_factor,
		     use_freshness_factor, use_urilength_factor);
}

int
nmz_is_tfidfmode(void)
{
    return use_idf_factor;
}

void
nmz_set_tfidfmode (int mode)
{
    const char *scoring_method[2]= {"SIMPLE", "TFIDF"};
    
    if ((mode < 0) || (mode > 1))
        return;
    
    nmz_set_scoring(scoring_method[mode]);
}

void
nmz_set_doclength(char *str)
{
    sscanf(str, "%d", &score_doclength);
}

void
nmz_set_freshness(char *str)
{
    sscanf(str, "%d", &score_freshness);
}

void
nmz_set_urilength(char *str)
{
    sscanf(str, "%d", &score_urilength);
}

