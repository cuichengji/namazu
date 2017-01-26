#
# -*- Perl -*-
# $Id: oleexcel.pl,v 1.11.4.25 2015-09-24 13:45:07 opengl2772 Exp $
# Copyright (C) 2001 Yoshinori TAKESAKO,
#               1999 Jun Kurabe,
#               1999 Ken-ichi Hirose,
#               2000-2015 Namazu Project All rights reserved.
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
#  Some Code copy from Win32::OLE Example program.
#  Licence for these code is
#    You may distribute under the terms of either the GNU General Public
#    License or the Artistic License, as specified in the README(Win32::OLE) file.
#
# Created by Jun Kurabe <jun-krb@mars.dti.ne.jp>
# V1.00 1999/10/30
# V1.01 1999/11/03 Add getFrames by Jun Kurabe
# V1.02 1999/11/03 Change getProperties of check TextFrame statement
# V2.00 1999/11/06 Change Program Structure 
#		  Get Text From Grouped Shape Items
# V2.10 1999/11/09 Change Name
#		  Merge three program ReadMSWord.pl, ReadExcel.pl, ReadPPT.pl
# V2.11 1999/11/15  separate file. modify some functions.
# V2.12 1999/11/27 Use Office::OLE::Const to define constant value
# V3.00 2001/01/12 New OLE Excel filter written by <takesako@ddt.or.jp>
# V3.01 2001/01/13 Changed overall program structure.
# V3.02 2001/01/14 Skipped password-protected file.
# V3.03 2001/01/16 The using memory size was reduced.
# V3.04 2001/01/20 Moved Excel application destructor to END block
# V3.05 2001/01/21 Do not pop-up over-write dialog message
# V3.06 2001/01/24 Convert kanji code of document properties to euc-jp code

package oleexcel;
use strict;
use English;
require 'util.pl';
require 'gfilter.pl';

use Win32;
use Win32::OLE qw(in with);
use Win32::OLE::Const;

# for Excel application start only one time
my $excel = undef;
my $const = undef;
my $version = 0;

# Excel application destructor
END {
    if (defined $excel) {
        util::vprint("Excel->Quit\n");
        $excel->Quit();
        undef $excel;
    }
}

sub mediatype() {
    status();

    if ($version >= 10) {
        # 16.0 Office 2016
        # 15.0 Office 2013
        # 14.0 Office 2010
        # 12.0 Office 2007
        # 11.0 Office 2003
        # 10.0 Office 2002
        return (
            'application/excel',
            'application/vnd.openxmlformats-officedocument.spreadsheetml',
#            'application/vnd.ms-excel.sheet.macroEnabled',
#            'application/vnd.ms-excel.sheet.binary.macroEnabled',
        );
    } else {
        #  9.0 Office 2000
        #  8.0 Office 97, 98
        return (
            'application/excel',
        );
    }
}

sub status() {
    open (SAVEERR,">&STDERR");
    open (STDERR,">nul");

    if (!defined $const) {
        $const = Win32::OLE::Const->Load("Microsoft Excel 16.0 Object Library");
        $version = 16 if (defined $const);
    }
    if (!defined $const) {
        $const = Win32::OLE::Const->Load("Microsoft Excel 15.0 Object Library");
        $version = 15 if (defined $const);
    }
    if (!defined $const) {
        $const = Win32::OLE::Const->Load("Microsoft Excel 14.0 Object Library");
        $version = 14 if (defined $const);
    }
    if (!defined $const) {
        $const = Win32::OLE::Const->Load("Microsoft Excel 12.0 Object Library");
        $version = 12 if (defined $const);
    }
    if (!defined $const) {
        $const = Win32::OLE::Const->Load("Microsoft Excel 11.0 Object Library");
        $version = 11 if (defined $const);
    }
    if (!defined $const) {
        $const = Win32::OLE::Const->Load("Microsoft Excel 10.0 Object Library");
        $version = 10 if (defined $const);
    }
    if (!defined $const) {
        $const = Win32::OLE::Const->Load("Microsoft Excel 9.0 Object Library");
        $version = 9 if (defined $const);
    }
    if (!defined $const) {
        $const = Win32::OLE::Const->Load("Microsoft Excel 8.0 Object Library");
        $version = 8 if (defined $const);
    }

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

    # FIXME: very ad hoc.
    $magic->addFileExts('\\.xls$', 'application/excel');
    $magic->addFileExts('\\.xlsx$', 'application/vnd.openxmlformats-officedocument.spreadsheetml');
#    $magic->addFileExts('\\.xlsm$', 'application/vnd.ms-excel.sheet.macroEnabled');
#    $magic->addFileExts('\\.xlsb$', 'application/vnd.ms-excel.sheet.binary.macroEnabled');
    return;
}

sub getProperties ($$$) {
    my ($cfile, $fields, $weighted_str) = @_;

    # See VBA online help using Microsoft Excel in detail.
    # Topic item: 'DocumentProperty Object'.

    my $title = $cfile->BuiltInDocumentProperties('Title')->{Value};
    $title = $cfile->BuiltInDocumentProperties('Subject')->{Value}
	unless (defined $title);
    if (defined $title) {
        $title = codeconv::shiftjis_to_eucjp($title);
        codeconv::normalize_eucjp_document(\$title);
        $fields->{'title'} = $title;

        my $weight = $conf::Weight{'html'}->{'title'};
        $$weighted_str .= "\x7f$weight\x7f$fields->{'title'}\x7f/$weight\x7f\n";
    }

    my $author = $cfile->BuiltInDocumentProperties('Last Author')->{Value};
    $author = $cfile->BuiltInDocumentProperties('Author')->{Value}
	unless (defined $author);
    if (defined $author) {
        $author = codeconv::shiftjis_to_eucjp($author);
        codeconv::normalize_eucjp_document(\$author);
        $fields->{'author'} = $author;
    }

    # my $date = $cfile->BuiltInDocumentProperties('Last Save Time')->{Value};
    # $date = $cfile->BuiltInDocumentProperties('Creation Date')->{Value}
    #    unless (defined $date);
    # if (defined $date) {
    #     $date = codeconv::shiftjis_to_eucjp($date);
    #     codeconv::normalize_eucjp_document(\$date);
    #     $fields->{'date'} = $date;
    # }

    my $keyword = $cfile->BuiltInDocumentProperties('keywords')->{Value};
    if (defined $keyword) {
        $keyword = codeconv::shiftjis_to_eucjp($keyword);
        codeconv::normalize_eucjp_document(\$keyword);

        my $weight = $conf::Weight{'metakey'};
        $$weighted_str .= "\x7f$weight\x7f$keyword\x7f/$weight\x7f\n";
    }

    return undef;
}

sub Win32_FullPath ($) {
    # c:/hoge/hoge.xls -> c:\hoge\hoge.xls
    my $file = shift;
    if ($English::PERL_VERSION >= 5.006) {
	$file = Win32::GetFullPathName($file);
    }
    $file =~ s|/|\\|g;
    return $file;
}

sub GetExt($) {
    my ($filename) = @_;

    my $ext = $filename;
    $ext =~ s!.*/!!g;
    if ($ext !~ s/^.*(\.[^\.]*)$/$1/) {
        $ext = "";
    }

    return $ext;
}

my $Count = 0;

sub filter ($$$$$) {
    my ($orig_cfile, $cont, $weighted_str, $headings, $fields) = @_;
    my $cfile = defined $orig_cfile ? $$orig_cfile : '';

    util::vprint("Processing excel file ...\n");

    my $err = ReadDocument($cfile, $cont, $weighted_str, $headings, $fields);
    return $err if (defined $err);

    gfilter::line_adjust_filter($cont);
    gfilter::line_adjust_filter($weighted_str);
    gfilter::white_space_adjust_filter($cont);
    $fields->{'title'} = gfilter::filename_to_title($cfile, $weighted_str)
	unless $fields->{'title'};
    gfilter::show_filter_debug_info($cont, $weighted_str, $fields, $headings);

    return undef;
}

sub ReadDocument ($$$$$) {
    my ($cfile, $cont, $weighted_str, $headings, $fields) = @_;

    my $ext = GetExt($cfile);
    my $tmpfile = util::tmpnam('NMZ.oleexcel') . $ext;
    {
        my $fh = util::efopen("> $tmpfile");
        print $fh $$cont;
        util::fclose($fh);
    }

    my $err = ReadExcel($tmpfile, $cont, $weighted_str, $headings, $fields);
    unlink($tmpfile);

    # codeconv::toeuc($cont);
    codeconv::codeconv_document($cont);

    # TEXT_SIZE_MAX
    my $text_size_max = $conf::TEXT_SIZE_MAX;
    if (length($$cont) > $text_size_max) {
	util::vprint("text size is too LARGE! Cut down on test size: $text_size_max bytes");
	$$cont = substr($$cont, 0, $text_size_max);
	$$cont =~ s/\n.*$//m;
    }

    return $err;
}

sub ReadExcel ($$$$$) {
    my ($cfile, $cont, $weighted_str, $headings, $fields) = @_;

    my $win32filename = $cfile;
    $win32filename =~ s/\//\\/g;
    $$cont = "";

    # make temporary file name
    my $tmpfile0 = util::tmpnam("NMZ.xls.$Count.0");
    my $tmpfile1 = util::tmpnam("NMZ.xls.$Count.1");
    my $tmpfile2 = util::tmpnam("NMZ.xls.$Count.2");
    $Count++;

    # use existing instance if Excel is already running.
    # my $excel;
    # eval {$excel = Win32::OLE->GetActiveObject('Excel.Application')};
    # die "MSExcel not installed" if $@;
    unless (defined $excel) {
		$excel = Win32::OLE->new('Excel.Application', sub {$_[0]->Quit;})
			or return "Oops, cannot start Excel." . Win32::OLE->LastError();
    }

    $Win32::OLE::Warn = 0;             # False
    $excel->{Visible} = 0;             # False
    $excel->{DisplayAlerts} = 0;       # False
    $excel->{EnableEvents} = 0;        # False
    $excel->{AutomationSecurity} = 3;  # msoAutomationSecurityForceDisable

    # Open the excel workbooks.
    # In order to skip password-protected file, send a dummy password.
    my $Book = $excel->Workbooks->Open({
	'FileName'                  => $win32filename,
	'Updatelinks'               => 0,  # False
	'ReadOnly'                  => 1,  # True
	'Password'                  => 'dummy password',
	'WriteResPassword'          => 'dummy password',
	'IgnoreReadOnlyRecommended' => 1   # True
    });
    return "Cannot open File $cfile" unless (defined $Book);

    # get some properties
    getProperties($Book, $fields, $weighted_str);

    # FileHandle for temporary file 1,2
    local (*FH1, *FH2);

    # for exchanging SaveAs temporary file 0 or 1
    my $unlink_list;
    my $tmpfile = $tmpfile0;

    # for each All Sheets in the WorkBook
    foreach my $sheet (in $Book->Sheets) {
	# Get this sheetName
	my $sheetName = $sheet->Name;

	# SaveAs xlText FileFormat
	$sheet->Select;
	my $ret = $excel->ActiveWorkbook->SaveAs({
	    'FileName'     => &Win32_FullPath($tmpfile),
	    'FileFormat'   => $const->{xlText},  # xlText
	    'CreateBackup' => 0                  # False
	});

	# print this sheetName
	open (FH2, ">>$tmpfile2") or return("$tmpfile2: $!\n");
	print FH2 "$sheetName\n";
	util::vprint("Processing sheet: $sheetName");

	# if SaveAs method is successful then unescape form xlText file-format.
	if (defined $ret) {
	    open (FH1, "<$tmpfile") or return("$tmpfile: $!\n");
	    binmode(FH1);
	    local ($/) = "\r\n";
	    while (my $text = <FH1>) {
		chomp($text);
		chomp($text);
		$text =~ s/^"//m;
		$text =~ s/"$//m;
		$text =~ s/\t+$//m;
		$text =~ s/\t"/\t/gm;
		$text =~ s/"\t/\t/gm;
		$text =~ s/""/"/gm;
		$text =~ s/\s+/ /gm; # for Adjust white spaces
		print FH2 $text, "\n" if ($text ne '');
	    }
	    close(FH1);

	    # unlink old temporary file
	    unlink $unlink_list if defined $unlink_list;
	    $unlink_list = $tmpfile;

	    # exchange SaveAs temporary file 0 or 1
	    $tmpfile = ($tmpfile eq $tmpfile0) ? $tmpfile1 : $tmpfile0;
	}
	close(FH2);
    }

    $Book->Close({
        'SaveChanges' => 0  # False
    });
    undef $Book;
	# $excel->Quit();
    # undef $excel;

    # read all text from temporary file 2
    {
        my $fh2 = util::efopen("< $tmpfile2");
        $$cont = util::readfile($fh2);
        util::fclose($fh2);
        undef $fh2;
    }

    # unlink temporary file 0,1,2
    unlink $tmpfile0, $tmpfile1, $tmpfile2;

    return undef;
}

1;
