#
# -*- Perl -*-
# $Id: apachecache.pl,v 1.1.2.2 2003-08-24 10:41:55 usu Exp $
# Copyright (C) 2002 TSUCHIYA Masatoshi ,
#               2002 Namazu Project All rights reserved.
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

package apachecache;

require 'util.pl';
use FileHandle;
use strict;

sub mediatype()    { 'application/x-apache-cache'; }
sub recursive()    { 1; }
sub pre_codeconv() { 0; }
sub post_codeconv(){ 0; }
sub status()       { 'yes'; }

sub add_magic ($) {
    my ($magic) = @_;
    $magic->addMagicEntry( "119\tstring\tX-URL:\tapplication/x-apache-cache" );
}

# This function is stolen from CGI_Lite.pm.
sub url_decode ($) {
    my $string = shift;
    $string =~ s/%([\da-fA-F]{2})/chr (hex ($1))/eg;
    $string;
}

sub getapacheurl {
    my ($str) = @_;
    $str =~ /\A.{126}([^\n]*)\n/s;
    &url_decode($1);
}

sub replacecode {
    my $fh = new FileHandle( $_, "r" );
    if( $fh ){
	my $buf;
	read( $fh, $buf, 126 + 1024 );
	close $fh;
	$_ = &getapacheurl( $buf );
    } else {
	util::vprint( "Can not open cache file: $_\n" );
    }
}

sub filter ($$$$$) {
    my( $orig_cfile, $contref, $weighted_str, $headings, $fields ) = @_;
    util::vprint( "Cache File: ".$$orig_cfile,
		  "Cache URL : ".&getapacheurl($$contref) );

    # Remove header.
    $$contref =~ s/\A.*?\r\n\r\n//s;
    $$contref =~ s/\A.*?\r\n\r\n//s;
    return undef;
}

1;
