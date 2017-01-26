# -*- Perl -*-
# $Id: usage.pl,v 1.25.8.11 2006-01-24 12:42:55 opengl2772 Exp $
# Copyright (C) 1997-1999 Satoru Takabayashi All rights reserved.
# Copyright (C) 2000-2006 Namazu Project All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either versions 2, or (at your option)
#  any later version.
# 
#  This program is distributed in the hope that it will be useful
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
#  02111-1307, USA
#
#  This file must be encoded in EUC-JP encoding
#

package usage;
require "var.pl";

# dummy function.
sub N_ {
    return $_[0];
}

#
# Fake "\n\" was removed because gettext 0.13 supports perl string.
# (2004/03/04 knok)
#
$USAGE = N_("mknmz %s, an indexer of Namazu.

Usage: mknmz [options] <target>...

Target files:
  -a, --all                target all files.
  -t, --media-type=MTYPE   set the media type for all target files to MTYPE.
  -h, --mailnews           same as --media-type='message/rfc822'
      --mhonarc            same as --media-type='text/html; x-type=mhonarc'
  -F, --target-list=FILE   load FILE which contains a list of target files.
      --allow=PATTERN      set PATTERN for file names which should be allowed.
      --deny=PATTERN       set PATTERN for file names which should be denied.
      --exclude=PATTERN    set PATTERN for pathnames which should be excluded.
  -e, --robots             exclude HTML files containing
                           <meta name=\"ROBOTS\" content=\"NOINDEX\">
  -M, --meta               handle HTML meta tags for field-specified search.
  -r, --replace=CODE       set CODE for replacing URI.
      --html-split         split an HTML file with <a name=\"...\"> anchors.
      --mtime=NUM          limit by mtime just like find(1)'s -mtime option.
                           e.g., -50 for recent 50 days, +50 for older than 50.

Morphological Analysis:
  -b, --use-mecab          use MeCab for analyzing Japanese.
  -c, --use-chasen         use ChaSen for analyzing Japanese.
  -k, --use-kakasi         use KAKASI for analyzing Japanese.
  -m, --use-chasen-noun    use ChaSen for extracting only nouns.
  -L, --indexing-lang=LANG index with language specific processing.

Text Operations:
  -E, --no-edge-symbol     remove symbols on edge of word.
  -G, --no-okurigana       remove Okurigana in word.
  -H, --no-hiragana        ignore words consist of Hiragana only.
  -K, --no-symbol          remove symbols.
      --decode-base64      decode base64 bodies within multipart entities.

Summarization:
  -U, --no-encode-uri      do not encode URI.
  -x, --no-heading-summary do not make summary with HTML's headings.

Index Construction:
      --update=INDEX       set INDEX for updating.
  -z, --check-filesize     detect file size changed.
  -Y, --no-delete          do not detect removed documents.
  -Z, --no-update          do not detect update and deleted documents.

Miscellaneous:
  -s, --checkpoint         turn on the checkpoint mechanism.
  -C, --show-config        show the current configuration.
  -f, --config=FILE        use FILE as a config file.
  -I, --include=FILE       include your customization FILE.
  -O, --output-dir=DIR     set DIR to output the index.
  -T, --template-dir=DIR   set DIR having NMZ.{head,foot,body}.*.
  -q, --quiet              suppress status messages during execution.
  -v, --version            show the version of namazu and exit.
  -V, --verbose            be verbose.
  -d, --debug              be debug mode.
      --help               show this help and exit.
      --norc               do not read the personal initialization files.
      --                   Terminate option list.

Report bugs to <%s>
or <%s>.
");

##
## Version information
##
$VERSION_INFO = <<EOFversion;
mknmz of Namazu $var::VERSION
$var::COPYRIGHT

This is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2, or (at your option)
any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty
of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
EOFversion

1;

