#
# -*- Perl -*-
# $Id: spreadexcel.pl,v 1.1.2.1 2002-04-26 10:29:41 rug Exp $
# Copyright (C) 2000-2001 Mineo Kasai, All rights reserved.
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

package spreadexcel;
use strict;

require 'util.pl';
require 'gfilter.pl';

eval('
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseExcel::FmtJapan;
use Jcode;
');

sub mediatype() {
    return ('application/excel');
}

sub status() {
	my $cond;

	eval('$cond = Spreadsheet::ParseExcel->VERSION;');

    return 'yes' if($cond);
}

sub recursive() {
    return 0;
}

sub pre_codeconv() {
    return 0;
}

sub post_codeconv () {
    return 1;
}

sub add_magic ($) {
    my ($magic) = @_;
    $magic->addFileExts('\\.xls$', 'application/excel');
    return;
}

sub filter ($$$$$) {
    my ($orig_cfile, $cont, $weighted_str, $headings, $fields)
      = @_;
    my $cfile = defined $orig_cfile ? $$orig_cfile : '';

    my $tmpfile = util::tmpnam('NMZ.xls');
    my $tmpfile2 = util::tmpnam('NMZ.xls2');

    my $fh = util::efopen("> $tmpfile");
    print $fh $$cont;
    undef $fh;

	util::vprint("Processing xls file ...\n");

	my $oExcel = new Spreadsheet::ParseExcel;
	my $oFmtJ = Spreadsheet::ParseExcel::FmtJapan->new(Code => 'euc');
	my $oBook = $oExcel->Parse($tmpfile, $oFmtJ);

	open(OUT,">$tmpfile2");
	my($iR, $iC, $oWkS, $oWkC);
	for(my $iSheet=0; $iSheet < $oBook->{SheetCount} ; $iSheet++) {
	    $oWkS = $oBook->{Worksheet}[$iSheet];
	    print OUT $oWkS->{Name}, "\n";
	    for(my $iR = $oWkS->{MinRow} ;
	            defined $oWkS->{MaxRow} && $iR <= $oWkS->{MaxRow} ; $iR++) {
	        for(my $iC = $oWkS->{MinCol} ;
	                        defined $oWkS->{MaxCol} && $iC <= $oWkS->{MaxCol} ; $iC++) {
	            $oWkC = $oWkS->{Cells}[$iR][$iC];
	            print OUT $oWkC->Value if($oWkC);
				print OUT "\t";
	        }
			print OUT "\n";
	    }
	}
	close(OUT);

	$fields->{'author'} = $oBook->{Author};
	#$fields->{'title'} = $oBook->{File};
    $fields->{'title'} = gfilter::filename_to_title($cfile, $weighted_str)
	unless $fields->{'title'};

    unless (-e $tmpfile2) {
	unlink $tmpfile;
	unlink $tmpfile2;
	return 'Unable to convert xls file';
    }

    $fh = util::efopen("< $tmpfile2");
    $$cont = util::readfile($fh);
    undef $fh;
    unlink $tmpfile;
    unlink $tmpfile2;

    gfilter::line_adjust_filter($cont);
    gfilter::line_adjust_filter($weighted_str);
    gfilter::white_space_adjust_filter($cont);

    gfilter::show_filter_debug_info($cont, $weighted_str,
			   $fields, $headings);

    return undef;
}

1;
