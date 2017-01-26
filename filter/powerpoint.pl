#
# -*- Perl -*-
# $Id: powerpoint.pl,v 1.6.4.27 2011-10-08 08:03:45 opengl2772 Exp $
# Copyright (C) 2000 Ken-ichi Hirose, 
#               2000-2011 Namazu Project All rights reserved.
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

package powerpoint;
use strict;
use English;
require 'util.pl';
require 'gfilter.pl';
require 'html.pl';
#eval 'require NKF;';

my $pptconvpath = undef;
my @pptconvopts = undef;
my $wvsummarypath = undef;
my $_filter = undef;

sub mediatype() {
    return ('application/powerpoint');
}

sub status() {
    # The check of a dependence filter.
    return 'no' if (html::status() ne 'yes');

    $wvsummarypath = util::checkcmd('wvSummary');

    $pptconvpath = util::checkcmd('ppthtml') || util::checkcmd('pptHtml');
#    return 'no' unless defined $pptconvpath
    if (defined $pptconvpath) {
        $_filter = \&_filter_ppt;
        @pptconvopts = ();

        if (ext::issupport('EXT_UTF8') eq 'yes') {
            return 'yes';
        }
    }

    $_filter = \&_filter_doccat;
    $pptconvpath = util::checkcmd('doccat');
    @pptconvopts = ("-o", "e");
    return 'yes' if defined $pptconvpath;
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

    # FIXME: very ad hoc.
    $magic->addFileExts('\\.pp[st]$', 'application/powerpoint');
    return;
}

sub filter ($$$$$) {
    my ($orig_cfile, $cont, $weighted_str, $headings, $fields)
        = @_;
    my $err = undef;

    $err = $_filter->($orig_cfile, $cont, $weighted_str, $headings, $fields);

    return $err;
}

sub _filter_ppt ($$$$$) {
    my ($orig_cfile, $cont, $weighted_str, $headings, $fields)
        = @_;
    my $cfile = defined $orig_cfile ? $$orig_cfile : '';

    util::vprint("Processing powerpoint file ... (using  '$pptconvpath')\n");

    my $tmpfile  = util::tmpnam('NMZ.powerpoint');
    {
        my $fh = util::efopen("> $tmpfile");
        print $fh $$cont;
        util::fclose($fh);
    }

    # get summary info in all OLE documents.
    getSummaryInfo($tmpfile, $cont, $weighted_str, $headings, $fields);
    my $title = $fields->{'title'};

    {
        # handle a Japanese PowerPoint document correctly.
        my @cmd = ($pptconvpath, @pptconvopts, $tmpfile);
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
            return "Unable to convert file ($pptconvpath error occurred).";
        } elsif ($size > $conf::FILE_SIZE_MAX) {
            util::fclose($fh_out);
            unlink $tmpfile;
            return 'Too large powerpoint file.';
        }
        $$cont = util::readfile($fh_out);
        util::fclose($fh_out);
    }
    unlink $tmpfile;

    codeconv::normalize_document($cont);

    # Code conversion for Japanese document.
    if (util::islang("ja")) {
        # Pattern for pptHtml
        if ($$cont =~ m!^<FONT SIZE=-1><I>Last Updated&nbsp;using Excel 5.0 or 95</I></FONT><br>$!m)
        {
            $$cont = codeconv::shiftjis_to_eucjp($$cont);
            codeconv::normalize_eucjp($cont);
        } else {
            $extutf8::codeconv_document->($cont);
        }
    } else {
        codeconv::tousascii($cont);
    }

    # Extract the author and exclude pptHtml's footer at once.
    $$cont =~ s!^<FONT SIZE=-1><I>Spreadsheet's Author:&nbsp;(.*?)</I></FONT><br>.*!!ms;  # '
    if (defined $1) {
        $fields->{'author'} = $1 unless (defined $fields->{'author'});
    }

    # Title shoud be removed.
    $$cont =~ s!<TITLE.*?>.*?</TITLE>!!is;

    html::html_filter($cont, $weighted_str, $fields, $headings);
    $fields->{'title'} = $title if (defined $title);

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

    util::vprint("Processing powerpoint file ... (using  '$pptconvpath')\n");

    my $tmpfile  = util::tmpnam('NMZ.powerpoint');
    {
        my $fh = util::efopen("> $tmpfile");
        print $fh $$cont;
        util::fclose($fh);
    }
    {
        my @cmd = ($pptconvpath, @pptconvopts, $tmpfile);
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
            return "Unable to convert file ($pptconvpath error occurred).";
        } elsif ($size > $conf::FILE_SIZE_MAX) {
            util::fclose($fh_out);
            unlink $tmpfile;
            return 'Too large powerpoint file.';
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

sub getSummaryInfo ($$$$$) {
    my ($cfile, $cont, $weighted_str, $headings, $fields)
        = @_;

    return undef unless (defined $wvsummarypath);

    my @cmd = ($wvsummarypath, $cfile);
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
        return undef;
    } elsif ($size > $conf::FILE_SIZE_MAX) {
        util::fclose($fh_out);
        return 'Too large summary file.';
    }

    my $summary = util::readfile($fh_out);
    util::fclose($fh_out);
    codeconv::normalize_document(\$summary);
    my $orgsummary = $summary;

    # Codepage
    #   932 : 0x000003a4 : Shift_JIS
    # 10001 : 0x00002711 : x-mac-japanese
    # 65001 : 0xfffffde9 : UTF-8


    my $codepage = "000003a4"; # Shift_JIS
    my $title = undef;
    my $subject = undef;
    my $lastauthor = undef;
    my $author = undef;
    my $keywords = undef;

    if ($summary =~ /^Codepage is 0x([0-9a-f]*)/m) {
        $codepage = sprintf("%8.8x", hex($1));
    }

    if ($codepage eq "fffffde9") {
        $extutf8::codeconv_document->(\$summary);
    } else {
        codeconv::codeconv_document(\$summary);
        codeconv::normalize_eucjp(\$summary);
    }

    if ($summary =~ /^The title is (.*)$/m) {
        my $orgtitle;

        $title = $1;

        # PowerPoint Only
        $orgsummary =~ /^The title is (.*)$/m;
        $orgtitle = $1;
        undef $title if $orgtitle eq # which has no slide title
            "\xbd\xd7\xb2\xc4\xde\x20\xc0\xb2\xc4\xd9\x82\xc8\x82\xb5";
    }
    if ($summary =~ /^The subject is (.*)$/m) {
        $subject = $1;
    }
    if ($summary =~ /^The last author was (.*)$/m) {
        $lastauthor = $1;
    }
    if ($summary =~ /^The author is (.*)$/m) {
        $author = $1;
    }
    if ($summary =~ /^The keywords are (.*)$/m) {
        $keywords = $1;
    }

    my $weight = $conf::Weight{'html'}->{'title'};
    if (defined $title) {
        $$weighted_str .= "\x7f$weight\x7f$title\x7f/$weight\x7f\n";
    }
    if (defined $subject) {
        $$weighted_str .= "\x7f$weight\x7f$subject\x7f/$weight\x7f\n";
    }

    $fields->{'title'} = $title;
    $fields->{'title'} = $subject unless (defined $title);

    $fields->{'author'} = $lastauthor;
    $fields->{'author'} = $author unless (defined $lastauthor);

    if (defined $keywords) {
        $weight = $conf::Weight{'metakey'};
        $$weighted_str .= "\x7f$weight\x7f$keywords\x7f/$weight\x7f\n";
    }

    return undef;
}

1;
