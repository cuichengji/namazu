/*
 * 
 * usage.c -
 * 
 * $Id: usage.c,v 1.26.8.7 2007-12-05 16:59:36 opengl2772 Exp $
 * 
 * Copyright (C) 1997-1999 Satoru Takabayashi All rights reserved.
 * Copyright (C) 2000-2007 Namazu Project All rights reserved.
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
#include "namazu.h"
#include "libnamazu.h"
#include "codeconv.h"
#include "message.h"
#include "usage.h"
#include "i18n.h"

/*
 *
 * Public functions
 *
 */

/*
 * Display the usage and version info and exit
 */
void 
show_usage(void)
{
    char *usage = _("\
namazu %s, a search program of Namazu.\n\n\
Usage: namazu [options] <query> [index]... \n\
    -n, --max=NUM        set the number of documents shown to NUM.\n\
    -w, --whence=NUM     set the first number of documents shown to NUM.\n\
    -l, --list           print the results by listing the format.\n\
    -s, --short          print the results in a short format.\n\
        --result=EXT     set NMZ.result.EXT for printing the results.\n\
        --late           sort the documents in late order.\n\
        --early          sort the documents in early order.\n\
        --sort=METHOD    set a sort METHOD (score, date, field:name)\n\
        --ascending      sort in ascending order (default: descending)\n\
    -a, --all            print all results.\n\
    -c, --count          print only the number of hits.\n\
    -h, --html           print in HTML format.\n\
    -r, --no-references  do not display the reference hit counts.\n\
    -H, --page           print the links of further results. \n\
                         (This is nearly meaningless)\n\
    -F, --form           force to print the <form> ... </form> region.\n\
    -R, --no-replace     do not replace the URI string.\n\
    -U, --no-decode-uri  do not decode the URI when printing in a plain format.\n\
    -o, --output=FILE    set the output file name to FILE.\n\
    -f, --config=FILE    set the config file name to FILE.\n\
    -C, --show-config    print the current configuration.\n\
    -q, --quiet          do not display extra messages except search results.\n\
    -d, --debug          be in debug mode.\n\
    -v, --version        show the namazu version and exit.\n\
        --help           show this help and exit.\n\
        --norc           do not read the personal initialization files.\n\
        --               Terminate option list.\n\
\n\
Report bugs to <%s>\n\
or <%s>.\n\
");

    printf(usage, VERSION, TRAC_URI, MAILING_ADDRESS);
}


void 
show_mini_usage(void)
{
    fputs(_("Usage: namazu [options] <query> [index]...\n"), stdout);
    fputs(_("Try `namazu --help' for more information.\n"), stdout);
}

void 
show_version(void)
{
    printf("namazu of Namazu %s\n", VERSION);
    printf("%s\n", COPYRIGHT);
    printf("This is free software; you can redistribute it and/or modify\n");
    printf("it under the terms of the GNU General Public License as published by\n");
    printf("the Free Software Foundation; either version 2, or (at your option)\n");
    printf("any later version.\n\n");
    printf("This program is distributed in the hope that it will be useful,\n");
    printf("but WITHOUT ANY WARRANTY; without even the implied warranty\n");
    printf("of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the\n");
    printf("GNU General Public License for more details.\n");
}
