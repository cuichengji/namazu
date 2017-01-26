#ifndef _UTIL_H
#define _UTIL_H

#include <stdio.h>     /* for FILE struct */
#include "libnamazu.h" /* for enum nmz_stat struct */

/*
 *
 * Macros
 *
 */

#define nmz_iseuc(c)         ((uchar)(c) >= 0xa1 && (uchar)(c) <= 0xfe)
#define nmz_iseuc_kana1st(c) ((uchar)(c) == 0x8e)
#define nmz_iseuc_hojo1st(c) ((uchar)(c) == 0x8f)

extern unsigned long nmz_scan_oct ( const char *start, int len, int *retlen );
extern unsigned long nmz_scan_hex ( const char *start, int len, int *retlen );
extern void * nmz_xmalloc ( unsigned long size );
extern void * nmz_xrealloc ( void *ptr, unsigned long size );
extern void nmz_tr ( char *str, const char *lstr, const char *rstr );
extern void nmz_chomp ( char * str );
extern size_t nmz_fread ( void *ptr, size_t size, size_t nmemb, FILE *stream );
extern int nmz_get_unpackw ( FILE *fp, int *data );
extern int nmz_read_unpackw ( FILE *fp, int *buf, int size );
extern long nmz_getidxptr ( FILE * fp, long point );
extern void nmz_warn_printf ( const char *fmt, ... );
extern void nmz_debug_printf ( const char *fmt, ... );
extern void nmz_pathcat ( const char *base, char *name );
extern int nmz_isnumstr ( const char *str );
extern int _nmz_tolower ( int c );
extern int _nmz_toupper ( int c );
extern void nmz_strlower ( char *str );
extern int nmz_strcasecmp ( const char *str1, const char *str2 );
extern int nmz_strncasecmp ( const char *str1, const char *str2, int n );
extern int nmz_strprefixcasecmp ( const char *str1, const char *str2 );
extern int nmz_strprefixcmp ( const char *str1, const char *str2 );
extern int nmz_strsuffixcmp ( const char *str1, const char *str2 );
extern char * nmz_readfile ( const char *fname );
extern char * nmz_getenv ( const char *str );
extern void nmz_decode_uri ( char * str );
extern char * nmz_strerror ( enum nmz_stat errnumt );
extern int nmz_is_file_exists(const char *fname);
extern char *nmz_delete_since_path_delimitation( char *dest, const char *src, size_t n);

#endif /* _UTIL_H */
