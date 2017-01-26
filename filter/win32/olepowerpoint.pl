#
# -*- Perl -*-
# $Id: olepowerpoint.pl,v 1.8.4.23 2015-09-24 13:45:07 opengl2772 Exp $
# Copyright (C) 1999 Jun Kurabe,
#               1999 Ken-ichi Hirose,
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
#
#  Some Code copy from Win32::OLE Example program.
#  Licence for these code is
#    You may distribute under the terms of either the GNU General Public
#    License or the Artistic License, as specified in the README(Win32::OLE) file.
#
# Created by Jun Kurabe
# E-Mail: jun-krb@mars.dti.ne.jp
# V1.00 1999/10/30
# V1.01 1999/11/03 Add getFrames by Jun Kurabe
# V1.02 1999/11/03 Change getProperties of check TextFrame statement
# V2.00 1999/11/06 Change Program Structure
#                  Get Text From Grouped Shape Items
# V2.10 1999/11/09 Change Name
#                  Merge three program ReadMSWord.pl, ReadExcel.pl, ReadPPT.pl
# V2.11 1999/11/15  separate file.
#                   modify some functions.
# V2.12 1999/11/27 Use Office::OLE::Const to define constant value
# V2.13 2000/05/16 Optimize for Namazu filter ...
# V2.14 2000/10/28 contribute patch by Yoshinori.TAKESAKO-san.
# V2.20 2001/01/24 get a title from filename which has no slide title
#

package olepowerpoint;
use strict;
no strict 'refs';  # for symbolic reference: $fields;
require 'util.pl';
require 'gfilter.pl';

my $version = 0;

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
            'application/powerpoint',
            'application/vnd.openxmlformats-officedocument.presentationml',
        );
    } else {
        #  9.0 Office 2000
        #  8.0 Office 97, 98
        return (
            'application/powerpoint',
        );
    }
}

sub status() {
    my $const = undef;

    open (SAVEERR,">&STDERR");
    open (STDERR,">nul");

#    if (!defined $const) {
#        $const = Win32::OLE::Const->Load("Microsoft PowerPoint 16.0 Object Library");
#        $version = 16;
#    }
#    if (!defined $const) {
#        $const = Win32::OLE::Const->Load("Microsoft PowerPoint 15.0 Object Library");
#        $version = 15;
#    }
    if (!defined $const) {
        $const = Win32::OLE::Const->Load("Microsoft PowerPoint 14.0 Object Library");
        $version = 14;
    }
    if (!defined $const) {
        $const = Win32::OLE::Const->Load("Microsoft PowerPoint 12.0 Object Library");
        $version = 12;
    }
    if (!defined $const) {
        $const = Win32::OLE::Const->Load("Microsoft PowerPoint 11.0 Object Library");
        $version = 11;
    }
    if (!defined $const) {
        $const = Win32::OLE::Const->Load("Microsoft PowerPoint 10.0 Object Library");
        $version = 10;
    }
    if (!defined $const) {
        $const = Win32::OLE::Const->Load("Microsoft PowerPoint 9.0 Object Library");
        $version = 9;
    }
    if (!defined $const) {
        $const = Win32::OLE::Const->Load("Microsoft PowerPoint 8.0 Object Library");
        $version = 8;
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
    $magic->addFileExts('\\.pp[st]$', 'application/powerpoint');
    $magic->addFileExts('\\.pp[st]x$', 'application/vnd.openxmlformats-officedocument.presentationml');
    return;
}

sub filter ($$$$$) {
    my ($orig_cfile, $cont, $weighted_str, $headings, $fields) = @_;
    my $cfile = defined $orig_cfile ? $$orig_cfile : '';

    util::vprint("Processing powerpoint file ... (using  'Win32::OLE->new PowerPoint.Application')\n");

    my $err = ReadPPT::ReadDocument($cfile, $cont, $fields, $weighted_str);
    return $err if (defined $err);

    gfilter::line_adjust_filter($cont);
    gfilter::line_adjust_filter($weighted_str);
    gfilter::white_space_adjust_filter($cont);
    $fields->{'title'} = gfilter::filename_to_title($cfile, $weighted_str)
	unless $fields->{'title'};
    gfilter::show_filter_debug_info($cont, $weighted_str, $fields, $headings);

    return undef;
}


# Original of this code was contributed by <jun-krb@mars.dti.ne.jp>.

use Win32::OLE;
use Win32::OLE::Enum;
use Win32::OLE::Const;

sub enum ($$$) {
    my ($enum_objs, $func, $cont) = @_;

    die "No Objects or No Function" unless ($enum_objs and $func );

    my $e = Win32::OLE::Enum->new($enum_objs);
    while((my $obj = $e->Next)) {
        return 0 if (!&$func($obj, $cont));
    }
    return 1;
}

sub getProperties ($$$) {
    my ($cfile, $fields, $weighted_str) = @_;

    # See VBA online help using Microsoft PowerPoint in detail.
    # Topic item: 'DocumentProperty Object'.

    my $title = $cfile->BuiltInDocumentProperties('Title')->{Value};
    $title = $cfile->BuiltInDocumentProperties('Subject')->{Value}
	unless (defined $title);
    undef $title if $title eq # which has no slide title
	"\xbd\xd7\xb2\xc4\xde\x20\xc0\xb2\xc4\xd9\x82\xc8\x82\xb5";
    if (defined $title) {
        $title = codeconv::shiftjis_to_eucjp($title);
        codeconv::normalize_eucjp_document(\$title);
        $fields->{'title'} = $title;

        my $weight = $conf::Weight{'html'}->{'title'};
        $$weighted_str .= "\x7f$weight\x7f$fields->{'title'}\x7f/$weight\x7f\n";
    }

    my $author = $cfile->BuiltInDocumentProperties('Author')->{Value};
    $author = $cfile->BuiltInDocumentProperties('Last Author')->{Value}
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

package ReadPPT;

my $ppt = undef;
my $office_consts = undef;

# PowerPoint application destructor
END {
    if (defined $ppt) {
        util::vprint("PowerPoint->Quit\n");
        $ppt->Quit();
        undef $ppt;
    }
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

sub ReadDocument ($$$$) {
    my ($cfile, $cont, $fields, $weighted_str) = @_;

    my $ext = GetExt($cfile);
    my $tmpfile = util::tmpnam('NMZ.olepowerpoint') . $ext;
    {
        my $fh = util::efopen("> $tmpfile");
        print $fh $$cont;
        util::fclose($fh);
    }

    my $err = ReadPPT::ReadPPT($tmpfile, $cont, $fields, $weighted_str);
    unlink $tmpfile;

    # codeconv::toeuc($cont);
    codeconv::codeconv_document($cont);

    return $err;
}

sub ReadPPT ($$$$) {
    my ($cfile, $cont, $fields, $weighted_str) = @_;

    $cfile =~ s/\//\\/g;
    $$cont = "";

    # Copy From Win32::OLE Example Program
    # use existing instance if PowerPoint is already running
    eval {$ppt = Win32::OLE->GetActiveObject('PowerPoint.Application')};
    # die "PowerPoint not installed" if $@;
    unless (defined $ppt) {
		$ppt = Win32::OLE->new('PowerPoint.Application', sub {$_[0]->Quit;})
			or return "Oops, cannot start PowerPoint." . Win32::OLE->LastError();
    }
    #End of Copy From Win32::OLE Example Program

    # Redirect stderr to null device, to ignore Error and Exception message.
    open (SAVEERR,">&STDERR");
    open (STDERR,">nul");
    # Load Office 97/98/2000/XP/2003/2007/2010/2013/2016 Constant
    $office_consts = Win32::OLE::Const->Load("Microsoft Office 16.0 Object Library") unless $office_consts;
    $office_consts = Win32::OLE::Const->Load("Microsoft Office 15.0 Object Library") unless $office_consts;
    $office_consts = Win32::OLE::Const->Load("Microsoft Office 14.0 Object Library") unless $office_consts;
    $office_consts = Win32::OLE::Const->Load("Microsoft Office 12.0 Object Library") unless $office_consts;
    $office_consts = Win32::OLE::Const->Load("Microsoft Office 11.0 Object Library") unless $office_consts;
    $office_consts = Win32::OLE::Const->Load("Microsoft Office 10.0 Object Library") unless $office_consts;
    $office_consts = Win32::OLE::Const->Load("Microsoft Office 9.0 Object Library") unless $office_consts;
    $office_consts = Win32::OLE::Const->Load("Microsoft Office 8.0 Object Library") unless $office_consts;

    $Win32::OLE::Warn = 0;           # False
    # 'Visible = false' causes exception but noharm, so we ignore... X-(
    $ppt->{Visible} = 0;             # msoFalse
    $ppt->{DisplayAlerts} = 1;       # ppAlertsNone
    $ppt->{AutomationSecurity} = 3;  # msoAutomationSecurityForceDisable


    # Restore stderr device usually.
    open (STDERR,">&SAVEERR");

    my $prs = $ppt->{Presentations}->Open({
	'FileName'      => $cfile,
#	 'ReadOnly'      => 1,   # msoCTrue
	'ReadOnly'      => -1,  # msoTrue
	'WithWindow'    => 0    # msoFalse
	});
    return "Cannot open File $cfile" unless (defined $prs);

    olepowerpoint::getProperties($prs, $fields, $weighted_str);
    getSlides($prs, $cont);

    $prs->Close();
    undef $prs;
	$ppt->Quit();
	undef $ppt;

    return undef;
}

sub getSlides ($$) {
    my ($prs, $cont) = @_;

    my $enum_a_slide = sub {
	my $slide = shift;

	my $enum_a_headerfooter = sub {
	    my $obj = shift;
	    $$cont .= $obj->Header->{Text} if ( $obj->{Header} && $obj->Header->{Text} ) ;
	    $$cont .= $obj->Footer->{Text} if ( $obj->{Footer} && $obj->Footer->{Text} ) ;
	    return 1;
	};

	sub enum_a_shape ($$) {
	    my ($shape, $cont) = @_;
	    # Get text whaen TextFrame in Shapes and Text in TextFrame
	    if ($shape->{HasTextFrame} && $shape->TextFrame->TextRange) {
		my $p = $shape->TextFrame->TextRange->{Text};
		$$cont .= "$p\n" if (defined $p);
	    } elsif ( $shape->{Type} == $office_consts->{msoGroup} ) {
	    olepowerpoint::enum($shape->GroupItems, \&enum_a_shape, $cont);
	    }
	    return 1;
	};

        olepowerpoint::enum($slide->Shapes, \&enum_a_shape, $cont);
#        &$enum_a_headerfooter($slide->HeadersFooters);
        return 1;
    };

    olepowerpoint::enum($prs->Slides, $enum_a_slide, $cont);
    return undef;
}

#main
#use Cwd;
#$ARGV[0] = cwd().'\\'.$ARGV[0] unless ($ARGV[0] =~ m/^[a-zA-Z]\:[\\\/]/ || $ARGV[0] =~ m/^\/\//);
#$ARGV[0] =~ s|/|\\|g;

#my $$cont = "";
#ReadPPT::ReadPPT("$ARGV[0]", $cont, "", "");
#(my $base = $ARGV[0]) =~ s/\.ppt$//;
#open(F, "> $base.txt") || die;
#print F $$cont;
#close(F);

1;
