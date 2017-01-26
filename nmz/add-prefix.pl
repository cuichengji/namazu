#! /usr/bin/perl
#
# $Id: add-prefix.pl,v 1.1 2000-01-09 13:00:38 satoru Exp $
#
# Copyright (C) 2000 Satoru Takabayashi  All rights reserved.
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

use strict;
use FileHandle;

die if @ARGV != 2;

my $prefix = $ARGV[0];
my $file   = $ARGV[1];

my @list = ();
while (<STDIN>) {
    chomp;
    push @list, $_;
}

my $regex = join '|', sort {length($b) <=> length($a)} @list;
{
    my $target = new FileHandle;
    $target->open("$file") || die;
    while (<$target>) {
	s/\b($regex)\b/${prefix}_$1/g;
	print;
    }
}

