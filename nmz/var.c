/*
 * 
 * var.c -
 * 
 * $Id: var.c,v 1.21.4.3 2007-12-05 16:50:47 opengl2772 Exp $
 * 
 * Copyright (C) 1997-1999 Satoru Takabayashi All rights reserved.
 * Copyright (C) 2000,2002,2007 Namazu Project All rights reserved.
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

#include <stdio.h>
#include "libnamazu.h"
#include "re.h"

struct nmz_files Nmz;     /* NMZ.* files' file pointers */
struct nmz_names NMZ = {  /* NMZ.* files' names */
    "NMZ.i", 
    "NMZ.ii",
    "NMZ.head",
    "NMZ.foot",
    "NMZ.body",
    "NMZ.lock",
    "NMZ.result",
    "NMZ.slog",
    "NMZ.w",
    "NMZ.wi",
    "NMZ.field.",
    "NMZ.t",
    "NMZ.p",
    "NMZ.pi",
    "NMZ.tips",
    "NMZ.access",
    "NMZ.version",
    "NMZ.warnlog"
};

