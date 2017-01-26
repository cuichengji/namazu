#ifndef _LIST_H
#define _LIST_H

#include "libnamazu.h" /* for enum nmz_stat */

/*
 *  handle
 */

typedef void *NMZ_HANDLE;

extern void nmz_clear_handle(NMZ_HANDLE handle);
extern void nmz_free_handle(NMZ_HANDLE handle);

/*
 *  generic list
 */

extern enum nmz_stat nmz_first_list(NMZ_HANDLE handle);
extern enum nmz_stat nmz_next_list(NMZ_HANDLE handle);

/*
 *  string list
 */

#define NMZ_STRLIST_SINGLE                 0x010000
#define NMZ_STRLIST_KEY_DUPLICATE          0x008000
#define NMZ_STRLIST_KEY_CASE_INSENSITIVE   0x000100
#define NMZ_STRLIST_VALUE_CASE_INSENSITIVE 0x000001

extern NMZ_HANDLE nmz_create_strlist(unsigned int config);
extern enum nmz_stat
nmz_add_single_strlist(NMZ_HANDLE handle, const char *value);
extern enum nmz_stat
nmz_add_strlist(NMZ_HANDLE handle, const char *key, const char *value);
extern char *nmz_get_key_strlist(NMZ_HANDLE handle);
extern char *nmz_get_value_strlist(NMZ_HANDLE handle);
extern char *nmz_find_first_strlist(NMZ_HANDLE handle, const char *key);
extern char *nmz_find_next_strlist(NMZ_HANDLE handle, const char *key);

#endif /* _LIST_H */
