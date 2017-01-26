/*
 * $Id: result.c,v 1.59.8.30 2009-09-05 16:05:59 opengl2772 Exp $
 * 
 * Copyright (C) 1989, 1990 Free Software Foundation, Inc.
 * Copyright (C) 1997-1999 Satoru Takabayashi All rights reserved.
 * Copyright (C) 2000-2009 Namazu Project All rights reserved.
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

#ifdef HAVE_CONFIG_H
#  include "config.h"
#endif
#ifdef HAVE_SUPPORT_H
#  include "support.h"
#endif

#include <stdlib.h>
#include <ctype.h>

#ifdef HAVE_STRING_H
#  include <string.h>
#else
#  include <strings.h>
#endif

#include "namazu.h"
#include "i18n.h"
#include "util.h"
#include "field.h"
#include "output.h"
#include "re.h"
#include "result.h"
#include "codeconv.h"
#include "replace.h"
#include "var.h"
#include "parser.h"
#include "query.h"
#include "l10n-ja.h"

static int urireplace  = 1;   /* Replace URI in results as default. */
static int uridecode   = 1;   /* Decode  URI in results as default. */

/*
 *
 * Private functions
 *
 */

static void commas ( char *str );
static char *my_strcasestr ( char *s1, char *s2 );
static void replace_field ( struct nmz_data d, int counter, const char *field, char *result );
static void encode_entity ( char *str );
static void emphasize ( char *str );
static int is_wordboundary ( char *str );
static int is_urireplace ( void );
static int is_uridecode ( void );


/*
 * Add commas to numstr without overflow checking.
 * Be careful with the function!
 */
static void 
commas(char *numstr)
{
    int i;
    size_t n;
    size_t leng = strlen(numstr);

    if (leng <= 0) return;
    n = leng + (leng - 1) / 3;
    numstr[n] = '\0';
    n--;
    for (i = 0; i < (int)leng; i++, n--) {
        numstr[n] = numstr[leng - 1 - i];
        if (i % 3 == 2 && n != 0) {
            n--;
            numstr[n] = ',';
        }
    }
}

/* 
 * Case-insensitive brute force search
 */

static char *
my_strcasestr (s1, s2)
     char *s1;
     char *s2;
{
    int i;
    char *p1;
    char *p2;
    char *s = s1;
    int ja_mode;

    ja_mode = nmz_is_lang_ja ();

    for (p2 = s2, i = 0; *s; p2 = s2, i++, s++) {
        for (p1 = s; *p1 && *p2 && (_nmz_tolower(*p1) == _nmz_tolower(*p2)); p1++, p2++)
            ;
        if (!*p2)
            break;
        if (ja_mode && (nmz_iseuc(*s) || nmz_iseuc_kana1st(*s))) {
            i++;
            if (!*(++s)) break;
        }
    }
    if (!*p2)
        return s1 + i;

    return 0;
}

static void 
replace_field(struct nmz_data d, int counter, 
			  const char *field, char *result)
{
    /* 
     * 8 is length of '&quot;' + 2 (for emphasizing). 
     * It's a consideration for buffer overflow (overkill?) 
     */
    char buf[BUFSIZE * 8] = "";

    if (strcmp(field, "namazu::score") == 0) {
        sprintf(buf, "%d", d.score);
        commas(buf);
    } else if (strcmp(field, "namazu::counter") == 0) {
        sprintf(buf, "%d", counter);
        commas(buf);
    } else {
        nmz_get_field_data(d.idxid, d.docid, field, buf);
        if (buf[0] != '\0' && strcasecmp(field, "uri") == 0) {
            if (is_urireplace()) {
                nmz_replace_uri(buf);
            }
            if (is_uridecode()) {
                nmz_decode_uri(buf);
            }
        }
    }

    /* 
     * Do not emphasize keywords in URI.
     */
    if (buf[0] != '\0' && is_htmlmode()) {
        if (strcasecmp(field, "uri") != 0)
            emphasize(buf);
        encode_entity(buf);
    }

    /* Insert commas if the buf is a numeric string. */
    if (buf[0] != '\0' && nmz_isnumstr(buf)) {
        commas(buf);
    }

    strcat(result, buf);
}

static void 
encode_entity(char *str)
{
    int i;
    char tmp[BUFSIZE] = "";

    strncpy(tmp, str, BUFSIZE - 1);
    strcpy(str, "");
    for (i = 0; tmp[i]; i++) {
        if (tmp[i] == '<') {
            strncat(str, "&lt;", BUFSIZE - strlen(str) - 1);
        } else if (tmp[i] == '>') {
            strncat(str, "&gt;", BUFSIZE - strlen(str) - 1);
        } else if (tmp[i] == '&') {
            strncat(str, "&amp;", BUFSIZE - strlen(str) - 1);
        } else if (tmp[i] == '"') {
            strncat(str, "&quot;", BUFSIZE - strlen(str) - 1);
        } else if (tmp[i] == '\'') {
            strncat(str, "&#39;", BUFSIZE - strlen(str) - 1);
        } else if (tmp[i] == '(') {
            strncat(str, "&#40;", BUFSIZE - strlen(str) - 1);
        } else if (tmp[i] == ')') {
            strncat(str, "&#41;", BUFSIZE - strlen(str) - 1);
        } else {
            if (strlen(str) < BUFSIZE - 1)
                strncat(str, tmp + i, 1);
        }
    }
}

/*
 * Inefficient algorithm but it works
 */
static void 
emphasize(char *str)
{
    int i;

    for (i = 0; nmz_get_querytoken(i) != NULL; i++) {
        char *ptr = str;
        char key[BUFSIZE] = "";
        size_t keylen = 0;
        int findFlag = 0;
        char *keys;
        char *word;

        if (nmz_is_query_op(nmz_get_querytoken(i)))
            continue;

        strncpy(key, nmz_get_querytoken(i), BUFSIZE - 1);

        if (strchr(key, '\t')) { /* for phrase search */
            nmz_tr(key, "\t", " ");
            memmove(key, key + 1, strlen(key + 1) + 1);
            key[strlen(key) - 1] = '\0';

            nmz_strlower(key);

            ptr = str;
            while (*ptr) {
                char *lowerString, *lowerPtr;
                char *startPos, *endPos;

                lowerString = strdup(str);
                nmz_strlower(lowerString);
                lowerPtr = lowerString + (ptr - str);
                startPos = endPos = lowerPtr;

                findFlag = 0;
                for (; *lowerPtr; lowerPtr++, ptr++) {
                   keys = strdup(key);
                   word = strtok(keys, " \t\n\r");
                   if (!strncmp(lowerPtr, word, strlen(word))) {
                       startPos = lowerPtr;
                       endPos = lowerPtr + strlen(word);
                       lowerPtr += strlen(word);
                       ptr += strlen(word);
                       findFlag = 1;
                       while ((word = strtok(NULL, " \t\n\r"))) {
                           while (*lowerPtr == ' ' || *lowerPtr == '\t' || *lowerPtr == '\r' || *lowerPtr == '\n') {
                               lowerPtr++;
                               ptr++;
                           }
                           if (!strncmp(lowerPtr, word, strlen(word))) {
                               findFlag = 1;
                               endPos = lowerPtr + strlen(word);
                           }
                           else {
                               findFlag = 0;
                               break;
                           }
                           lowerPtr += strlen(word);
                           ptr += strlen(word);
                       }
                   }
                   free(keys);

                   if (findFlag) {
                       break;
                   }
                }

                free(lowerString);

                if (!findFlag) {
                    break;
                }

                keylen = endPos - startPos;
                ptr -= keylen;
                memmove(ptr + 2, ptr, strlen(ptr) + 1);
                memmove(ptr + 1, ptr + 2, keylen);
                *ptr = EM_START_MARK;
                *(ptr + keylen + 1) = EM_END_MARK;
                ptr += keylen + 2;
            }
            continue;
        }

        if (strlen(key) > 0) {
            if (strlen(key) >= 2
            && ((key[0] == '"' && key[strlen(key) - 1] == '"')
            || (key[0] == '{' && key[strlen(key) - 1] == '}')
            || (key[0] == '/' && key[strlen(key) - 1] == '/'))) {
                memmove(key, key + 1, strlen(key + 1) + 1);
                key[strlen(key) - 1] = '\0';
            } else {
                /* substring matching */
                if (key[0] == '*') {
                    memmove(key, key + 1, strlen(key + 1) + 1);
                }
                if (key[strlen(key) - 1] == '*') {
                    key[strlen(key) - 1] = '\0';
                }
            }
        }

        keylen = strlen(key);

        if (keylen > 0) {
            do {
                ptr = my_strcasestr(ptr, key);
                if (ptr != NULL) {
                    if ((ptr == str || is_wordboundary(ptr - 1))
                    && keylen && is_wordboundary(ptr + keylen - 1)){
                        memmove(ptr + 2, ptr, strlen(ptr) + 1);
                        memmove(ptr + 1, ptr + 2, keylen);
                        *ptr = EM_START_MARK;
                        *(ptr + keylen + 1) = EM_END_MARK;
                        ptr += 2;
                    }
                    ptr += keylen;
                }
            } while (ptr != NULL);
        }
    }
}

static int
is_wordboundary(char *p)
{
  if (nmz_isalpha((unsigned char)*p) && nmz_isalpha((unsigned char)*(p + 1)))
      return 0;
  if (nmz_isdigit((unsigned char)*p) && nmz_isdigit((unsigned char)*(p + 1)))
      return 0;
  return 1;
}

static int 
is_urireplace(void)
{
    return urireplace;
}

static int 
is_uridecode(void)
{
    return uridecode;
}
/*
 *
 * Public functions 
 *
 */

void 
compose_result(struct nmz_data d, int counter, 
			   const char *template, char *r)
{
    const char *p = template;
    char achars[BUFSIZE] = ""; /* acceptable characters */

    strcpy(r, "\t");  /* '\t' has an important role cf. html_print() */

    strncpy(achars, FIELD_SAFE_CHARS, BUFSIZE - 1);
    strncat(achars, ":", BUFSIZE - strlen(achars) - 1);  /* for namazu::score, namazu::counter */

    do {
        char *pp;
        pp = strstr(p, "${");
        if (pp != NULL) {
            size_t n;
            strncat(r, p, pp - p);
            pp += 2;  /* skip "${" */
            n = strspn(pp, achars);
            if (n > 0 && pp[n] == '}') {
                char field[BUFSIZE] = "";

                strncpy(field, pp, n);
                field[n] = '\0';
                replace_field(d, counter, field, r);
                p = pp + n + 1; /* +1 for skipping "}" */
            } else {
                p += 2;
            }
        } else {
            strncat(r, p, BUFSIZE * 128 - strlen(r) - 1);
            break;
        }
    } while (1);
}

void 
set_urireplace(int mode)
{
    urireplace = mode;
}

void 
set_uridecode(int mode)
{
    uridecode = mode;
}

