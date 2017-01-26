#
# -*- Perl -*-
# $Id: macbinary.pl,v 1.1.2.6 2008-05-09 07:46:24 opengl2772 Exp $
# Copyright (C) 2003-2008 Namazu Project All rights reserved.
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

package macbinary;
use strict;
require 'util.pl';

sub mediatype () {
    return ('application/macbinary');
}

sub status () {
    return 'yes';
}

sub recursive () {
    return 0;
}

sub pre_codeconv () {
    return 0;
}

sub post_codeconv () {
    return 0;
}

sub add_magic ($) {
    my ($magic) = @_;

    $magic->addMagicEntry("0\tubyte\t0\t");
    $magic->addMagicEntry(">74\tubyte\t0\t");

#   MacBinaryIII
    $magic->addMagicEntry(">>122\tubyte\t130\t");
    $magic->addMagicEntry(">>>102\tstring\tmBIN\tapplication/macbinary");

#   MacBinaryII
    $magic->addMagicEntry(">>122\tubyte\t129\t");
    $magic->addMagicEntry(">>>123\tubyte\t129\t");
    $magic->addMagicEntry(">>>>102\tbelong\t0\tapplication/macbinary");

#   MacBinaryI
    $magic->addMagicEntry(">>122\tubyte\t0\t");
    $magic->addMagicEntry(">>>123\tubyte\t0\t");
    $magic->addMagicEntry(">>>>102\tbelong\t0\tapplication/macbinary");

    return;
}

sub filter ($$$$$) {
    my ($orig_cfile, $contref, $weighted_str, $headings, $fields)
      = @_;

    util::vprint("Processing macbinary file ...\n");

    return 'Unsupported macbinary.';

    # 083 Data Fork Length
    my $size = unpack("N", substr($$contref, 83, 4));

    if ($size > $conf::FILE_SIZE_MAX) {
        return 'too_large_macbinary_file';
    }

    # 128-byte Header Size
    my $datafork = substr($$contref, 128, $size);

    my $filetype_code = substr($$contref, 65, 4);
    my $creator_code  = substr($$contref, 69, 4);
    my $mmtype = undef;
    if (($filetype_code =~ /^XLS/) && ($creator_code =~ /XCEL/)) {
        $mmtype = 'application/excel';
    } elsif (($filetype_code =~ /W.BN/) && ($creator_code =~ /MSWD/)) {
        $mmtype = 'application/msword';
    } elsif (($filetype_code =~ /(SLD8|PPSS)/) && ($creator_code =~ /^PPT/)) {
        $mmtype = 'application/powerpoint';
    } elsif (($filetype_code =~ /(SLD3)/) && ($creator_code =~ /^PPT/)) {
        # ppthtml doesn't sopport this file.
        $mmtype = 'application/powerpoint4';
    } elsif ($filetype_code =~ /^PDF/) {
        $mmtype = 'application/pdf';
    } elsif ($filetype_code =~ /^RTF/) {
        $mmtype = 'application/rtf';
    } elsif ($filetype_code =~ /TEXT/) {
        $mmtype = undef;
    }

    my $dummy_shelterfname = "";
    my $err = undef;
    my ($kanji, $mtype) = mknmz::apply_filter($orig_cfile, \$datafork,
                        $weighted_str, $headings, $fields,
                        $dummy_shelterfname, $mmtype);
    if ($mtype =~ /; x-system=unsupported$/) {
        $$contref = "";
        $err = "filter/macbinary.pl gets error from other filter";
        util::dprint($err);
        $err = $mtype;
    } elsif ($mtype =~ /; x-error=(.*)$/) {
        $$contref = "";
        $err = "filter/macbinary.pl gets error from other filter";
        util::dprint($err);
        $err = $1;
    } else {
        $$contref = $datafork;
        gfilter::show_filter_debug_info($contref, $weighted_str,
                        $fields, $headings);
    }
    return $err;
}

1;
