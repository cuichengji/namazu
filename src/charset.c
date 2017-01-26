/*
 * 
 * charset.c - 
 *
 * $Id: charset.c,v 1.1.4.2 2007-12-05 16:59:35 opengl2772 Exp $
 * 
 * Copyright (C) 2007 Tadamasa Teranishi All rights reserved.
 *               2007 Namazu Project All rights reserved.
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

#include <stdio.h>
#include <stdlib.h>

#ifdef HAVE_ERRNO_H
#  include <errno.h>
#endif

#include <assert.h>

#ifdef HAVE_STRING_H
#  include <string.h>
#else
#  include <strings.h>
#endif

#include "charset.h"
#include "util.h"

typedef struct _node {
    char *lang;
    char *encode;
} ENCODE_TABLE;

static ENCODE_TABLE EncodeTable[] = {
    { "ja", "EUC-JP" },
    { "ja_JP.SJIS", "Shift_JIS" },
    { "ja_JP.ISO-2022-JP", "ISO-2022-JP" },
    { "en", "ISO-8859-1", },
    { "fr", "ISO-8859-1", },
    { "de", "ISO-8859-1", },
    { "es", "ISO-8859-1", },
    { "pl", "ISO-8859-2", },
};

/*
 *
 * Public functions
 *
 */

NMZ_HANDLE
create_charset_list(void)
{
    int i;
    NMZ_HANDLE handle = (NMZ_HANDLE)0;

    handle = nmz_create_strlist(
        NMZ_STRLIST_KEY_CASE_INSENSITIVE
    );

    if (handle == (NMZ_HANDLE)0) {
        return (NMZ_HANDLE)0;
    }

    for (i = 0; i < sizeof(EncodeTable) / sizeof(ENCODE_TABLE); i++) {
        enum nmz_stat stat;

        stat = nmz_add_strlist(handle,
            EncodeTable[i].lang, EncodeTable[i].encode
        );
        if (stat == FAILURE) {
            nmz_free_handle(handle);
            return (NMZ_HANDLE)0;
        }
    }

    return handle;
}
