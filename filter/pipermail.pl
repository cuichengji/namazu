#
# -*- Perl -*-
# $Id: pipermail.pl,v 1.3.2.11 2008-05-09 07:36:13 opengl2772 Exp $
# Copyright (C) 2004-2008 Namazu Project All rights reserved.
#
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

package pipermail;
use strict;
require 'util.pl';
require 'gfilter.pl';
require 'html.pl';
require 'mailnews.pl';

#
# This pattern specifies pipermail's file names.
#
my $PIPERMAIL_MESSAGE_FILE = '\d{6}\.html';

sub mediatype() {
    return ('text/html; x-type=pipermail');
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
    return 0;
}

sub post_codeconv () {
    return 0;
}

sub add_magic ($) {
    return;
}

sub filter ($$$$$) {
    my ($orig_cfile, $contref, $weighted_str, $headings, $fields)
      = @_;
    my $cfile = defined $orig_cfile ? $$orig_cfile : '';
    my $dummy_weighted_str;
    my %dummy_fields = ();

    util::vprint("Processing pipermail file ...\n");

    if ($$contref !~ m/<!--beginarticle-->/s ||
    $$contref !~ m/<!--endarticle-->/s) {
        return $$orig_cfile . " is not a Pipermail message file! skipped."; # error
    }

    unless ($cfile =~ /($PIPERMAIL_MESSAGE_FILE)$/o)
    {
        return $$orig_cfile . " is not a Pipermail message file! skipped."; # error
    }

    pipermail_filter($contref, $weighted_str, $fields);
    html::html_filter($contref, \$dummy_weighted_str, \%dummy_fields, $headings);

    $$contref =~ s/^\s+//;
    mailnews::uuencode_filter($contref);
    mailnews::mailnews_filter($contref, \$dummy_weighted_str, \%dummy_fields);
    mailnews::mailnews_citation_filter($contref, \$dummy_weighted_str);

    gfilter::line_adjust_filter($contref);
    gfilter::line_adjust_filter($weighted_str);
    gfilter::white_space_adjust_filter($contref);
    gfilter::show_filter_debug_info($contref, $weighted_str,
                           $fields, $headings);
    return undef;
}

# Assume a normal message files by pipermail (mailman edition)
sub pipermail_filter ($$$) {
    my ($contref, $weighted_str, $fields) = @_;

    # Strip off end-matter
    $$contref =~ s/<!--endarticle-->.*//s;

    my $pos = index($$contref, '<!--beginarticle-->');
    if ($pos > 0) {
        my $head = substr($$contref, 0, $pos);

        util::vprint("Looking at header: " . $head . "\n");
        if ($head =~
        m!<h1>(.*?)</h1>\s*<b>(.*?)\s*</b>(?:\s*<a\s+.*?href=.*?>(.*?)\s*</a>)?\s*<br>\s*<i>(.*?)</i>!is) {
            {
                my $title = $1;
                decode_entity(\$title);
                $title = uncommentize($title);
                # codeconv::toeuc(\$title);
                codeconv::codeconv_document(\$title);

                1  while ($title =~ s/\A\s*(re|sv|fwd|fw|aw)[\[\]\d]*[:>-]+\s*//i);
                $title =~ s/\A\s*\[[^\]]+\]\s*//;
                1  while ($title =~ s/\A\s*(re|sv|fwd|fw|aw)[\[\]\d]*[:>-]+\s*//i);
                html::decode_entity(\$title);
                $fields->{'title'} = $title;

                my $weight = $conf::Weight{'html'}->{'title'};
                $$weighted_str .= "\x7f$weight\x7f$title\x7f/$weight\x7f\n";
            }

            {
                my $from = $2;
                if (defined $3) {
                    my $email = $3;
#                    $email =~ s/ at /@/s;    # no spam
#                    $email =~ s/ @ /@/s;     # no spam
                    $from .= " <$email>";
                }
                html::decode_entity(\$from);
                # codeconv::toeuc(\$from);
                codeconv::codeconv_document(\$from);
                $fields->{'from'} = $from;
            }

            {
                my $date = $4;
                html::decode_entity(\$date);
                # codeconv::toeuc(\$date);
                codeconv::codeconv_document(\$date);
                if (util::islang("ja")) {
                    if ($date =~ m/(\d{4})Ç¯\s*(\d{1,2})·î\s*(\d{1,2})Æü\s+\(.*\)\s+(\d{2}:\d{2}:\d{2})\s+(\w+)/s) {
                        my @month = (
                            "Jan", "Feb", "Mar", "Apr",
                            "May", "Jun", "Jul", "Aug",
                            "Sep", "Oct", "Nov", "Dec"
                        );
                        my $m = $month[$2 - 1];
                        $date = "Mon $m $3 $4 $5 $1";
                    }
                }
                my $err = time_to_rfc822time(\$date);
                $fields->{'date'} = $date unless(defined $err);
            }
        }
    }

    $$contref =~ s/<head>(.*)?<\/head>//si;
    $$contref =~ s/<h1>.*<!--beginarticle-->//si;
    # codeconv::toeuc($contref);
    codeconv::codeconv_document($contref);
    $$contref =~ s/ at /@/s;
    if (util::islang("ja")) {
        $$contref =~ s/ @ /@/s;
    }
}

sub uncommentize {
    my($txt) = $_[0];
    $txt =~ s/&#(\d+);/pack("C",$1)/ge;
    $txt;
}

# Decode an entity. Ignore characters of right half of ISO-8859-1.
# Because it can't be handled in EUC encoding.
# This function provides sequential entities like: &quot &lt &gt;
sub decode_entity ($) {
    my ($text) = @_;

    return unless defined($$text);

    $$text =~ s/&quot[;\s]/\"/g;
    $$text =~ s/&amp[;\s]/&/g;
    $$text =~ s/&lt[;\s]/</g;
    $$text =~ s/&gt[;\s]/>/g;
    $$text =~ s/&nbsp[;\s]/ /g;
}

my %wday_names = (
    "Sun" => 0, "Mon" => 1, "Tue" => 2, "Wed" => 3,
    "Thu" => 4, "Fri" => 5, "Sat" => 6
);
my %month_names = (
    "Jan" =>  0, "Feb" =>  1, "Mar" =>  2, "Apr" =>  3,
    "May" =>  4, "Jun" =>  5, "Jul" =>  6, "Aug" =>  7,
    "Sep" =>  8, "Oct" =>  9, "Nov" => 10, "Dec" => 11
);
my $re_wday  =  join '|', keys %wday_names;
my $re_month =  join '|', keys %month_names;
my $re_day   =  '(?:0?[1-9]|[12][0-9]|3[01])';
my $re_year  =  '(?:\d{4}|\d{2})';  # allow 2 digit fomrat
my $re_hour  =  '(?:[01][0-9]|2[0-3])';
my $re_min   =  '(?:[0-5][0-9])';
my $re_sec   =  '(?:[0-5][0-9])';

sub time_to_rfc822time ($) {
    my ($conf) = @_;

    if ($$conf =~ /
        ^\s*
        ($re_wday)\s+                         # a day of the week
        ($re_month)\s+                        # name of month
        ($re_day)\s+                          # a day of the month
        ($re_hour):($re_min):($re_sec)\s+     # HH:MM:SS
        (?:([^\s]*)\s+)?                      # (timezone)
        (\d{4})\s*                            # year
        /x)
    {
        my ($week, $month, $day, $hour, $min, $sec, $timezone, $year) =
            ($1, $2, $3, $4, $5, $6, $7, $8);

        $timezone = gettimezone() unless(defined $timezone);
        $timezone = time::normalize_rfc822timezone($timezone);

        my $mon = $month_names{$month};
        $week = ("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat")
                                [time::getwday($year, $mon + 1, $day)];

        $$conf = sprintf("%s, %2.2d %s %d %2.2d:%2.2d:%2.2d %s\n",
            $week, $day, $month, $year, $hour, $min, $sec, $timezone);

        return undef;
    }

    return "Illegal format.";
}

1;
