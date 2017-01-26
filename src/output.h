#ifndef _OUTPUT_H
#define _OUTPUT_H

#include "libnamazu.h"  /* for NmzResult */

/*
 * Special identifier for keyword emphasizing.
 */
enum {
    EM_START_MARK = 0x01,
    EM_END_MARK   = 0x02
};

extern enum nmz_stat print_result ( NmzResult hlist, const char *query, const char *subquery );
extern void print_default_page ( void );
extern void set_emphasis_tags(const char *start_tag, const char *end_tag);
extern char *get_emphasis_tag_start(void);
extern char *get_emphasis_tag_end(void);
extern void set_contenttype( const char *str );
extern char *get_contenttype(void);
extern void set_htmlmode ( int mode );
extern int is_htmlmode ( void );
extern void set_cgimode ( int mode );
extern void set_quietmode ( int mode );
extern void set_countmode ( int mode );
extern void set_listmode ( int mode );
extern void set_allresult ( int mode );
extern void set_pageindex ( int mode );
extern void set_formprint ( int mode );
extern int is_formprint ( void );
extern void set_refprint ( int mode );
extern void set_maxresult ( int num );
extern int get_maxresult ( void );
extern void set_listwhence ( int num );
extern int get_listwhence ( void );
extern void set_templatesuffix ( const char *tmpl );
extern char *get_templatesuffix ( void );
extern void html_print ( const char *str );
extern void print ( const char *str );
extern void die(const char *fmt, ...);
extern void puts_entitize( const char *str );
extern void putc_entitize( int c );

#endif /* _OUTPUT_H */
