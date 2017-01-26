#
# -*- Perl -*-
# $Id: gzip.pl,v 1.16.8.5 2005-06-06 06:13:34 opengl2772 Exp $
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

package gzip;
use strict;
require 'util.pl';

my $gzippath = undef;
my @gzipopts = undef;

sub mediatype() {
    return ('application/x-gzip');
}

sub status() {
    return 'yes' if (util::checklib('Compress/Zlib.pm'));
    $gzippath = util::checkcmd('gzip');
    @gzipopts = ("-cd");
    return 'yes' if (defined $gzippath);
    return 'no';
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
    my $err = undef;

    if (util::checklib('Compress/Zlib.pm')) {
	$err = filter_xs($cont);
    } else {
	$err = filter_file($cont);
    }
    return $err;
}

sub filter_file ($) {
    my ($contref) = @_;

    util::vprint("Processing gzip file ... (using  '$gzippath')\n");

    my $tmpfile = util::tmpnam('NMZ.gzip');
    {
	my $fh = util::efopen("> $tmpfile");
	print $fh $$contref;
        util::fclose($fh);
    }
    {
	my @cmd = ($gzippath, @gzipopts, $tmpfile);
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
	    return "Unable to convert file ($gzippath error occurred)";
	}
	if ($size > $conf::FILE_SIZE_MAX) {
            util::fclose($fh_out);
            unlink $tmpfile;
	    return 'Too large gzipped file';
	}
	$$contref = util::readfile($fh_out);
        util::fclose($fh_out);
    }
    unlink $tmpfile;

    return undef;
}

sub filter_xs ($) {
    my ($contref) = @_;

    util::vprint("Processing gzip file ... (using  Compress::Zlib)\n");

    eval 'use Compress::Zlib;';

    my $offset = 0;
    $offset += 3;
    my $flags = unpack('C', substr($$contref, $offset, 1));
    $offset += 1;
    $offset += 6;
    $$contref = substr($$contref, $offset);
    $$contref = substr($$contref, 2) if ($flags & 0x04);
    $$contref =~ s/^[^\0]*\0// if ($flags & 0x08);
    $$contref =~ s/^[^\0]*\0// if ($flags & 0x10);
    $$contref = substr($$contref, 2) if ($flags & 0x02);

    my $zl = inflateInit(-WindowBits => - MAX_WBITS());
    my ($inf, $stat) = $zl->inflate($$contref);
    if ($stat == Z_OK() or $stat == Z_STREAM_END()) {
	$$contref = $inf;
    } else {
	$$contref = '';
	return 'Bad compressed data.';
    }

    return undef;
}

1;
