#
# -*- Perl -*-
# $Id: gnumeric.pl,v 1.2.4.2 2005-12-06 19:28:59 opengl2772 Exp $
# Copyright (C) 2004 Yukio USUDA 
#               2004 Namazu Project All rights reserved ,
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

package gnumeric;
use strict;
require 'util.pl';

sub mediatype () {
    return ('application/gnumeric');
}

sub status() {
    my $gzippath = undef;
    return 'yes' if (util::checklib('Compress/Zlib.pm'));
    $gzippath = util::checkcmd('gzip');
    return 'yes' if (defined $gzippath);
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

    # gnumeric worksheet is gziped XML file.
    $magic->addSpecials("application/gnumeric",
			"^<gmr:Workbook",
			"<gmr:Attributes>",
			"<gmr:Attribute>",
			"<gmr:Summary>",);
    return;
}

sub filter ($$$$$) {
    my ($orig_cfile, $contref, $weighted_str, $headings, $fields)
        = @_;
    filter_gnumeric($contref, $weighted_str, $headings, $fields);
    gfilter::line_adjust_filter($contref);
    gfilter::line_adjust_filter($weighted_str);
    gfilter::white_space_adjust_filter($contref);
    gfilter::show_filter_debug_info($contref, $weighted_str,
                                    $fields, $headings);
    return undef;
}

sub filter_gnumeric ($$$$) {
    my ($contref, $weighted_str, $headings, $fields) = @_;

    my $authorname = gnumeric::get_author($contref);
    my $title = gnumeric::get_title($contref);
    my $keywords = gnumeric::get_keywords($contref);
    gnumeric::get_content($contref);

    gnumeric::decode_entity(\$authorname);
    gnumeric::decode_entity(\$title);
    gnumeric::decode_entity(\$keywords);
    gnumeric::decode_entity($contref);

    # Code conversion for Japanese document.
    # Japanese locarized gnumeric seem to use euc-jp code.
    if (util::islang("ja")) {
        codeconv::normalize_eucjp(\$authorname);
        codeconv::normalize_eucjp(\$title);
        codeconv::normalize_eucjp(\$keywords);
        codeconv::normalize_eucjp($contref);
    }
    if ($authorname ne ""){
        $fields->{'author'} = $authorname;
    }
    if ($title ne ""){
        $fields->{'title'} = $title;
        my $weight = $conf::Weight{'html'}->{'title'};
        $$weighted_str .= "\x7f$weight\x7f$title\x7f/$weight\x7f\n";
    }
    if ($keywords ne ""){
        my @weight_str = split(' ',$keywords);
        for my $tmp (@weight_str) {
            my $weight = $conf::Weight{'metakey'};
            $$weighted_str .= "\x7f$weight\x7f$tmp\x7f/$weight\x7f\n" if $tmp;
        }
    }
}

sub get_content ($) {
    my ($contref) = @_;
    my @content;
    push(@content, $$contref =~ m!<gmr:Cell .*?>(.*?)</gmr:Cell>!sg);
    $$contref = join("\n", @content);
}

sub get_author ($){
    my ($contref) = @_;
    my $author = "";
    if ($$contref =~ m!<gmr:name>author</gmr:name>\s+<gmr:val-string>(.*?)</gmr:val-string>!s) {
        $author = $1;
    }
    if ($author eq ""){
	if ($$contref =~ m!<gmr:name>manager</gmr:name>\s+<gmr:val-string>(.*?)</gmr:val-string>!s) {
	    $author = $1;
        }
    }
    return $author;
}

sub get_title ($){
    my ($contref) = @_;
    my $title = "";
    if ($$contref =~ m!<gmr:name>title</gmr:name>\s+<gmr:val-string>(.*?)</gmr:val-string>!s) {
        $title = $1;
    }
    return $title;
}

sub get_keywords ($){
    my ($contref) = @_;
    my $keyword = "";
    if ($$contref =~ m!<gmr:name>keywords</gmr:name>\s+<gmr:val-string>(.*?)</gmr:val-string>!s) {
        $keyword = $1;
    }
    return $keyword;
}

# Decode a numberd entity. Exclude an invalid number.
sub decode_numbered_entity ($) {
    my ($num) = @_;

    if ($num <= 127) {
        return ""
            if (($num >= 0 && $num <= 8) || ($num >= 11 && $num <= 31) ||
            $num == 127);
    } else {
        return "" if (!util::islang('ja'));
        # gnumeric use numberd entity for multibyte chars.
        # Japanese is EUC-JP.
        return "" if ($num < 0xa1 || $num > 0xfe);
    }
    chr($num);
}

# Decode an entity. Ignore characters of right half of ISO-8859-1.
# Because it can't be handled in EUC encoding.
# This function provides sequential entities like: &quot &lt &gt;
sub decode_entity ($) {
    my ($text) = @_;

    return unless defined($$text);

    $$text =~ s/&#(\d+);/decode_numbered_entity($1)/ge;
    $$text =~ s/&#x([\da-f]+)[;\s]/decode_numbered_entity(hex($1))/gei;
    $$text =~ s/&quot[;\s]/\"/g; #"
    $$text =~ s/&apos[;\s]/\'/g; #"
    $$text =~ s/&amp[;\s]/&/g;
    $$text =~ s/&lt[;\s]/</g;
    $$text =~ s/&gt[;\s]/>/g;
    $$text =~ s/&nbsp[;\s]/ /g;
}

1;
