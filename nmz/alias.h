#ifndef _ALIAS_H
#define _ALIAS_H

#include "libnamazu.h" /* for enum nmz_stat */

struct nmz_alias {
    char *alias;
    char *real;
    struct nmz_alias *next;
};

extern enum nmz_stat nmz_add_alias ( const char *alias, const char *real );
extern void nmz_free_aliases ( void );
extern struct nmz_alias *nmz_get_aliases ( void );

#endif /* _ALIAS_H */
