#ifndef _NAMAZU_H
#define _NAMAZU_H

#include "libnamazu.h" /* for enum nmz_stat */

enum {
    PAGE_MAX            = 20,  /* Max number of result pages */
    RESULT_MAX          = 100, /* Max number of result displays at once */
    CGI_QUERY_MAX       = 512, /* Max length of a CGI query */
				/* If you want to customize the paramater, */
				/* it MUST be smaller than BUFSIZE. */
				/* BUFSIZE is defined in libnamazu.h */
    CGI_INDEX_NAME_MAX  = 64,  /* Max length of an index name in a CGI query */
    CGI_RESULT_NAME_MAX = 64,  /* Max length of a result name in a CGI query */

    SUICIDE_TIME = 60      /* namazu.cgi will suicide when its
			      processing time exceeds this */
};

extern enum nmz_stat namazu_core ( char * query, char *subquery );
extern void exit_nmz(int status);
void set_templatedir(char *dir);
char *get_templatedir(void);

#endif /* _NAMAZU_H */
