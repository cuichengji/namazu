#ifndef _RCFILE_H
#define _RCFILE_H

#define DIRECTIVE_CHARS "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"

extern enum nmz_stat load_rcfiles ( void );
extern void show_config ( void );
extern void set_namazurc ( const char *arg );
extern void set_namazunorc ( const char *arg );

#endif /* _RCFILE_H */
