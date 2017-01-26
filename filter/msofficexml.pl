#
# -*- Perl -*-
# $Id: msofficexml.pl,v 1.2.2.20 2009-02-17 09:11:52 opengl2772 Exp $
# Copyright (C) 2007 Yukio USUDA, 
#               2007-2009 Namazu Project All rights reserved.
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

package msofficexml;
use strict;
use English;
require 'util.pl';
require 'gfilter.pl';
require 'ooo.pl';
require 'zip.pl';


sub mediatype() {
    return (
        'application/vnd.openxmlformats-officedocument.wordprocessingml',
        'application/vnd.openxmlformats-officedocument.spreadsheetml',
        'application/vnd.openxmlformats-officedocument.presentationml',
    );
}

sub status() {
    if (ext::issupport('EXT_ZIP') eq 'yes') {
        if (ext::issupport('EXT_UTF8') eq 'yes') {
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
    $magic->addFileExts('\\.docx$', 'application/vnd.openxmlformats-officedocument.wordprocessingml');
    $magic->addFileExts('\\.xlsx$', 'application/vnd.openxmlformats-officedocument.spreadsheetml');
    $magic->addFileExts('\\.pp[st]x$', 'application/vnd.openxmlformats-officedocument.presentationml');
    return;
}

sub filter ($$$$$) {
    my ($orig_cfile, $contref, $weighted_str, $headings, $fields)
        = @_;
    my $cfile = defined $orig_cfile ? $$orig_cfile : '';
    my $ext = '';
    if ($cfile =~ m/\.([A-Za-z]{4})$/) {
        $ext = $1;
    }
    my $err = undef;
    $err = filter_metafile($contref, $weighted_str, $fields);
#    return $err if (defined $err);
    $err = filter_contentfile($contref, $weighted_str, $headings, $fields, $ext);
    return $err;
}

sub filter_metafile ($$$) {
    my ($contref, $weighted_str, $fields) = @_;

    my $metafile = 'docProps/core.xml';
    my $xml = "";
    my $err = $extzip::zip_read->($contref, $metafile, \$xml);
    return $err if (defined $err);
    codeconv::normalize_nl(\$xml);

    my $authorname = ooo::get_author(\$xml);
    my $title = ooo::get_title(\$xml);
    my $keywords = msofficexml::get_keywords(\$xml);
    ooo::decode_entity(\$authorname);
    ooo::decode_entity(\$title);
    ooo::decode_entity(\$keywords);

    # Code conversion for Japanese document.
    $extutf8::codeconv_document->(\$authorname);
    $extutf8::codeconv_document->(\$title);
    $extutf8::codeconv_document->(\$keywords);

    if (!($authorname eq "")) {
        $fields->{'author'} = $authorname;
    }
    if (!($title eq "")) {
        $fields->{'title'} = $title;
        my $weight = $conf::Weight{'html'}->{'title'};
        $$weighted_str .= "\x7f$weight\x7f$title\x7f/$weight\x7f\n";
    }
    my @weight_str = split(' ',$keywords);
    for my $tmp (@weight_str) {
        my $weight = $conf::Weight{'metakey'};
        $$weighted_str .= "\x7f$weight\x7f$tmp\x7f/$weight\x7f\n" if $tmp;
    }

    return undef;
}

sub get_embedded_list ($$$) {
    my ($zipref, $embeddingsref, $apptype) = @_;

    my $pattern = "$apptype/embeddings/.+";    # embeddings filename
    my $err = $extzip::zip_membersMatching->($zipref, $pattern, $embeddingsref);
    return $err;
}

sub filter_contentfile ($$$$$) {
    my ($contref, $weighted_str, $headings, $fields, $ext) = @_;
    my @contentfile;
    my @embeddedfiles;
    my $xml = "";
    if ($ext =~ /docx/i) {
        $contentfile[0] = 'word/document.xml';
        my $err = get_embedded_list($contref, \@embeddedfiles, 'word');
        return $err if (defined $err);
    } elsif ($ext =~ /xlsx/i) {
        $contentfile[0] = 'xl/sharedStrings.xml';
        my $err = get_embedded_list($contref, \@embeddedfiles, 'xl');
        return $err if (defined $err);
    } elsif ($ext =~ /pp(t|s)x/i) {
        my $filename = 'docProps/app.xml';
        my $err = $extzip::zip_read->($contref, $filename, \$xml);
        return $err if (defined $err);
        codeconv::normalize_nl(\$xml);

        my $slides = 1;
        if ($xml =~ m!<Slides>(\d)</Slides>!) {
            $slides = $1;
        }
        for (my $i = 1; $i <= $slides; $i++) {
            $contentfile[$i-1] = 'ppt/slides/slide' . $i . '.xml';
        }
        $err = get_embedded_list($contref, \@embeddedfiles, 'ppt');
        return $err if (defined $err);
    }
    $xml = "";
    foreach my $filename (@contentfile) {
        my $xmlcont = '';
        my $err = $extzip::zip_read->($contref, $filename, \$xmlcont);
        return $err if (defined $err);
        codeconv::normalize_nl(\$xmlcont);
        $xml .= $xmlcont
    }
    if ($ext =~ /xlsx/i) {
        my $xmlcont = '';
        my $filename = 'xl/workbook.xml';
        my $err = $extzip::zip_read->($contref, $filename, \$xmlcont);
        return $err if (defined $err);
        codeconv::normalize_nl(\$xmlcont);
        $xml .= msofficexml::get_sheetname(\$xmlcont);
    }

    msofficexml::remove_txbodytag(\$xml);
    ooo::remove_all_tag(\$xml);
    ooo::decode_entity(\$xml);

    # Code conversion for Japanese document.
    $extutf8::codeconv_document->(\$xml);

    my $embeddedcont = '';
    if (@embeddedfiles) {
        foreach my $fname (@embeddedfiles) {
            my $cont = '';
            my $err = $extzip::zip_read->($contref, $fname, \$cont);
            return $err if (defined $err);
            my $unzippedname = "unzipped_content";
            if ($fname =~ /.*(\..*)/) {
                $unzippedname = $unzippedname . $1;
            }
            $err = zip::nesting_filter($unzippedname, \$cont, $weighted_str);
            if (defined $err) {
                util::dprint("filter/zip.pl gets error message \"$err\"");
            }
            $embeddedcont .= " " . $cont;
        }
    }
    $$contref = $xml . $embeddedcont;

    gfilter::line_adjust_filter($contref);
    gfilter::line_adjust_filter($weighted_str);
    gfilter::white_space_adjust_filter($contref);
    gfilter::show_filter_debug_info($contref, $weighted_str,
                                    $fields, $headings);

    return undef;
}

sub get_keywords ($) {
    my ($contref) = @_;
    my @keywordstmp;
    push(@keywordstmp, $$contref =~ m!<cp:keywords>(.*)</cp:keywords>!g);
    return join(" ", @keywordstmp);
}

sub get_sheetname ($) {
    my ($contref) = @_;
    my @sheetnames;
    push(@sheetnames, $$contref =~ m!<sheet name="([^"]*)"!g);
    return join(" ", @sheetnames);
}

sub remove_txbodytag($) {
    my ($contref) = @_;
    my $txbodies = '';
    while ($$contref =~ m!<p:txBody>(.*?)</p:txBody>!sg) {
       my $txbody = $1;
       $txbody =~ s/<a:p>/\n/gs;
       $txbody =~ s/<[^>]*>//gs;
       $txbodies .= " " . $txbody;
    }
    $$contref =~ s!<p:txBody>(.*?)</p:txBody>!!sg;
    $$contref .= $txbodies;
}

1;
