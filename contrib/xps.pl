#
# -*- Perl -*-
# $Id: xps.pl,v 1.1.2.1 2007-02-23 05:02:43 opengl2772 Exp $
# Copyright (C) 2007 Yukio USUDA, 
#               2007 Namazu Project All rights reserved.
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

package xps;
use strict;
use English;
require 'util.pl';
require 'gfilter.pl';
require 'ooo.pl';
require 'msofficexml.pl';

my $utfconvpath = undef;
my $unzippath = undef;
my @unzipopts;

sub mediatype() {
    return (
        'application/vnd.ms-xpsdocument',
    );
}

sub status() {
    $unzippath = util::checkcmd('unzip');
    if (defined $unzippath){
        @unzipopts = ("-p");
        if (util::islang("ja")) {
           if (($conf::NKF eq 'module_nkf') && ($NKF::VERSION >= 2.00)) {
               return 'yes';
           }
           return 'no'; 
        } else {
           return 'yes'; 
        }
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

    # FIXME: very ad hoc.
    $magic->addFileExts('\\.xps$', 'application/vnd.ms-xpsdocument');
    return;
}

sub filter ($$$$$) {
    my ($orig_cfile, $contref, $weighted_str, $headings, $fields)
        = @_;
    my $cfile = defined $orig_cfile ? $$orig_cfile : '';
    msofficexml::filter_metafile($contref, $weighted_str, $fields);
    filter_contentfile($contref, $weighted_str, $headings, $fields);
    return undef;
}

sub zip_read ($$$) {
    my ($zipref, $fname, $unzipcontref) = @_;
    my $tmpfile;
    my $uniqnumber = int(rand(10000));
    do {
        $tmpfile = util::tmpnam('NMZ.zip' . substr("000$uniqnumber", -4));
        $uniqnumber++;
    } while (-f $tmpfile);
    { 
        my $fh = util::efopen("> $tmpfile");
        print $fh $$zipref;
        util::fclose($fh);
    }
    my @cmd = ($unzippath, @unzipopts, $tmpfile, $fname);
    my $status = util::syscmd(
        command => \@cmd,
        option => {
            "stdout" => $unzipcontref,
            "stderr" => "/dev/null",
            "mode_stdout" => "wb",
            "mode_stderr" => "wt",
        },
    );
    unlink $tmpfile;
}

sub get_pages_list ($$) {
    my ($zipref, $pagesref) = @_;
    my $tmpfile  = util::tmpnam('NMZ.zip');
    { 
        my $fh = util::efopen("> $tmpfile");
        print $fh $$zipref;
        util::fclose($fh);
    }
    my @unzipopts_getlist = ("-Z", "-1");
    my @cmd = ($unzippath, @unzipopts_getlist, $tmpfile);
    my $file_list;
    my $status = util::syscmd(
        command => \@cmd,
        option => {
            "stdout" => \$file_list,
            "stderr" => "/dev/null",
            "mode_stdout" => "wt",
            "mode_stderr" => "wt",
        },
    );
    if ($status == 0) {
        while ($file_list =~ m!\n
            (Documents/1/Pages/\d+\.fpage)!gx){
            my $filename = $1;
            push(@$pagesref, $filename);
        }
    }
    unlink $tmpfile;
}

sub filter_contentfile ($$$$$) {
    my ($contref, $weighted_str, $headings, $fields) = @_;
    my @pagefiles;
    my $xml = "";

    get_pages_list($contref, \@pagefiles);
    foreach my $filename (@pagefiles){
        my $xmlcont = '';
        xps::zip_read($contref, $filename, \$xmlcont);
        codeconv::toeuc(\$xmlcont);
        xps::get_document(\$xmlcont);
        $xml .= ' ' . $xmlcont
    }

    ooo::remove_all_tag(\$xml);
    ooo::decode_entity(\$xml);

    # Code conversion for Japanese document.
    if (util::islang("ja")) {
        codeconv::normalize_eucjp(\$xml);
    }

    $$contref = $xml;

    gfilter::line_adjust_filter($contref);
    gfilter::line_adjust_filter($weighted_str);
    gfilter::white_space_adjust_filter($contref);
    gfilter::show_filter_debug_info($contref, $weighted_str,
                                    $fields, $headings);
}

sub get_keywords ($) {
    my ($contref) = @_;
    my @keywordstmp;
    push(@keywordstmp ,$$contref =~ m!<cp:keywords>(.*)</cp:keywords>!g);
    return  join(" ",@keywordstmp);
}

sub get_document ($) {
    my ($contref) = @_;
    my @documents;
    push(@documents ,$$contref =~ m!UnicodeString="([^"]*)"!g);
    $$contref = join(" ",@documents);
}

1;
