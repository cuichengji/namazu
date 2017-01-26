#
# -*- Perl -*-
# $Id: olevisio.pl,v 1.4.2.10 2017-01-13 16:52:38 opengl2772 Exp $
# Copyright (C) 2004-2017 Tadamasa Teranishi,
#               2004-2017 Namazu Project All rights reserved.
#     This is free software with ABSOLUTELY NO WARRANTY.
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either versions 2, or (at your option)
#  any later version.
#
#  This program is distributed in the hope that it will be useful
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the
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

package olevisio;
use strict;
require 'util.pl';
require 'gfilter.pl';
require 'olemsword.pl';

use Win32::OLE;
use Win32::OLE::Enum;
use Win32::OLE::Const;

my $version = 0;

my $const = undef;

# for Visio application start only one time
my $visio = undef;

# Visio application destructor
END {
    if (defined $visio) {
        util::vprint("Visio->Quit\n");
        $visio->Quit();
        undef $visio;
    }
}

sub mediatype() {
    status();
    
    if ($version >= 15) {
        # 16.0 Office 2016
        # 15.0 Office 2013
        return (
            'application/vnd.visio; x-type=vsdx',
            'application/vnd.visio; x-type=vdw',
            'application/vnd.visio; x-type=vdx',
            'application/vnd.visio',
            'application/ms-visio',
            'application/visio',
        );
    } elsif ($version >= 14) {
        # 14.0 Office 2010
        return (
            'application/vnd.visio; x-type=vdw',
            'application/vnd.visio; x-type=vdx',
            'application/vnd.visio',
            'application/ms-visio',
            'application/visio',
        );
    } else {
        return (
            'application/vnd.visio; x-type=vdx',
            'application/vnd.visio',
            'application/ms-visio',
            'application/visio',
        );
    }
}

sub status() {
    open (SAVEERR, ">&STDERR");
    open (STDERR, ">nul");
    
    if (!defined $const) {
        $const = Win32::OLE::Const->Load("Microsoft Visio 16.0 Type Library");
        $version = 16;
    }
    if (!defined $const) {
        $const = Win32::OLE::Const->Load("Microsoft Visio 15.0 Type Library");
        $version = 15;
    }
    if (!defined $const) {
        $const = Win32::OLE::Const->Load("Microsoft Visio 14.0 Type Library");
        $version = 14;
    }
    if (!defined $const) {
        $const = Win32::OLE::Const->Load("Microsoft Visio 12.0 Type Library");
        $version = 12;
    }
    if (!defined $const) {
        $const = Win32::OLE::Const->Load("Microsoft Visio 11.0 Type Library");
        $version = 11;
    }
    if (!defined $const) {
        $const = Win32::OLE::Const->Load("Microsoft Visio 2002 Type Library");
        $version = 10;
    }
    if (!defined $const) {
        $const = Win32::OLE::Const->Load("Microsoft Visio 2000 Type Library");
        $version = 9;
    }
    if (!defined $const) {
        $const = Win32::OLE::Const->Load("Visio 2000 Type Library");
        $version = 9;
    }
        
    open (STDERR, ">&SAVEERR");

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
    $magic->addFileExts('\\.vs[dst]$', 'application/vnd.visio');
    $magic->addFileExts('\\.v[dst]x$', 'application/vnd.visio; x-type=vdx');
    $magic->addFileExts('\\.vdw$', 'application/vnd.visio; x-type=vdw');
    $magic->addFileExts('\\.vs[dst]x$', 'application/vnd.visio; x-type=vsdx');
    
    $magic->addSpecials('application/vnd.visio; x-type=vdx',
                        '^<VisioDocument\s',);
    return;
}

sub filter ($$$$$) {
    my ($orig_cfile, $cont, $weighted_str, $headings, $fields) 
        = @_;
    my $cfile = defined $orig_cfile ? $$orig_cfile : '';

    util::vprint("Processing visio file ... (using  'Win32::OLE->new Visio.InvisibleApp')\n");

    my $err = ReadDocument($cfile, $cont, $fields, $weighted_str, $headings);
    return $err if (defined $err);

    gfilter::line_adjust_filter($cont);
    gfilter::line_adjust_filter($weighted_str);
    gfilter::white_space_adjust_filter($cont);
    $fields->{'title'} = gfilter::filename_to_title($cfile, $weighted_str)
        unless $fields->{'title'};
    gfilter::show_filter_debug_info($cont, $weighted_str, $fields, $headings);

    return undef;
}

sub enum ($$$) {
    my ($enum_objs, $func, $cont) = @_;

    die "No Objects or No Function" unless ($enum_objs and $func);

    my $e = Win32::OLE::Enum->new($enum_objs);
    while((my $obj = $e->Next)) {
        return 0 if (!&$func($obj, $cont));
    }
    return 1;
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

sub ReadDocument ($$$$$) {
    my ($cfile, $cont, $fields, $weighted_str, $headings) = @_;

    my $ext = GetExt($cfile);
    my $tmpfile = util::tmpnam('NMZ.olevisio') . $ext;
    {
        my $fh = util::efopen("> $tmpfile");
        print $fh $$cont;
        util::fclose($fh);
    }

    my $err = ReadVISIO($tmpfile, $cont, $fields, $weighted_str, $headings);
    unlink $tmpfile;

    # codeconv::toeuc($cont);
    codeconv::codeconv_document($cont);

    return $err;
}

sub ReadVISIO ($$$$$) {
    my ($cfile, $cont, $fields, $weighted_str, $headings) = @_;

    $cfile =~ s/\//\\/g;
    $$cont = "";

    # eval {$visio = Win32::OLE->GetActiveObject('Visio.InvisibleApp')};
    # die "Visio not installed" if $@;
    unless (defined $visio) {
        $visio = Win32::OLE->new('Visio.InvisibleApp', sub {$_[0]->Quit;})
            or return "Oops, cannot start Visio." . Win32::OLE->LastError();
    }

    $Win32::OLE::Warn = 0;        # False
    $visio->{Visible} = 0;        # False
    $visio->{AlertResponse} = 2;  # IDCANCEL

    # Open the visio document.
    my $doc = $visio->Documents->OpenEx({
        'FileName' => $cfile,
        'Flags'    => 0xde        # 0x01 visOpenCopy 
                                  # 0x02 visReadOnly
                                  # 0x04 visOpenDocked
                                  # 0x08 visDontList
                                  # 0x10 visOpenMinimized
                                  # 0x20 visOpenRW
                                  # 0x40 visOpenHidden
                                  # 0x80 visOpenMacrosDisabled
    });
    return "Cannot open File $cfile" unless (defined $doc);

    $doc->{AutoRecover} = 0;      # False

    # get description
    my $description = getDescription($doc);
    $$headings .= $description if (defined $description);

    # get some properties
    getProperties($doc, $fields, $weighted_str);

    getShapes($doc, $cont);

    $doc->{Saved} = 1;  # True
    $doc->Close();
    undef $doc;

    return undef;
}

sub getDescription ($) {
    my ($doc) = @_;

    my $description = $doc->{Description};

    if (defined $description && $description ne "") {
        $description = codeconv::shiftjis_to_eucjp($description);
        codeconv::normalize_eucjp_document(\$description);

        util::vprint("Description : $description\n");

        return $description;
    }

    return undef;
}

sub getProperties ($$$) {
    my ($doc, $fields, $weighted_str) = @_;

    my $title = $doc->{Title};
    $title = $doc->{Subject}
        unless (defined $title);
    if (defined $title) {
        $title = codeconv::shiftjis_to_eucjp($title);
        codeconv::normalize_eucjp_document(\$title);
        $fields->{'title'} = $title;

        my $weight = $conf::Weight{'html'}->{'title'};
        $$weighted_str .= "\x7f$weight\x7f$fields->{'title'}\x7f/$weight\x7f\n";
    }

    my $author = $doc->{Creator};
    $author = $doc->{Application}->{UserName}
        unless (defined $author);
    if (defined $author) {
        $author = codeconv::shiftjis_to_eucjp($author);
        codeconv::normalize_eucjp_document(\$author);
        $fields->{'author'} = $author;
    }

    my $keyword = $doc->{Keywords};
    if (defined $keyword) {
        $keyword = codeconv::shiftjis_to_eucjp($keyword);
        codeconv::normalize_eucjp_document(\$keyword);

        my $weight = $conf::Weight{'metakey'};
        $$weighted_str .= "\x7f$weight\x7f$keyword\x7f/$weight\x7f\n";
    }

    return undef;
}

sub getShapes ($$) {
    my ($doc, $cont) = @_;

    sub enum_a_shape ($$) {
        my ($obj, $cont) = @_;

        my $type = $obj->{Type};
        my $index = $obj->{Index};
        my $text = $obj->{Text};


        util::vprint("Shape.Type:[$type]\n");
        util::vprint("Shape.Index:[$index]\n");
        util::vprint("Shape.Text:[$text]\n");

        $text = $obj->{Characters}->{Text};
        $$cont .= "$text " if (defined $text && $text ne "");

        util::vprint("Shape.Characters.Text:[$text]\n");

        my $section = $const->{visSectionProp};
        for (my $row = 0; $row < $obj->RowCount($section); $row++) {
#            if ($obj->CellsSRCExists($section, $row, $const->{visCustPropsType}, 1)) {
#                my $cell = $obj->CellsSRC($section, $row, $const->{visCustPropsType});
#                my $result = $cell->ResultStr(0);
#                $$cont .= "$result " if (defined $result && $result ne "");
#                util::vprint("CustPropsType:[$result]\n");
#            }
            if ($obj->CellsSRCExists($section, $row, $const->{visCustPropsLabel}, 1)) {
                my $cell = $obj->CellsSRC($section, $row, $const->{visCustPropsLabel});
                my $result = $cell->ResultStr(0);
                $$cont .= "$result " if (defined $result && $result ne "");
                util::vprint("CustPropsLabel:[$result]\n");
            }
            if ($obj->CellsSRCExists($section, $row, $const->{visCustPropsPrompt}, 1)) {
                my $cell = $obj->CellsSRC($section, $row, $const->{visCustPropsPrompt});
                my $result = $cell->ResultStr(0);
                $$cont .= "$result " if (defined $result && $result ne "");
                util::vprint("CustPropsPrompt:[$result]\n");
            }
            if ($obj->CellsSRCExists($section, $row, $const->{visCustPropsValue}, 1)) {
                my $cell = $obj->CellsSRC($section, $row, $const->{visCustPropsValue});

                my $rowname = $cell->RowName;
                $$cont .= "$rowname " if (defined $rowname && $rowname ne "");
                util::vprint("RowName:[$rowname]\n");

                my $result = $cell->ResultStr(0);
                $$cont .= "$result " if (defined $result && $result ne "");
                util::vprint("CustPropsValue:[$result]\n");
            }
        }

        {
            my $data1 = $obj->{Data1};
            my $data2 = $obj->{Data2};
            my $data3 = $obj->{Data3};

            $$cont .= "$data1 " if (defined $data1 && $data1 ne "");
            $$cont .= "$data2 " if (defined $data2 && $data2 ne "");
            $$cont .= "$data3 " if (defined $data3 && $data3 ne "");
        }

        if ($obj->{Type} & $const->{visTypeForeignObject}) {
            my $foreignType = $obj->{ForeignType};
            util::vprint("Shape.Foreigntype:[$foreignType]\n");

                #     16: visTypeMetafile
                #     32: visTypeBitmap 
                #     64: visTypeInk 
                #    256: visTypeIsLinked
                #    512: visTypeIsEmbedded
                #   1024: visTypeIsControl
                #  32768: visTypeIsOLE2
        }
        if ($obj->{Type} == $const->{visTypeGroup}) {
            olemsword::enum($obj->{Shapes}, \&enum_a_shape, $cont);
        }
        return 1;
    };

    my $pages = $doc->Pages;
    for (my $i = 1; $i <= $pages->{Count}; $i++) {
        my $name = $pages->Item($i)->{Name};
        $$cont .= "$name " if (defined $name && $name ne "");

        util::vprint("Name:[$name]\n");

        enum($pages->Item($i)->{Shapes}, \&enum_a_shape, $cont);
    }

    return undef;
}

1;
