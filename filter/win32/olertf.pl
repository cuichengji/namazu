# 
# -*- Perl -*-
# $Id: olertf.pl,v 1.4.4.15 2015-09-24 13:45:07 opengl2772 Exp $
# 
# Copyright (C) 2000 Yoshinori.TAKESAKO,
#               2000 Jun Kurabe,
#               2000 Ken-ichi Hirose,
#               2004-2015 Namazu Project All rights reserved.
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

package olertf;
use strict;
require 'util.pl';
require 'gfilter.pl';
require 'olemsword.pl';

use Win32::OLE::Const;

sub mediatype() {
    return ('application/rtf');
}

sub status() {
    my $const = undef;

    # The check of a dependence filter.
    return 'no' if (olemsword::status() ne 'yes');

    # Redirect stderr to null device, to ignore Error and Exception message.
    open (SAVEERR,">&STDERR");
    open (STDERR,">nul");
    # Load Office 97/98/2000/XP/2003/2007/2010/2013/2016 Constant
    $const = Win32::OLE::Const->Load("Microsoft Word 16.0 Object Library") unless $const;
    $const = Win32::OLE::Const->Load("Microsoft Word 15.0 Object Library") unless $const;
    $const = Win32::OLE::Const->Load("Microsoft Word 14.0 Object Library") unless $const;
    $const = Win32::OLE::Const->Load("Microsoft Word 12.0 Object Library") unless $const;
    $const = Win32::OLE::Const->Load("Microsoft Word 11.0 Object Library") unless $const;
    $const = Win32::OLE::Const->Load("Microsoft Word 10.0 Object Library") unless $const;
    $const = Win32::OLE::Const->Load("Microsoft Word 9.0 Object Library") unless $const;
    $const = Win32::OLE::Const->Load("Microsoft Word 8.0 Object Library") unless $const;

    # Restore stderr device usually.
    open (STDERR,">&SAVEERR");

    return 'yes' if (defined $const);
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

    $magic->addMagicEntry("0\tstring\t{\\rtf\t");
    $magic->addMagicEntry(">6\tstring\t\\ansi\tapplication/rtf");
    $magic->addMagicEntry(">6\tstring\t\\mac\tapplication/rtf");
    $magic->addMagicEntry(">6\tstring\t\\pc\tapplication/rtf");
    $magic->addMagicEntry(">6\tstring\t\\pca\tapplication/rtf");

    # FIXME: very ad hoc.
    $magic->addFileExts('\\.rtf$', 'application/rtf');

    return;
}

sub filter ($$$$$) {
    my ($orig_cfile, $cont, $weighted_str, $headings, $fields) = @_;
    my $cfile = defined $orig_cfile ? $$orig_cfile : '';

    util::vprint("Processing rtf file ...\n");

    my $err = ReadMSWord::ReadDocument($cfile, $cont, $fields, $weighted_str);
    return $err if (defined $err);

    gfilter::line_adjust_filter($cont);
    gfilter::line_adjust_filter($weighted_str);
    gfilter::white_space_adjust_filter($cont);
    $fields->{'title'} = gfilter::filename_to_title($cfile, $weighted_str)
	unless $fields->{'title'};
    gfilter::show_filter_debug_info($cont, $weighted_str, $fields, $headings);

    return undef;
}

1;
