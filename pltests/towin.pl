#!/usr/local/bin/perl -w
#
# $Id: towin.pl,v 1.1.4.3 2006-01-26 12:46:27 opengl2772 Exp $
# Copyright (C) 2004-2006 Tadamasa Teranishi
#               2004-2006 Namazu Project All rights reserved.
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
#

use strict;
use English;
use File::Copy;

if (!($English::OSNAME eq "MSWin32" || $English::OSNAME eq "os2")) {
    warn 'This program operates only by Windows.';
    exit 1;
}

my $comspec = "cmd";
$comspec = $ENV{'COMSPEC'} if (defined $ENV{'COMSPEC'});

my $file = "alltests.pl";
my @cmd = ( "$comspec", "/c", "pl2bat", "-s", "/.pl.in/", "$file.in" );
print join(" ", @cmd) . "\n";
my $status = system { $cmd[0] } @cmd;
warn "Error : $!" if ($status != 0);

exit 0;
