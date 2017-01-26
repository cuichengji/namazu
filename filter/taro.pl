#
# -*- Perl -*-
# $Id: taro.pl,v 1.7.4.9 2008-05-02 08:13:45 opengl2772 Exp $
# Copyright (C) 2000 Ken-ichi Hirose, 
#               2000-2008 Namazu Project All rights reserved.
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

package taro;
use strict;
require 'util.pl';
require 'gfilter.pl';

my $taroconvpath = undef;
my @taroconvopts = undef;

sub mediatype() {
    return qw(
        application/ichitaro5
        application/ichitaro6
        application/ichitaro7
        application/x-js-taro
    );
}

sub status() {
    $taroconvpath = util::checkcmd('doccat');
    @taroconvopts = ("-o", "e");
    return 'yes' if defined $taroconvpath;
    return 'no';
}

sub recursive() {
    return 0;
}

sub pre_codeconv() {
    return 0;
}

sub post_codeconv () {
    return 0;
}

sub add_magic ($) {
    my ($magic) = @_;

    # Justsystem Ichitaro 5
    # FIXME: very ad hoc.
    $magic->addFileExts('\\.jaw$', 'application/ichitaro5');
    # Justsystem Ichitaro 6
    # FIXME: very ad hoc.
    $magic->addFileExts('\\.jbw$', 'application/ichitaro6');
    # Justsystem Ichitaro 7
    # FIXME: very ad hoc.
    $magic->addFileExts('\\.jfw$', 'application/ichitaro7');
    # Justsystem Ichitaro 8 - 13, 2004
    # FIXME: very ad hoc.
    $magic->addFileExts('\\.jt[dt]$', 'application/x-js-taro');

    return;
}

sub filter ($$$$$) {
    my ($orig_cfile, $cont, $weighted_str, $headings, $fields)
      = @_;
    my $cfile = defined $orig_cfile ? $$orig_cfile : '';

    util::vprint("Processing taro file ... (using  '$taroconvpath')\n");

    my $tmpfile  = util::tmpnam('NMZ.taro');
    {
        my $fh = util::efopen("> $tmpfile");
        print $fh $$cont;
        util::fclose($fh);
    }
    {
        my @cmd = ($taroconvpath, @taroconvopts, $tmpfile);
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
            return "Unable to convert file ($taroconvpath error occurred).";
        }
        if ($size > $conf::FILE_SIZE_MAX) {
            util::fclose($fh_out);
            unlink $tmpfile;
            return 'Too large taro file.';
        }
        $$cont = util::readfile($fh_out);
        util::fclose($fh_out);
    }
    unlink $tmpfile;

    codeconv::normalize_eucjp_document($cont);

    gfilter::line_adjust_filter($cont);
    gfilter::line_adjust_filter($weighted_str);
    gfilter::white_space_adjust_filter($cont);
    $fields->{'title'} = gfilter::filename_to_title($cfile, $weighted_str)
        unless $fields->{'title'};
    gfilter::show_filter_debug_info($cont, $weighted_str,
                                    $fields, $headings);

    return undef;
}

1;
