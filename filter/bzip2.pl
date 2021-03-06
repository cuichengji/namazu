#
# -*- Perl -*-
# $Id: bzip2.pl,v 1.16.8.3 2005-06-06 06:13:34 opengl2772 Exp $
# Copyright (C) 2000-2004 Namazu Project All rights reserved ,
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

package bzip2;
use strict;
require 'util.pl';

my $bzip2path = undef;
my @bzip2opts = undef;

sub mediatype() {
    return ('application/x-bzip2');
}

sub status() {
    $bzip2path = util::checkcmd('bzip2');
    @bzip2opts = ("-cd");
    return 'no' unless (defined $bzip2path);
    return 'yes';
}

sub recursive() {
    return 1;
}

sub pre_codeconv() {
    return 0;
}

sub post_codeconv () {
    return 0;
}

sub add_magic ($) {
    return;
}

sub filter ($$$$$) {
    my ($orig_cfile, $cont, $weighted_str, $headings, $fields)
	= @_;

    util::vprint("Processing bzip2 file ... (using  '$bzip2path')\n");

    my $tmpfile = util::tmpnam('NMZ.bzip2');
    {
	my $fh = util::efopen("> $tmpfile");
	print $fh $$cont;
        util::fclose($fh);
    }
    {
	my @cmd = ($bzip2path, @bzip2opts, $tmpfile);
        my $fh_out = IO::File->new_tmpfile();
        my $status = util::syscmd(
            command => \@cmd,
            option => {
                "stdout" => $fh_out,
                "stderr" => "/dev/null",
            },
        );
	my $size = util::filesize($fh_out);
	if ($size == 0) {
            util::fclose($fh_out);
            unlink $tmpfile;
	    return "Unable to convert file ($bzip2path error occurred)";
	}
	if ($size > $conf::FILE_SIZE_MAX) {
            util::fclose($fh_out);
            unlink $tmpfile;
	    return 'Too large bzipped file';
	}
	$$cont = util::readfile($fh_out);
        util::fclose($fh_out);
    }
    unlink $tmpfile;

    return undef;
}

1;
