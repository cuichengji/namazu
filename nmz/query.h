#ifndef _QUERY_H
#define _QUERY_H

extern enum nmz_stat nmz_make_query(const char *querystring);
extern int nmz_get_querytokennum(void);
char *nmz_get_querytoken(int id);

#endif /* _QUERY_H */
