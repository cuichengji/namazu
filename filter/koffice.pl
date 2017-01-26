#
# -*- Perl -*-
# $Id: koffice.pl,v 1.6.4.14 2009-02-17 09:11:52 opengl2772 Exp $
# Copyright (C) 2004 Yukio USUDA 
#               2004-2009 Namazu Project All rights reserved ,
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

package koffice;
use strict;
use English;
require 'util.pl';


sub mediatype () {
    #http://www.iana.org/assignments/media-types/application/
    return ('application/vnd.kde.kword',
            'application/vnd.kde.kspread',
            'application/vnd.kde.kpresenter',
	    'application/vnd.kde.kivio');
}

sub status () {
    if (ext::issupport('EXT_ZIP') eq 'yes') {
        if (ext::issupport('EXT_UTF8') eq 'yes') {
            return 'yes';
        }
    }

    return 'no';
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

    # FIXME: very ad hoc.
    $magic->addFileExts('\\.kwd$', 'application/vnd.kde.kword');
    $magic->addFileExts('\\.ksp$', 'application/vnd.kde.kspread');
    $magic->addFileExts('\\.kpr$', 'application/vnd.kde.kpresenter');
    $magic->addFileExts('\\.flw$', 'application/vnd.kde.kivio');
    return;
}

sub filter ($$$$$) {
    my ($orig_cfile, $contref, $weighted_str, $headings, $fields)
        = @_;
    my $err = undef;
    $err = filter_docinfofile($contref, $weighted_str, $fields);
#    return $err if (defined $err);
    $err = filter_maindocfile($contref, $weighted_str, $headings, $fields);
    return $err;
}

sub filter_docinfofile ($$$) {
    my ($contref, $weighted_str, $fields) = @_;

    my $xml = "";
    my $err = $extzip::zip_read->($contref, 'documentinfo.xml', \$xml);
    return $err if (defined $err);
    codeconv::normalize_nl(\$xml);

    my $authorname = koffice::get_author(\$xml);
    my $title = koffice::get_title(\$xml);
    my $abstract = koffice::get_abstract(\$xml);
    koffice::decode_entity(\$authorname);
    koffice::decode_entity(\$title);
    koffice::decode_entity(\$abstract);

    # Code conversion for Japanese document.
    $extutf8::codeconv_document->(\$authorname);
    $extutf8::codeconv_document->(\$title);
    $extutf8::codeconv_document->(\$abstract);

    if ($authorname ne "") {
        $fields->{'author'} = $authorname;
    }
    if ($title ne "") {
        $fields->{'title'} = $title;
        my $weight = $conf::Weight{'html'}->{'title'};
        $$weighted_str .= "\x7f$weight\x7f$title\x7f/$weight\x7f\n";
    }
    if ($abstract ne "") {
         $fields->{'summary'} = $abstract;
    }

    return undef;
}

sub filter_maindocfile ($$$$$) {
    my ($contref, $weighted_str, $headings, $fields) = @_;

    my $xml = "";
    my $err = $extzip::zip_read->($contref, 'maindoc.xml', \$xml);
    return $err if (defined $err);
    codeconv::normalize_nl(\$xml);

    koffice::get_kivio_content(\$xml);
    koffice::remove_all_tag(\$xml);
    koffice::decode_entity(\$xml);

    # Code conversion for Japanese document.
    $extutf8::codeconv_document->(\$xml);

    $$contref = $xml;
    gfilter::line_adjust_filter($contref);
    gfilter::line_adjust_filter($weighted_str);
    gfilter::white_space_adjust_filter($contref);
    gfilter::show_filter_debug_info($contref, $weighted_str,
                                    $fields, $headings);

    return undef;
}

sub get_author($) {
    my ($contref) = @_;
    $$contref =~ m!<author>(.*)</author>!s;
    my $authordata = $1;
    my $author = "";
    if ($authordata =~ m!<full-name>(.*)</full-name>!) {
        $author = $1;
        if ($author ne "") {
            return $author;
        }
    }
    if ($authordata =~ m!<email>(.*)</email>!) {
        $author = $1;
        if ($author ne "") {
            return $author;
        }
    }
    return $author;
}

sub get_title($) {
    my ($contref) = @_;
    $$contref =~ m!<about>(.*)</about>!s;
    my $aboutdata = $1;
    if ($aboutdata =~ m#<title>(.*)</title>#) {
        return $1;
    } else {
        return "";
    }
}

sub get_abstract($) {
    my ($contref) = @_;
    $$contref =~ m!<about>(.*)</about>!s;
    my $aboutdata = $1;
    if ($aboutdata =~ m#<abstract>(.*)</abstract>#) {
        $aboutdata = $1;
        $aboutdata =~ s/<!\[CDATA\[//;
        $aboutdata =~ s/\]\]>//;
        return $aboutdata;
    } else {
        return "";
    }
}

sub get_kivio_content ($) {
    my ($contref) = @_;
    my @content;
    push(@content, $$contref =~ m!<KivioTextStyle .*?text="(.*?)"!sg);
    $$contref .= join("\n", @content);
}

sub remove_all_tag($) {
  my ($contref) = @_;
      $$contref =~ s/<[^>]*>/\n/gs;
      $$contref =~ s/\n+/\n/gs;
      $$contref =~ s/^\n+//;
}

# Decode a numberd entity. Exclude an invalid number.
sub decode_numbered_entity($) {
    my ($num) = @_;
    return ""
        if $num >= 0 && $num <= 8 ||  $num >= 11 && $num <= 31 || $num >=127;
    sprintf ("%c",$num);
}

# Decode an entity. Ignore characters of right half of ISO-8859-1.
# Because it can't be handled in EUC encoding.
# This function provides sequential entities like: &quot &lt &gt;
sub decode_entity($) {
    my ($text) = @_;

    return unless defined($$text);

    $$text =~ s/&#(\d{2,3})[;\s]/decode_numbered_entity($1)/ge;
    $$text =~ s/&#x([\da-f]+)[;\s]/decode_numbered_entity(hex($1))/gei;
    $$text =~ s/&quot[;\s]/\"/g; #"
    $$text =~ s/&apos[;\s]/\'/g; #"
    $$text =~ s/&amp[;\s]/&/g;
    $$text =~ s/&lt[;\s]/</g;
    $$text =~ s/&gt[;\s]/>/g;
    $$text =~ s/&nbsp[;\s]/ /g;
}

1;
