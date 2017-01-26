/*
 * 
 * codeconv.c -
 * 
 * $Id: codeconv.c,v 1.29.8.10 2017-01-09 13:44:00 opengl2772 Exp $
 * 
 * Copyright (C) 1997-1999 Satoru Takabayashi All rights reserved.
 * Copyright (C) 2000-2017 Namazu Project All rights reserved.
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
 * 
 */

/*
 * Kanji encoding converting routine
 * this routine refers source code of K.Sato-san's QKC [1997-08-31]
 * (Quick KANJI code Converter  C Version 1.0) 
 */

#ifdef HAVE_CONFIG_H
#  include "config.h"
#endif
#ifdef HAVE_SUPPORT_H
#  include "support.h"
#endif

#include <stdio.h>
#ifdef HAVE_STDLIB_H
#  include <stdlib.h>
#endif

#ifdef HAVE_ERRNO_H
#  include <errno.h>
#endif

#ifdef HAVE_STRING_H
#  include <string.h>
#else
#  include <strings.h>
#endif

#include "libnamazu.h"
#include "codeconv.h"
#include "util.h"
#include "i18n.h"
#include "l10n-ja.h"

static uchar kanji2nd;


/*
 *
 * Macros
 *
 */

#define iskanji1st(c) (((uchar)(c) >= 0x81 && \
                       (uchar)(c)) <= 0x9f || \
                       ((uchar)(c) >= 0xe0 && \
                       (uchar)(c) <= 0xfc))
#define iskanji2nd(c) (((uchar)(c) >= 0x40 && \
                       (uchar)(c) <= 0xfc && \
                       (uchar)(c) != 0x7f))


/*
 *
 * Private functions
 *
 */

static uchar jmstojis ( uchar c1, uchar c2 );
static void jistoeuc ( uchar * s );
static void sjistoeuc ( uchar * s );
static uchar jistojms ( uchar c1, uchar c2 );
static void euctosjis ( uchar *s );
static void euctojis ( uchar *p );
static void zen2han ( char *str );

static uchar 
jmstojis(uchar c1, uchar c2)
{
    c1 -= (c1 <= 0x9f) ? 0x70 : 0xb0;
    c1 <<= 1;
    if (c2 < 0x9f) {
	c2 -= (c2 < 0x7f) ? 0x1f : 0x20;
	c1--;
    } else
	c2 -= 0x7e;
    kanji2nd = c2;
    return c1;
}


static void 
jistoeuc(uchar * s)
{
    uchar c, c2;
    int state, i = 0, j = 0;

    state = 0;
    if (!(c = *(s + j++)))
	return;
    while (1) {
	if (c == ESC) {
	    if (!(c = *(s + j++))) {
		*(s + i) = ESC;
		return;
	    }
	    switch (c) {
	    case '$':
		if (!(c2 = *(s + j++))) {
		    *(s + i++) = ESC;
		    *(s + i) = c;
		    return;
		}
		if (c2 == 'B' || c2 == '@')
		    state = 1;
		else {
		    *(s + i++) = ESC;
		    *(s + i++) = c;
		    c = c2;
		    continue;
		}
		break;

	    case '(':
		if (!(c2 = *(s + j++))) {
		    *(s + i++) = ESC;
		    *(s + i) = c;
		    return;
		}
		if (c2 == 'J' || c2 == 'B' || c2 == 'H') {
		    state = 0;
		} else {
		    *(s + i++) = ESC;
		    *(s + i++) = c;
		    c = c2;
		    continue;
		}
		break;

	    case 'K':
		state = 1;
		break;

	    case 'H':
		state = 0;
		break;

	    default:
		*(s + i++) = c;
		continue;
	    }
	} else if (c <= 0x20 || c == 0x7f) {
	    *(s + i++) = c;
	} else if (state) {
	    if (!(c2 = *(s + j++))) {
		*(s + i++) = c;
		*(s + i) = '\0';
		return;
	    }
	    if (c2 <= 0x20 || c2 == 0x7f) {
		*(s + i++) = c;
		c = c2;
		continue;
	    }
	    *(s + i++) = c | 0x80;
	    *(s + i++) = c2 | 0x80;
	} else {
	    *(s + i++) = c;
	}
	if (!(c = *(s + j++))) {
	    *(s + i) = '\0';
	    return;
	}
    }
}

static void 
sjistoeuc(uchar * s)
{
    uchar c, c2;
    int i = 0, j = 0;

    if (!(c = *(s + j++)))
	return;
    while (1) {
	if (c < 0x80)
	    *(s + i++) = c;
	else if (iskanji1st(c)) {
	    if (!(c2 = *(s + j++))) {
		*(s + i) = c;
		return;
	    }
	    if (iskanji2nd(c2)) {
		c = jmstojis(c, c2);
		*(s + i++) = (c | 0x80);
		*(s + i++) = (kanji2nd | 0x80);
	    } else {
		*(s + i++) = c;
		*(s + i++) = c2;
	    }
	} else
	    *(s + i++) = c;
	if (!(c = *(s + j++)))
	    return;
    }
}

static uchar 
jistojms(uchar c1, uchar c2)
{
    if (c1 & 1) {
	c1 = (c1 >> 1) + 0x71;
	c2 += 0x1f;
	if (c2 >= 0x7f)
	    c2++;
    } else {
	c1 = (c1 >> 1) + 0x70;
	c2 += 0x7e;
    }
    if (c1 > 0x9f)
	c1 += 0x40;
    kanji2nd = c2;
    return c1;
}

static void 
euctosjis(uchar *s)
{
    uchar c, c2;
    int i = 0, j = 0;

    while ((int)(c = *(s + j++))) {
	if (nmz_iseuc(c)) {
	    /* G1 for JIS X 0208 KANJI */
	    if (!(c2 = *(s + j++))) {
		*(s + i++) = c;
		break;
	    }
	    if (nmz_iseuc(c2)) {
		c = jistojms((uchar)(c & 0x7f), (uchar)(c2 & 0x7f));
		*(s + i++) = c;
		*(s + i++) = kanji2nd;
	    } else {
		*(s + i++) = c;
		*(s + i++) = c2;
	    }
	} else if (nmz_iseuc_kana1st(c)) {
	    /* G2 for JIS X 0201 KATAKANA */
	    if (!(c2 = *(s + j++))) {
		*(s + i++) = c;
		break;
	    }
	    *(s + i++) = c2;
	} else if (nmz_iseuc_hojo1st(c)) {
	    /* G3 for JIS X 0212 HOJO KANJI */
	    if (!(c2 = *(s + j++))) {
		*(s + i++) = c;
		break;
	    }
	    *(s + i++) = 0x81;
	    if (!(c2 = *(s + j++)))
		break;
	    *(s + i++) = 0xac;
	} else
	    /* G0 for ASCII or JIS X 0201 ROMAN SET */
	    *(s + i++) = c;
    }
    *(s + i) = 0;
}

/*
 * FIXME: This function give no consideration for buffer overflow, 
 * so you should prepare enough memory for `p'.
 * In the future, code conversion functions will be replaced with iconv(3)
 */
static void 
euctojis(uchar *p)
{
    int c, c2, state = 0;
    uchar *alloc, *s;
    
    alloc = (uchar *)strdup((char *)p);
    s = alloc;
    if (s == NULL) { /* */
	nmz_set_dyingmsg(nmz_msg("%s", strerror(errno)));
	return;
    }

    if (!(c = (int) *(s++))) {
	return;
    }
    while (1) {
	if (c < 0x80) {
	    if (state) {
		*p = ESC; p++; *p = '('; p++; *p = 'B'; p++;
		state = 0;
	    }
	    *p = c;
	    p++;
	} else if (nmz_iseuc(c)) {
	    if (!(c2 = (int) *(s++))) {
		*p = c;
		p++;
		break;
	    }
	    if (!state) {
		*p = ESC; p++; *p = '$'; p++; *p = 'B'; p++;
		state = 1;
	    }
	    if (nmz_iseuc(c2)) {
		*p = c & 0x7f;
		p++;
		*p = c2 & 0x7f;
		p++;
	    } else {
		*p = c;
		p++;
		*p = ESC; p++; *p = '('; p++; *p = 'B'; p++;
		state = 0;
		*p = c2;
		p++;
	    }
	} else {
	    if (state) {
		*p = ESC; p++; *p = '('; p++; *p = 'B'; p++;
		state = 0;
	    }
	    *p = c;
	    p++;
	}
	if (!(c = (int) *(s++))) {
	    if (state) {
		*p = ESC; p++; *p = '('; p++; *p = 'B'; p++;
	    }
	    *p = '\0';
	    break;
	}
    }
    *p = '\0';
    free(alloc);
}


/*
 * Converting 2 bytes Alnum and Symbol into 1 byte one.
 * This code was contributed by Akira Yamada <akira@linux.or.jp> [1997-09-28]
 */
static char Z2H[] = 
"\0 \0\0,.\0:;?!\0\0'`\0^~_\0\0\0\0\0\0\0\0\0\0\0\0/\\\0\0|\0\0`'\"\"()\0\0[]{}<>\0\0\0\0\0\0\0\0+-\0\0\0=\0<>\0\0\0\0\0\0\0'\"\0\\$\0\0%#&*@";

static void 
zen2han(char *str)
{
    int p = 0, q = 0, r;
    uchar *s;
    
    s = (uchar *)str;

    while (*(s + p)) {
	if (*(s + p) == 0xa1) {
	    r = *(s + p + 1) - 0xa0;
	    if (r <= sizeof(Z2H) && Z2H[r] != '\0') {
		p++;
		*(s + p) = Z2H[r];
	    } else {
		*(s + q) = *(s + p);
		q++;
		p++;
	    }
	} else if (*(s + p) == 0xa3) {
	    p++;
	    *(s + p) = *(s + p) - 128;
	} else if (*(s + p) & 0x80) {
	    *(s + q) = *(s + p);
	    p++;
	    q++;
	}
	*(s + q) = *(s + p);
	p++;
	q++;
    }
    *(s + q) = '\0';
}

static void
check_eucjp(uchar *s)
{
    int i;
    size_t num;

    num = strlen((char *)s);
    i = 0;
    while (i < num) {
        if (s[i] >= 0x20 && s[i] <= 0x7e) {
            i++;
        }
        else if (s[i] >= 0xa1 && s[i] <= 0xfe) {
            if (i + 1 < num) {
                if (s[i + 1] >= 0xa1 && s[i + 1] <= 0xfe) {
                    i += 2;
                }
                else {
                    s[i++] = ' ';
                    s[i++] = ' ';
                }
            }
            else {
                s[i++] = ' ';
            }
        }
        else if (s[i] == 0x8e) {
            if (i + 1 < num) { 
                if (s[i + 1] >= 0xa1 && s[i + 1] <= 0xdf) {
                    i += 2;
                }
                else {
                    s[i++] = ' ';
                    s[i++] = ' ';
                }
            }
            else {
                s[i++] = ' ';
            }
        }
        else if (s[i] == 0x8f) {
            if (i + 2 < num) { 
                if (s[i + 1] >= 0xa1 && s[i + 1] <= 0xfe
                && s[i + 2] >= 0xa1 && s[i + 2] <= 0xfe) {
                    i += 3;
                }
                else {
                    s[i++] = ' ';
                    s[i++] = ' ';
                    s[i++] = ' ';
                }
            }
            else if (i + 1 < num) {
                s[i++] = ' ';
                s[i++] = ' ';
            }
            else {
                s[i++] = ' ';
            }
        }
        else {
            s[i++] = ' ';
        }
    }
}

/*
 *
 * Public functions
 *
 */

/*
 * Detect character encoding (with simple approach) 
 * and convert "in" into EUC-JP
 * Supported encodings: EUC-JP, ISO-2022-JP, Shift_JIS
 */
int 
nmz_codeconv_internal(char *s)
{
    int i, m, n, f;
    uchar *in;

    in = (uchar *)s;

    if (!nmz_is_lang_ja()) { /* Lang != ja */
	for (i = 0; i < strlen(s); i++) {
	    if (s[i] < 0x20 || s[i] >= 0x7f) {
	        s[i] = ' ';
	    }
	}
        return 0;
    }
    for (i = 0, m = 0, n = 0, f = 0; *(in + i); i++) {
	if (*(in + i) == ESC) {
	    jistoeuc(in);
	    check_eucjp(in);
	    return 1;
	}
	if (*(in + i) > (uchar) '\x80')
	    m++, f = f ? 0 : 1;
	else if (f) {
	    sjistoeuc(in);
	    check_eucjp(in);
	    return 1;
	}
	if (*(in + i) > (uchar) '\xa0')
	    n++;
    }
    if (m != n) {
	sjistoeuc(in);
	check_eucjp(in);
	return 1;
    }
    if (n) {
        check_eucjp(in);
	return 1;
    }
    check_eucjp(in);
    return 0;
}

/*
 * Convert character encoding from internal one to external one.
 * Return a pointer of converted string.
 *
 * NOTES: Current internal encoding is EUC-JP for Japanese.
 * In future, internal encoding of Namazu will be UTF-8.
 *
 */
char *
nmz_codeconv_external (const char *str) {
    char *tmp, *lang;

    tmp = strdup(str);
    if (tmp == NULL) {
	nmz_set_dyingmsg(nmz_msg("%s", strerror(errno)));
	return NULL;
    }

    lang = nmz_get_lang();
    if (strcasecmp(lang, "japanese") == 0 || 
	strcasecmp(lang, "ja") == 0 || 
	strcasecmp(lang, "ja_JP.EUC") == 0 || 
	strcasecmp(lang, "ja_JP.ujis") == 0 ||
	strcasecmp(lang, "ja_JP.eucJP") == 0)  /* EUC-JP */
    {
	;
    } else if (strcasecmp(lang, "ja_JP.SJIS") == 0 ||
	strcasecmp(lang, "Japanese_Japan.932") == 0) /* Shift_JIS */
    {
	euctosjis((uchar *)tmp);
    } else if (strcasecmp(lang, "ja_JP.ISO-2022-JP") == 0) { /* ISO-2022-JP */
	/*
	 * Prepare enough memory for ISO-2022-JP encoding.
	 * FIXME: It's not space-efficient. In the future, 
	 * code conversion functions will be replaced with iconv(3)
	 */
	tmp = realloc(tmp, strlen(str) * 5);
	if (tmp == NULL) {
	    nmz_set_dyingmsg(nmz_msg("%s", strerror(errno)));
	    return NULL;
	}
	euctojis((uchar *)tmp);
    }
    return (char *)tmp;
}

void 
nmz_codeconv_query(char *query)
{
    if (nmz_is_lang_ja()) {
        if (nmz_codeconv_internal(query)) {
            zen2han(query);
        }
    }
}

