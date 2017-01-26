#
# -*- Perl -*-
# $Id: visio.pl,v 1.1.4.9 2010-05-31 14:42:37 opengl2772 Exp $
# Copyright (C) 2007-2009 Tadamasa Teranishi All rights reserved.
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
#

package visio;
use strict;
require 'ooo.pl';

sub mediatype() {
    return ('application/vnd.visio; x-type=vdx');
}

sub status() {
    if (ext::issupport('EXT_UTF8') eq 'yes') {
        return 'yes';
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

    $magic->addSpecials('application/vnd.visio; x-type=vdx',
                        '^<VisioDocument\s',);

    return;
}

sub filter ($$$$$) {
    my ($orig_cfile, $contref, $weighted_str, $headings, $fields)
        = @_;
    filter_visio($contref, $weighted_str, $headings, $fields);
    gfilter::line_adjust_filter($contref);
    gfilter::line_adjust_filter($weighted_str);
    gfilter::white_space_adjust_filter($contref);
    gfilter::show_filter_debug_info($contref, $weighted_str,
                                    $fields, $headings);
    return undef;
}

sub filter_visio ($$$$) {
    my ($contref, $weighted_str, $headings, $fields) = @_;

    my $authorname = visio::get_author($contref);
    my $title = visio::get_title($contref);
    my $keywords = visio::get_keywords($contref);
    visio::get_content($contref);

    ooo::decode_entity(\$authorname);
    ooo::decode_entity(\$title);
    ooo::decode_entity(\$keywords);
    ooo::decode_entity($contref);

    # Code conversion for Japanese document.
    $extutf8::codeconv_document->(\$authorname);
    $extutf8::codeconv_document->(\$title);
    $extutf8::codeconv_document->(\$keywords);
    $extutf8::codeconv_document->($contref);

    if ($authorname ne "") {
        $fields->{'author'} = $authorname;
    }
    if ($title ne "") {
        $fields->{'title'} = $title;
        my $weight = $conf::Weight{'html'}->{'title'};
        $$weighted_str .= "\x7f$weight\x7f$title\x7f/$weight\x7f\n";
    }
    if ($keywords ne "") {
        my @weight_str = split(' ',$keywords);
        for my $tmp (@weight_str) {
            my $weight = $conf::Weight{'metakey'};
            $$weighted_str .= "\x7f$weight\x7f$tmp\x7f/$weight\x7f\n" if $tmp;
        }
    }
}

sub get_content ($) {
    my ($contref) = @_;
    $$contref =~ m!<Pages>(.*)</Pages>!s;
    my $pages = $1;
    my @content;
    push(@content, $pages =~ m!<Text>(.*?)</Text>!sg);
    $$contref = join("\n", @content);
    ooo::remove_all_tag($contref);
}

sub get_author ($) {
    my ($contref) = @_;
    my $author = "";
    if ($$contref =~ m!<Creator>(.*?)</Creator>!s) {
        $author = $1;
    }
    if ($author eq "") {
        if ($$contref =~ m!<Manager>(.*?)</Manager>!s) {
            $author = $1;
        }
    }
    return $author;
}

sub get_title ($) {
    my ($contref) = @_;
    my $title = "";
    if ($$contref =~ m!<Title>(.*?)</Title>!s) {
        $title = $1;
    }
    return $title;
}

sub get_keywords ($) {
    my ($contref) = @_;
    my $keyword = "";
    if ($$contref =~ m!<Keywords>(.*?)</Keywords>!s) {
        $keyword = $1;
    }
    return $keyword;
}

1;
