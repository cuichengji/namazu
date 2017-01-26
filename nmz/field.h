#ifndef _FIELD_H
#define _FIELD_H

#define FIELD_SAFE_CHARS "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_."

enum {
    FIELD_CACHE_SIZE = 8        /* Size of field caches */
};

extern int nmz_isfield ( const char *key );
extern char *nmz_get_field_name ( const char *fieldpat );
extern void nmz_get_field_data ( int idxid, int docid, const char *field, char *data );
extern void nmz_free_field_cache ( void );

#endif /* _FIELD_H */
