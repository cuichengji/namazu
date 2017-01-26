#
# -*- Perl -*-
# $Id: gfilter.pl,v 1.1.2.6 2006-04-16 12:48:49 opengl2772 Exp $
# Copyright (C) 1999 Satoru Takabayashi ,
#               2000-2006 Namazu Project All rights reserved.
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

package gfilter;
use English;

# Show debug information for filters
sub show_filter_debug_info ($$$$) {
    my ($contref, $weighted_str, $fields, $headings) = @_;
    util::dprint("-- title --\n$fields->{'title'}\n") 
	if defined $fields->{'title'};
    util::dprint("-- content --\n$$contref\n");
    util::dprint("-- weighted_str: --\n$$weighted_str\n");
    util::dprint("-- headings --\n$$headings\n");
}

# Adjust white spaces
sub white_space_adjust_filter ($) {
    my ($text) = @_;
    return undef unless defined($$text);

    $$text =~ s/[ \t]+/ /g;
    $$text =~ s/\r\n/\n/g;
    $$text =~ s/\r/\n/g;
    $$text =~ s/\n+/\n/g;
    $$text =~ s/^ +//gm;
    $$text =~ s/ +$//gm;
    $$text =~ s/ +/ /g;
    # Control characters be into space
    $$text =~ tr/\x00-\x09\x0b-\x1f/  /;
}

# get a title from a file name.
sub filename_to_title ($$) {
    my ($cfile, $weighted_str) = @_;

    # for MSWin32's filename using Shift_JIS [1998-09-24]
    if (($English::OSNAME eq "MSWin32") || ($English::OSNAME eq "os2")) {
	$cfile = codeconv::shiftjis_to_eucjp($cfile);
	codeconv::eucjp_han2zen_kana(\$cfile);
    }

    codeconv::normalize_eucjp(\$cfile);

    my $filename = $cfile;
    $filename = $1 if ($cfile =~ m!^.*/([^/]*)$!);

    # get keywords from a file name.
    # modified [1998-09-18] 
    my $tmp = $filename;
    $tmp =~ tr|/\\_\.-| |;

    my $weight = $conf::Weight{'html'}->{'title'};
    $$weighted_str .= "\x7f$weight\x7f$tmp\x7f/$weight\x7f\n";

    my $title = $filename;
    return $title
}

# Remove SPACE/TAB at the beginning or ending of the line.
# And remove '>|#:' at the begenning of the line.
# Join hyphenation for English text.
# Remove LF if the line is ended with a Japanese character and 
# length of the line is 40 or more longer.
#
# Original of this code was contributed by <furukawa@tcp-ip.or.jp>. 
# [1997-09-15]
#
sub line_adjust_filter ($) {
    my ($text) = @_;
    return undef unless defined($$text);

    my @tmp = split(/\n/, $$text);
    for my $line (@tmp) {
	$line .= "\n";
	$line =~ s/^[ \>\|\#\:]+//;
	$line =~ s/ +$//;
	$line =~ s/\n// if (($line =~ /[\xa1-\xfe]\n*$/) &&
			    (length($line) >=40));
	$line =~ s/(¡£|¡¢)$/$1\n/;
	$line =~ s/([a-z])-\n/$1/;  # for hyphenation.
    }
    $$text = join('', @tmp);
}

# not implimented yet.
sub analize_rcs_stamp()
{
}

1;

