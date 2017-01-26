/*
 * 
 * $Id: util.c,v 1.75.4.21 2010-12-18 19:45:07 opengl2772 Exp $
 * 
 * Copyright (C) 1997-1999 Satoru Takabayashi All rights reserved.
 * Copyright (C) 2000-2010 Namazu Project All rights reserved.
 * This is free software with ABSOLUTELY NO WARRANTY.
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
 * 02111-1307, USA
 * 
 * nmz_scan_hex(), nmz_scan_oct(), nmz_xmalloc(), nmz_xrealloc() are 
 * originally imported from Ruby b19's "util.c" and "gc.c". 
 * Thanks to Mr. Yukihiro Matsumoto <matz@netlab.co.jp>.
 *
 */

#ifdef HAVE_CONFIG_H
#  include "config.h"
#endif
#ifdef HAVE_SUPPORT_H
#  include "support.h"
#endif

#include <assert.h>
#include <stdio.h>
#ifdef HAVE_STDLIB_H
#  include <stdlib.h>
#endif
#include <ctype.h>
#include <stdarg.h>

#ifdef HAVE_ERRNO_H
#  include <errno.h>
#endif

#ifdef __EMX__
#include <sys/types.h>
#endif

#ifdef HAVE_SYS_STAT_H
#	include <sys/stat.h>
#endif

#ifdef HAVE_STRING_H
#  include <string.h>
#else
#  include <strings.h>
#endif

#include "libnamazu.h"
#include "util.h"
#include "i18n.h"
#include "var.h"
#include "system.h"

/*
 *
 * Private functions
 *
 */

static void reverse_byte_order (void*, size_t, size_t);
static char decode_uri_sub(char c1, char c2);

/* 
 * Reverse byte order. It's type independent.
 */
static void 
reverse_byte_order (void *p, size_t n, size_t size)
{
    int i, j;
    char *pp, tmp;

    pp = (char *)p;
    for (i = 0; i < (int)n; i++) {
        char *c = (pp + (i * size));
        for (j = 0; j < (int)(size / 2); j++) {
            tmp = *(c + j);
            *(c + j)= *(c + size - 1 - j);
            *(c + size - 1 - j) = tmp;
        }
    }
}

static char 
decode_uri_sub(char c1, char c2)
{
    char c;

    c = ((c1 >= 'A' ? (_nmz_toupper((unsigned char)c1) - 'A') + 10 : (c1 - '0'))) * 16;
    c += ( c2 >= 'A' ? (_nmz_toupper((unsigned char)c2) - 'A') + 10 : (c2 - '0'));
    return c;
}

/*
 *
 * Public functions
 *
 */

unsigned long
nmz_scan_oct(const char *start, int len, int *retlen)
{
    register const char *s = start;
    register unsigned long retval = 0;

    while (len-- && *s >= '0' && *s <= '7') {
	retval <<= 3;
	retval |= *s++ - '0';
    }

    *retlen = (int)(s - start);
    return retval;
}

unsigned long
nmz_scan_hex(const char *start, int len, int *retlen)
{
    static char hexdigit[] = "0123456789abcdef0123456789ABCDEFx";
    register const char *s = start;
    register unsigned long retval = 0;
    char *tmp;

    while (len-- && *s && (tmp = strchr(hexdigit, *s))) {
	retval <<= 4;
	retval |= (tmp - hexdigit) & 15;
	s++;
    }
    *retlen = (int)(s - start);
    return retval;
}


static unsigned long malloc_memories = 0;

void *
nmz_xmalloc(unsigned long size)
{
    void *mem;

    if (size == 0) size = 1;
    malloc_memories += size;
    mem = malloc(size);

    return mem;
}

void *
nmz_xrealloc(void *ptr, unsigned long size)
{
    void *mem;

    if (!ptr) return nmz_xmalloc(size);
    mem = realloc(ptr, size);
    return mem;
}



void 
nmz_tr(char *str, const char *lstr, const char *rstr)
{
    while (*str) {
	char *idx = strchr(lstr, *str);
	if (idx != NULL) { /* found */
	    *str = *(idx - lstr + rstr);
	}
        str++;
    }
}

/* 
 * Delete ending white spaces in the str.
 */
void 
nmz_chomp(char *str)
{
    char *p = str + strlen(str) - 1;

    for (; p >= str; p--) {
	if (*p == '\n' || *p == '\r' || *p == ' ' || *p == '\t') {
	    *p = '\0';
	} else {
	    break;
	}
    }
}


/* 
 * Do fread with endian consideration.
 */
size_t 
nmz_fread(void *ptr, size_t size, size_t nmemb, FILE *stream)
{
    size_t value;

    value = fread(ptr, size, nmemb, stream);
/*
 * FIXME: Please tell me if you know more better way.
 */
#ifndef WORDS_BIGENDIAN
    reverse_byte_order(ptr, nmemb, size);
#endif
    return value;
}

int 
nmz_get_unpackw(FILE *fp, int *data)
{
    int val = 0, i = 0;

    while (1) {
	int tmp = getc(fp);
	i++;
	if (tmp == EOF) {
	    return 0;
	}
	if (tmp < 128) {
	    val += tmp;
	    *data = val;
	    return i;
	} else {
	    tmp &= 0x7f;
	    val += tmp;
	    val <<= 7;
	}
    }
}

int 
nmz_read_unpackw(FILE *fp, int *buf, int size) {
    int i = 0,  n = 0;
    
    while (i < size) {
	int tmp = nmz_get_unpackw(fp, &buf[n]);
	n++;
	if (tmp == 0) {  /* Error */
	    break;
	} else {
	    i += tmp;
	}
    }
    return  n;
}

/* 
 * Read an index and return its value which is a pointer to another file.
 */
long 
nmz_getidxptr(FILE * fp, long point)
{
    int val;

    fseek(fp, point * sizeof(int), 0);
    nmz_fread(&val, sizeof(int), 1, fp);
    return (long) val;
}

/* 
 * Warning messaging function.
 */
void 
nmz_warn_printf(const char *fmt, ...)
{
    va_list args;
    FILE *fp;

    if (!nmz_is_loggingmode())
	return;
    if (nmz_is_output_warn_to_file()) {
	fp = fopen(NMZ.warnlog, "a+");
	if (fp == NULL) {
	    fprintf(stderr, "Can't open NMZ.warnlog.\n");
	    return;
	}
    } else {
	fp = stderr;
    }

    fflush(fp);

    fprintf(fp, "%s: ", PACKAGE);

    va_start(args, fmt);
    vfprintf(fp, fmt, args);
    va_end(args);

    if (fmt[strlen(fmt) - 1] != '\n') {
	fprintf(fp, "\n");
    }

    fflush(fp);

    if (fp != stderr)
	fclose(fp);
}

/* 
 * Debug messaging function.
 */
void 
nmz_debug_printf(const char *fmt, ...)
{
    va_list args;

    if (!nmz_is_debugmode()) {
	return;
    }

    fflush(stdout);

    fprintf(stderr, "%s(debug): ", PACKAGE);

    va_start(args, fmt);
    vfprintf(stderr, fmt, args);
    va_end(args);

    if (fmt[strlen(fmt) - 1] != '\n') {
	fprintf(stderr, "\n");
    }

    fflush(stderr);
}

void 
nmz_pathcat(const char *base, char *name)
{
    char work[BUFSIZE];
    int i;
    int win32 = 0;
#if  defined(_WIN32) || defined(__EMX__)
    win32 = 1;
#endif

    for (i = (int)strlen(name) - 1; i >= 0; i--) {
        if (name[i] == '/' || (win32 && name[i] == '\\')) {
            strcpy(name, name + i + 1);
            break;
        }
    }
    strncpy(work, base, BUFSIZE - 1);
    work[BUFSIZE - 1] = '\0';
    strncat(work, "/", BUFSIZE - strlen(work) - 1);
    strncat(work, name, BUFSIZE - strlen(work) - 1);
    strncpy(name, work, BUFSIZE - 1);
}

int 
nmz_isnumstr(const char *str)
{
    const unsigned char *p;

    if (strlen(str) > 10) {  /* Too large number */
	return 0;
    }

    for (p = (const unsigned char *)str; *p != '\0'; p++) {
	if (!nmz_isdigit((int)*p)) {
	    return 0;
	}
    }

    return 1;
}

/* 
 * Substitute for tolower(3).
 */

int
_nmz_tolower(int c)
{
    if (c >= 'A' && c <= 'Z') {
        c = 'a' + c - 'A';
        return c;
    }
    return c;
}

int
_nmz_toupper(int c)
{
    if (c >= 'a' && c <= 'z') {
        c = 'A' + c - 'a';
        return c;
    }
    return c;
}

void 
nmz_strlower(char *str)
{
    while (*str) {
	/* Using ascii dependent lower same as mknmz.  */
        *str = _nmz_tolower(*str);
        str++;
    }
}

int 
nmz_strprefixcasecmp(const char *str1, const char *str2)
{
    size_t len1, len2;

    len1 = strlen(str1);
    len2 = strlen(str2);

    if (len1 > len2) {
	return strncasecmp(str1, str2, len2);
    } else {
	return strncasecmp(str1, str2, len1);
    }
}

int 
nmz_strprefixcmp(const char *str1, const char *str2)
{
    size_t len1, len2;

    len1 = strlen(str1);
    len2 = strlen(str2);

    if (len1 > len2) {
	return strncmp(str1, str2, len2);
    } else {
	return strncmp(str1, str2, len1);
    }
}

int 
nmz_strsuffixcmp(const char *str1, const char *str2)
{
    size_t len1, len2;

    len1 = strlen(str1);
    len2 = strlen(str2);

    if (len1 > len2) {
	return strcmp(str1 + len1 - len2, str2);
    } else {					     
	return strcmp(str1, str2 + len2 - len1);
    }
}

/*
 * Load the whole of file.
 */
char *
nmz_readfile(const char *fname)
{
    char *buf;
    FILE *fp;
    struct stat fstatus;
	size_t size;

    errno = 0; /* errno must be initialized. */

    stat(fname, &fstatus);
	size = (size_t)fstatus.st_size;

    fp = fopen(fname, "rb");
    if (fp == NULL) {
        nmz_warn_printf("%s: %s", fname, strerror(errno));
        return NULL;
    }
    buf = malloc(size + 1);
    if (buf == NULL) {
        nmz_set_dyingmsg(nmz_msg("%s: %s", fname, strerror(errno)));
        fclose(fp);
        return NULL;
    }
    if (size != 0 &&
	fread(buf, sizeof(char), size, fp) == 0) 
    {
        nmz_set_dyingmsg(nmz_msg("%s: %s", fname, strerror(errno)));
        free(buf);
        fclose(fp);
        return NULL;
    }
    *(buf + size) = '\0';
    fclose(fp);
    return buf;
}

/*
 * Safe version of getenv. 
 */
char *
nmz_getenv(const char *s)
{
    char *cp;
    return (cp = getenv(s)) ? cp : "";
}

/*
 * Decoding URI encoded strings
 */
void 
nmz_decode_uri(char *str)
{
    int i, j;
    for (i = j = 0; str[i]; i++, j++) {
	if (str[i] == '%') {
	    if (str[i+1] != 0 && str[i+2] != 0) {
		str[j] = decode_uri_sub(str[i + 1], str[i + 2]);
		i += 2;
	    }
	} else if (str[i] == '+') {
	    str[j] = ' ';
	} else {
	    str[j] = str[i];
	}
    }
    str[j] = '\0';
}

/*
 * Returns a string describing the libnmz error code passed
 * in the argument errnum just like strerror().
 */
char *
nmz_strerror(enum nmz_stat errnum)
{
    char *msg = NULL;

    switch (errnum) {
    case ERR_FATAL:
	msg = _("Fatal error occurred!");
	break;
    case ERR_TOO_LONG_QUERY:
        msg = _("Too long query");
	break;
    case ERR_INVALID_QUERY:
	msg = _("Invalid query");
	break;
    case ERR_TOO_MANY_TOKENS:
	msg = _("Too many query tokens");
	break;
    case  ERR_TOO_MUCH_MATCH:
	msg = _("Too many words matched. Ignored");
	break;
    case ERR_TOO_MUCH_HIT:
	msg = _("Too many documents hit. Ignored");
	break;
    case ERR_REGEX_SEARCH_FAILED:
	msg = _("can't open the regex index");
	break;
    case ERR_PHRASE_SEARCH_FAILED:
	msg = _("can't open the phrase index");
	break;
    case ERR_FIELD_SEARCH_FAILED:
	msg = _("can't open the field index");
	break;
    case ERR_CANNOT_OPEN_INDEX:
	msg = _("can't open the index");
	break;
    case ERR_CANNOT_OPEN_RESULT_FORMAT_FILE:
	msg = _("can't open the result format file");
	break;
    case ERR_NO_PERMISSION:
	msg = _("You don't have a permission to access the index");
	break;
    case ERR_INDEX_IS_LOCKED:
	msg = _("The index is locked for maintenance");
	break;
    case ERR_OLD_INDEX_FORMAT:
	msg = _("Present index is old type. it's unsupported.");
	break;
    default:
	msg = _("Unknown error. Report bug!");
	break;
    } 

    assert(msg != NULL);

    return msg;
}

/*
 * Check wheter the file fname exists or not.
 */
int
nmz_is_file_exists(const char *fname)
{
    struct stat fstatus;

    return stat(fname, &fstatus) == 0;
}

/*
 *   for directory traversal issue.
 *   Must be encoded in EUC-JP encoding.
 */
char *
nmz_delete_since_path_delimitation(char *dest, const char *src, size_t n)
{
    char *p;

    if (n < 1) {
        return dest;
    }

    strncpy(dest, src, n - 1);
    dest[n - 1] = '\0';

    p = dest;
    while(*p) {
        if (*p == '/' || *p == '\\') {
            *p = '\0';
            break;
        }
        p++;
    }

    return dest;
}
