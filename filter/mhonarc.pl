#
# -*- Perl -*-
# $Id: mhonarc.pl,v 1.23.8.9 2013-12-15 04:01:53 opengl2772 Exp $
# Copyright (C) 1997-2000 Satoru Takabayashi ,
#               1999 NOKUBI Takatsugu ,
#               2002 Earl Hood ,
#               2000-2013 Namazu Project All rights reserved.
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

package mhonarc;
use strict;
require 'util.pl';
require 'gfilter.pl';
require 'html.pl';
require 'mailnews.pl';

#
# This pattern specifies MHonArc's file names.
# NOTE: MHonArc does allow one to customize the filename for message files.
#	So we make the regex a little flexible to handle common variations.
#
my $MHONARC_MESSAGE_FILE = '\bmsg\d+\.s?html(?:\.gz)?\Z';

sub mediatype() {
    return ('text/html; x-type=mhonarc');
}

sub status() {
    # The check of a dependence filter.
    return 'no' if (html::status() ne 'yes');
    return 'no' if (mailnews::status() ne 'yes');

    return 'yes';
}

sub recursive() {
    return 0;
}

sub pre_codeconv() {
    return 1;
}

sub post_codeconv () {
    return 0;
}

sub add_magic ($) {
    my ($magic) = @_;

    $magic->addMagicEntry('0	string		\<!--\ MHonArc		text/html; x-type=mhonarc');

    return;
}

sub filter ($$$$$) {
    my ($orig_cfile, $contref, $weighted_str, $headings, $fields)
      = @_;
    my $cfile = defined $orig_cfile ? $$orig_cfile : '';

    util::vprint("Processing MHonArc file ...\n");

    if (($cfile !~ /$MHONARC_MESSAGE_FILE/o) ||
	($$contref !~ /\A\s*<!-- MHonArc /))
    {
	return "is not a MHonArc message file! skipped."; # error
    }

    mhonarc_filter($contref, $weighted_str, $fields);
    html::html_filter($contref, $weighted_str, $fields, $headings);

    $$contref =~ s/^\s+//;
    mailnews::uuencode_filter($contref);
    mailnews::mailnews_filter($contref, $weighted_str, $fields);
    mailnews::mailnews_citation_filter($contref, $weighted_str);

    gfilter::line_adjust_filter($contref);
    gfilter::line_adjust_filter($weighted_str);
    gfilter::white_space_adjust_filter($contref);
    gfilter::show_filter_debug_info($contref, $weighted_str,
			   $fields, $headings);
    return undef;
}

# Assume a normal message files by MHonArc v2.x
sub mhonarc_filter ($$) {
    my ($contref, $weighted_str, $fields) = @_;
    my $mha_fields = { };

    my $pos = index($$contref, '<!--X-Head-End-->');
    if ($pos > 0) {
	load_mhonarc_fields($mha_fields, $weighted_str,
			    substr($$contref, 0, $pos));
    }

    # Strip off front-matter
    $pos = index($$contref, '<!--X-Head-of-Message-->');
    substr($$contref, 0, $pos + length('<!--X-Head-of-Message-->')) = "";

    # Strip off end-matter
    $pos = index($$contref, '<!--X-Body-of-Message-End-->');
    substr($$contref, $pos) = "";

    # Extract message header for separate processing, will be added back
    my $msg_header = "";
    $pos = index($$contref, '<!--X-Head-of-Message-End-->');
    if ($pos >= 0) {
	$msg_header = substr($$contref, 0, $pos);
	substr($$contref, 0, $pos) = "";
    }

    # Strip out stuff between header and body
    $pos = index($$contref, '<!--X-Body-of-Message-->');
    substr($$contref, 0, $pos + length('<!--X-Body-of-Message-->')) = "";

    # Reformat header to make it nice for mailnews filter
    if ($msg_header ne "") {
	$msg_header =~ s/\A\s+//;
	html::remove_html_elements(\$msg_header);
	$msg_header =~ s/^\s*([\w\-_]+:)/$1/gm;
	$msg_header =~ s/^([\w\-_]+:)(?:[^\n\S]*\n[^\n\S]*)+/$1 /gm;
    }

    # Format MHonArc X comment extracted headers as regular headers
    my $mha_header = "";
    for my $key (sort keys %$mha_fields) {
	$mha_header .= join('', $key, ': ', $mha_fields->{$key}, "\n");
    }

    # Added header back to content string.
    $$contref = $mha_header . $msg_header . "\n" . $$contref;

    # Return extract MHonArc fields
    #$mha_fields;
}

sub load_mhonarc_fields {
    my $fields	     = shift;
    my $weighted_str = shift;
    my $mha_head     = shift;

    if ($mha_head =~ /<!--X-Subject: ([^-]+) -->/) {
	my $subject = uncommentize($1);
        # codeconv::toeuc(\$subject);
        codeconv::codeconv_document(\$subject);
	1  while ($subject =~ s/\A\s*(re|sv|fwd|fw)[\[\]\d]*[:>-]+\s*//i);
	$subject =~ s/\A\s*\[[^\]]+\]\s*//;
	$fields->{'subject'} = $subject;
    }
    if ($mha_head =~ /<!--X-From-R13: ([^-]+) -->/) {
        my $from = mrot13(uncommentize($1));
        # codeconv::toeuc(\$from);
        codeconv::codeconv_document(\$from);
        $fields->{'from'} = $from;
    } elsif ($mha_head =~ /<!--X-From: ([^-]+) -->/) {
        my $from = uncommentize($1);
        # codeconv::toeuc(\$from);
        codeconv::codeconv_document(\$from);
        $fields->{'from'} = $from;
    }
    if ($mha_head =~ /<!--X-Message-Id: ([^-]+) -->/) {
	$fields->{'message-id'} = '&lt;' . uncommentize($1). '&gt;';
    }
    if ($mha_head =~ /<!--X-Date: ([^-]+) -->/) {
	$fields->{'date'} = uncommentize($1);
    }
}

sub uncommentize {
    my($txt) = $_[0];
    $txt =~ s/&#(\d+);/pack("C",$1)/ge;
    $txt;
}

sub mrot13 {
    my $str     = shift;
    $str =~ tr/@A-Z[a-z/N-Z[@A-Mn-za-m/;
    $str;
}

1;
