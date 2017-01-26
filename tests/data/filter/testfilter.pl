#
# -*- Perl -*-
# $Id: testfilter.pl,v 1.2.4.1 2004-09-06 11:43:34 opengl2772 Exp $
# Copyright (C) 2000 Namazu Project All rights reserved ,
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

package testfilter;
use strict;
require 'util.pl';

my $dvipath = undef;
my $nkfpath = undef;

sub mediatype() {
    return ('x-test/x-test');
}

sub status() {
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
    my $magic = shift @_;
    $magic->addMagicEntry("0\tstring\tNamazu-Filter-Test:\tx-test/x-test");
    return;
}

sub filter ($$$$$) {
    my ($orig_cfile, $contref, $weighted_str, $headings, $fields)
      = @_;
    my $cfile = defined $orig_cfile ? $$orig_cfile : '';

    util::vprint("Processing namazu-filter-test file ... \n");

    test_filter($contref, $weighted_str, $fields);

    return undef;
}

sub test_filter {
    my ($contref, $weighted_str, $fields) = @_;

    if ($$contref =~ s/^Namazu-Filter-Test: (.*)\n//m) {
	$weighted_str .= "\x7f1\x7f$1\x7f/1\x7f\n" if defined $1;
	my $title = $1 if defined $3;
	$fields->{'title'} = $title;
    }

    $fields->{'author'} = "foo";
}

1;
