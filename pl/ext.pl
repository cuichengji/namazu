#
# -*- Perl -*-
# $Id: ext.pl,v 1.2.2.3 2008-07-13 16:35:09 opengl2772 Exp $
# Copyright (C) 2008 Tadamasa Teranishi All rights reserved.
# Copyright (C) 2008 Namazu Project All rights reserved.
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

package ext;
use strict;
require 'extzip.pl';
require 'extutf8.pl';

sub issupport($)
{
    my ($ext) = @_;

    if ($ext eq 'EXT_ZIP') {
        return extzip::setup();
    } elsif ($ext eq 'EXT_UTF8') {
        return extutf8::setup();
    }

    return 'no';
}

1;
