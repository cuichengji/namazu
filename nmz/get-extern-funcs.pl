#! /usr/bin/perl
#
# $Id: get-extern-funcs.pl,v 1.2 2000-01-09 13:39:47 satoru Exp $
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

my @list = ();
while (<>) {
    push @list, $_ if m!^#if __STDC__! .. m!^#else /\* __STDC__ \*/!;
}

@list = grep {m!^extern !} @list;
@list = map  {m!^extern .* (\w+) *\(!; $1 . "\n"} @list;

print @list;

