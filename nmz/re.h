#ifndef _RE_H
#define _RE_H

#include "libnamazu.h" /* for NmzResult struct */

#define ALLOC_N(type,n) (type*)nmz_xmalloc(sizeof(type)*(n))
#define ALLOC(type) (type*)nmz_xmalloc(sizeof(type))
#define MEMZERO(p,type,n) memset((p), 0, sizeof(type)*(n))

extern NmzResult nmz_regex_grep ( const char *expr, FILE *fp, const char *field, int field_mode );

#endif /* _RE_H */
