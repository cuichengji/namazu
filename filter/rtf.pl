#
# -*- Perl -*-
# $Id: rtf.pl,v 1.3.2.18 2008-05-02 08:13:45 opengl2772 Exp $
# Copyright (C) 2003-2008 Tadamasa Teranishi All rights reserved.
#               2003-2008 Namazu Project All rights reserved.
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

package rtf;
use strict;
require 'util.pl';
require 'gfilter.pl';
require 'html.pl';

my $rtfconvpath  = undef;
my @rtfconvopts  = undef;
my $_filter = undef;

sub mediatype() {
    return ('application/rtf');
}

sub status() {
    # The check of a dependence filter.
    return 'no' if (html::status() ne 'yes');

    #
    # http://www.45.free.net/~vitus/ice/misc/rtf2html.tar.gz
    #
    $rtfconvpath = util::checkcmd('rtf2html');
    if (defined $rtfconvpath) {
        @rtfconvopts = ();
        $_filter = \&_filter_rtf2html;
        return 'yes';
    }

    $rtfconvpath = util::checkcmd('doccat');
    @rtfconvopts = ("-o", "e");
    if (defined $rtfconvpath) {
        $_filter = \&_filter_doccat;

        my @cmd = ("$rtfconvpath", "-V");
        my $fh_cmd = IO::File->new_tmpfile();
        my $status = util::syscmd(
            command => \@cmd,
            option => {
                "stdout" => $fh_cmd,
                "stderr" => "/dev/null",
            },
        );

        while (<$fh_cmd>) {
            if (/TF Library *: *Version *: *(\d+\.\d+)/i) {
                my $ver = $1;
                if ($ver >= 1.42) {
                    util::fclose($fh_cmd);
                    return 'yes';
                }
            }
        }
        util::fclose($fh_cmd);
    }
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

    $magic->addMagicEntry("0\tstring\t{\\rtf\t");
    $magic->addMagicEntry(">6\tstring\t\\ansi\tapplication/rtf");
    $magic->addMagicEntry(">6\tstring\t\\mac\tapplication/rtf");
    $magic->addMagicEntry(">6\tstring\t\\pc\tapplication/rtf");
    $magic->addMagicEntry(">6\tstring\t\\pca\tapplication/rtf");

    # FIXME: very ad hoc.
    $magic->addFileExts('\\.rtf$', 'application/rtf');

    return;
}

sub filter ($$$$$) {
    my ($orig_cfile, $cont, $weighted_str, $headings, $fields)
        = @_;
    my $err = undef;

    $err = $_filter->($orig_cfile, $cont, $weighted_str, $headings, $fields);

    return $err;
}

sub _filter_rtf2html ($$$$$) {
    my ($orig_cfile, $cont, $weighted_str, $headings, $fields)
      = @_;
    my $cfile = defined $orig_cfile ? $$orig_cfile : '';

    util::vprint("Processing rtf file ... (using  '$rtfconvpath')\n");

    # rtf2html : Fixed the problem in [namazu-devel-ja#03530].
    $$cont =~ s/\x5c$//gm;

    my $tmpfile = util::tmpnam('NMZ.rtf');
    util::writefile($tmpfile, $cont);
    {
        my @cmd = ($rtfconvpath, @rtfconvopts, $tmpfile);
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
            return "Unable to convert file ($rtfconvpath error occurred).";
        }
        if ($size > $conf::FILE_SIZE_MAX) {
            util::fclose($fh_out);
            unlink $tmpfile;
            return 'Too large rtf file.';
        }
        $$cont = util::readfile($fh_out);
        util::fclose($fh_out);
    }
    unlink $tmpfile;

    # codeconv::toeuc($cont);
    codeconv::codeconv_document($cont);

    # Title shoud be removed.
    $$cont =~ s!<TITLE.*?>.*?</TITLE>!!is;

    html::html_filter($cont, $weighted_str, $fields, $headings);

    gfilter::line_adjust_filter($cont);
    gfilter::line_adjust_filter($weighted_str);
    gfilter::white_space_adjust_filter($cont);
    $fields->{'title'} = gfilter::filename_to_title($cfile, $weighted_str)
        unless $fields->{'title'};
    gfilter::show_filter_debug_info($cont, $weighted_str,
                                    $fields, $headings);
    return undef;
}

sub _filter_doccat ($$$$$) {
    my ($orig_cfile, $cont, $weighted_str, $headings, $fields)
        = @_;
    my $cfile = defined $orig_cfile ? $$orig_cfile : '';

    util::vprint("Processing rtf file ... (using  '$rtfconvpath')\n");

    my $tmpfile = util::tmpnam('NMZ.rtf');
    util::writefile($tmpfile, $cont);
    {
        my @cmd = ($rtfconvpath, @rtfconvopts, $tmpfile);
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
            return "Unable to convert file ($rtfconvpath error occurred).";
        }
        if ($size > $conf::FILE_SIZE_MAX) {
            util::fclose($fh_out);
            unlink $tmpfile;
            return 'Too large rtf file.';
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
