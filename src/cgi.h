#ifndef _CGI_H
#define _CGI_H

struct cgivar {
    char *name;
    char *value;
    struct cgivar *next;
};
typedef struct cgivar CGIVAR;

/*
 * cgiarg: data structure for passing process_cgi_var_*() functions 
 * as a second arg as a pointer.
 */
struct cgiarg {
    char *query;
    char *subquery;
};


struct cgivar_func {
    char *name;
    void (*func)(char *key, struct cgiarg *func);
};

extern void init_cgi ( char *query, char *subquery );

#endif /* _CGI_H */
