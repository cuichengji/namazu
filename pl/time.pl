#
# -*- Perl -*-
# $Id: time.pl,v 1.5.2.5 2009-01-28 17:58:50 opengl2772 Exp $
# Copyright (C) 2004-2009 Tadamasa Teranishi
#               2004-2009 Namazu Project All rights reserved.
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

package time;
use strict;
use Time::Local;

#
# get timezone :
#      time::gettimezone() or time::timezone(-timelocal(gmtime(0)))
#
# 'JST' -> '+0900' :
#      my $zone = time::timezone($zone{'JST'} * 3600);
#
# ctime -> rfc822time :
#      my $time = "Sun Jan 11 16:38:39 2004";
#      my $err = time::ctime_to_rfc822time(\$time);
#
# "15 Jan 2004 05:09 JST" -> "Thu, 15 Jan 2004 05:09:00 +0900" :
#      my $time = "15 Jan 2004 05:09 JST";
#      my $err = time::normalize_rfc822time(\$time);
#
# rfc822time -> mtime :
#      my $mtime = rfc822time_to_mtime("15 Jan 2004 05:09 +0900");
#

my %zone = (
    "UT"  =>   0, "GMT" =>   0,
    "EST" =>  -5, "EDT" =>  -4,
    "CST" =>  -6, "CDT" =>  -5,
    "MST" =>  -7, "MDT" =>  -6,
    "PST" =>  -8, "PDT" =>  -7,

    "JST" =>  +9,                       # illegal timezone

    "A"   =>  +1, "B"   =>  +2, "C"   =>  +3, "D"   =>  +4,
    "E"   =>  +5, "F"   =>  +6, "G"   =>  +7, "H"   =>  +8,
    "I"   =>  +9,

    "K"   => +10, "L"   => +11, "M"   => +12,

    "N"   =>  -1, "O"   =>  -2, "P"   =>  -3, "Q"   =>  -4,
    "R"   =>  -5, "S"   =>  -6, "T"   =>  -7, "U"   =>  -8,
    "V"   =>  -9, "W"   => -10, "X"   => -11, "Y"   => -12,

    "Z"   =>   0,

    "a"   =>  +1, "b"   =>  +2, "c"   =>  +3, "d"   =>  +4,
    "e"   =>  +5, "f"   =>  +6, "g"   =>  +7, "h"   =>  +8,
    "i"   =>  +9,

    "k"   => +10, "l"   => +11, "m"   => +12,

    "n"   =>  -1, "o"   =>  -2, "p"   =>  -3, "q"   =>  -4,
    "r"   =>  -5, "s"   =>  -6, "t"   =>  -7, "u"   =>  -8,
    "v"   =>  -9, "w"   => -10, "x"   => -11, "y"   => -12,

    "z"   =>   0,
);

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

sub timezone ($) {
    my ($time) = @_;

    my $hour = int($time / 3600);
    my $min = abs(int(($time - $hour * 3600) / 60));

    my $timezone = sprintf("%+2.2d%2.2d", $hour, $min);

    return $timezone;
}

sub gettimezone {
    return timezone(timelocal(localtime(1000000)) - timelocal(gmtime(1000000)));
}

sub getwday {
    my ($year, $month, $day) = @_;

    if ($month == 1 or $month == 2) {
        $year--;
        $month += 12;
    }

    return ($year + int($year / 4) - int($year/100) + int($year / 400)
        + int((13 * $month + 8) / 5) + $day) % 7;
}

sub normalize_rfc822timezone ($) {
    my ($timezone) = @_;

    if ($timezone =~ /^(JST)$/) {             # convert illegal timezone.
                                              # "JST" -> "+0900"
        return timezone($zone{"$1"} * 3600);
    } elsif ($timezone eq "+0000") {          # convert "+0000" -> "GMT"
        return "GMT";
    } elsif ($timezone =~ /^[+-]\d{2}[0-5][0-9]$/) {
                                              # ( ("+" / "-") 4DIGIT )
        return $timezone;
    } elsif (exists $zone{$timezone}) {
        return $timezone;
    } else {
        return "-0000";
    }
}

sub ctime_to_rfc822time ($) {
    my ($conf) = @_;

    my $ctime = $$conf;

    if ($ctime =~ /
        ^\s*
        ($re_wday)\s+                         # a day of the week
        ($re_month)\s+                        # name of month
        ($re_day)\s+                          # a day of the month
        ($re_hour):($re_min):($re_sec)\s+     # HH:MM:SS
        (\d{4})\s*                            # year
        /x)
    {
        my ($week, $month, $day, $hour, $min, $sec, $year) =
            ($1, $2, $3, $4, $5, $6, $7);

        my $timezone = gettimezone();

        $$conf = sprintf("%s, %2.2d %s %d %2.2d:%2.2d:%2.2d %s\n",
            $week, $day, $month, $year, $hour, $min, $sec, $timezone);

        return undef;
    }

    return "Illegal format.";
}

sub normalize_rfc822time ($) {
    my ($datetime) = @_;

    if ($$datetime =~ /
        ^\s*
        (?:($re_wday),\s+)?                   # (a day of the week (ignored))
        ($re_day)\s+                          # a day of the month
        ($re_month)\s+                        # name of month
        ($re_year)\s+                         # year
        ($re_hour):($re_min)(?::($re_sec))?   # HH:MM(:SS)
        (?:\s+([^\s]*))?\s*                   # (timezone)
        /x)
    {

        my ($mday, $month_name, $year, $hour, $min, $sec, $timezone) =
            ($2, $3, $4, $5, $6, $7, $8);

        $timezone = gettimezone() unless($timezone);
        $timezone = normalize_rfc822timezone($timezone);
        return "unknown timezone." if ($timezone eq "-0000");

        my $month = $month_names{$month_name};

        my $wday_name =
            ("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat")
            [getwday($year, $month + 1, $mday)];

        $year += 2000 if ($year < 50);
        $year += 1900 if (50 <= $year && $year <= 99);

        $sec = 0 unless($sec);

        $$datetime = sprintf("%s, %2.2d %s %4.4d %2.2d:%2.2d:%2.2d %s",
            $wday_name, $mday, $month_name, $year,
            $hour, $min, $sec, $timezone);

        return undef;
    }

    return "Illegal format.";
}

sub rfc822time_to_mtime ($) {
    my ($datetime) = @_;

    my $err = time::normalize_rfc822time(\$datetime);
    return -1 if ($err);

    if ($datetime =~ /
        ^\s*
        (?:($re_wday),\s+)?                   # (a day of the week (ignored))
        ($re_day)\s+                          # a day of the month
        ($re_month)\s+                        # name of month
        ($re_year)\s+                         # year
        ($re_hour):($re_min)(?::($re_sec))?   # HH:MM(:SS)
        (?:\s+([^\s]*))?\s*                   # (timezone)
        /x)
    {
	my ($mday, $month_name, $year, $hour, $min, $sec, $timezone) =
            ($2, $3, $4, $5, $6, $7, $8);

        $timezone = time::gettimezone() unless($timezone);
        $timezone = time::normalize_rfc822timezone($timezone);
        return -1 if ($timezone eq "-0000");

        $sec = 0 unless($sec);

        my $month = $month_names{$month_name};

        $year += 2000 if ($year < 50);
        $year += 1900 if (50 <= $year && $year <= 99);
        return -1 if ($year >= 2038);

        my $mtime;
        eval {
            $mtime = timegm($sec, $min, $hour, $mday, $month, $year);
        } || return -1;

        my $offset;
        if ($timezone =~ /([+-])(\d{2})([0-5][0-9])/) {
            $offset = ($2 * 60 + $3) * 60;
            $offset = - $offset if ($1 eq "-");
        }
        else {
            $offset = $zone{$timezone} * 3600;
        }

        return $mtime - $offset;
    } else {
        return -1; # return with error
    }
}

1;
