#
# -*- Perl -*-
# $Id: taro7_10.pl,v 1.1.2.19 2008-05-09 08:48:08 opengl2772 Exp $
# Copyright (C) 2003 Yukio USUDA
#               2003-2008 Namazu Project All rights reserved.
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

package taro7_10;
use strict;
use English;
require 'util.pl';
require 'gfilter.pl';

sub mediatype() {
    return (
        'application/ichitaro7', 'application/x-js-taro'
    );
}

sub status() {
    my $olepath = undef;
    $olepath = util::checklib('OLE/Storage_Lite.pm');
    return 'no' unless $olepath;

    return 'yes' if ($English::PERL_VERSION >= 5.008);
    my $utfconvpath = undef;
    $utfconvpath = util::checklib('unicode.pl');
    return 'yes' if $utfconvpath;
    return 'no';
}

sub recursive() {
    return 0;
}

sub pre_codeconv() {
    return 0;
}

sub post_codeconv() {
    return 0;
}

sub add_magic($) {
    my ($magic) = @_;

    # FIXME: very ad hoc.
    $magic->addFileExts('\\.jtd$', 'application/x-js-taro');
    $magic->addFileExts('\\.jfw$', 'application/ichitaro7');
    return;
}

sub filter($$$$$) {
    my ($orig_cfile, $contref, $weighted_str, $headings, $fields)
      = @_;
    my $err = undef;
    $err = taro7_10_filter($orig_cfile, $contref, $weighted_str, $headings, $fields);
    return $err;
}

sub taro7_10_filter($$$$$) {
    my ($orig_cfile, $contref, $weighted_str, $headings, $fields)
      = @_;
    my $cfile = defined $orig_cfile ? $$orig_cfile : '';
    my $err = undef;

    eval 'use OLE::Storage_Lite';
    my $oleobject = OLE::Storage_Lite->new($contref);
    return (undef) unless($oleobject);
    my ($authorname, $title) = getinfo($oleobject);
    codeconv::normalize_eucjp(\$authorname);
    codeconv::normalize_eucjp(\$title);
    $fields->{'author'} = $authorname;
    $fields->{'title'} = $title;

    my $content = getcontent($oleobject);
    codeconv::normalize_eucjp(\$content);
    $$contref = $content;

    gfilter::line_adjust_filter($contref);
    gfilter::line_adjust_filter($weighted_str);
    gfilter::white_space_adjust_filter($contref);
    $fields->{'title'} = gfilter::filename_to_title($cfile, $weighted_str)
      unless $fields->{'title'};
    gfilter::show_filter_debug_info($contref, $weighted_str,
               $fields, $headings);
    return undef;
}

sub byteswap($) {
    my ($tmp) = @_;
    $$tmp = pack("n".length($$tmp)*2, unpack("v".length($$tmp)*2,$$tmp));
}

sub getinfo($) {
    my ($oleobject) = @_;
    my @pps = $oleobject->getPpsSearch(
            [OLE::Storage_Lite::Asc2Ucs("\x04JSRV_SummaryInformation")], 1, 1);
    return (undef) if($#pps < 0);
    my $author = undef;
    my $title = undef;
    my $position;
    if ($pps[0]->{Data}) {
        if ($pps[0]->{Data} =~ /\x02\x00\x00\x31\x8b\x89\xfa\x51\x57\x30/g) {
            $position = pos($pps[0]->{Data});
            my $title_length = unpack("v", substr($pps[0]->{Data},
                                       $position + 70, 2));
            $title = substr($pps[0]->{Data},
                      $position + 86, $title_length);
        }
        if ($pps[0]->{Data} =~ /\x04\x00\x00\x31\x5c\x4f\x10\x62\x05\x80/g) {
            $position = pos($pps[0]->{Data});
            my $author_length = unpack("v", substr($pps[0]->{Data},
                                       $position + 70, 2));
            $author = substr($pps[0]->{Data},
                             $position + 86, $author_length);
        }
    }
    taro7_10::byteswap(\$author);
    taro7_10::u16toe(\$author);
    $author =~ s/[\x00\x0E\x0c]//g;

    taro7_10::byteswap(\$title);
    taro7_10::u16toe(\$title);
    $title =~ s/[\x00\x0E\x0c]//g;

    return ($author, $title);
}

sub getcontent($) {
    my ($oleobject) = @_;
    my @pps = $oleobject->getPpsSearch(
            [OLE::Storage_Lite::Asc2Ucs('DocumentText')], 1, 1);
    return (undef) if($#pps < 0);
    my $content = "";
    for my $i (0..$#pps) {
        if ($pps[$i]->{Data}) {
            my $size = unpack("N", substr($pps[$i]->{Data}, 0x1c, 4)) * 2;
            my $buf = substr($pps[$i]->{Data}, 0x20, $size);
            taro7_10::remove_ctlcodearea(\$buf);
            $content .= $buf . "\x00\x0a";
        }
    }
    u16toe(\$content);
    $content =~ s/[\x00\x0E\x0c]//g;
    return $content;
}

sub remove_ctlcodearea($) {
    my ($textref) = @_;
    my $ctl_in  = "\x00\x1c";
    my $ctl_out = "\x00\x1f";
    my $tmptext1 = $$textref;
    my $tmptext2 = "";
    my $pos1 = 0;
    my $pos2 = 0;
    my @incodes;
    while ($tmptext1 =~ /$ctl_in/sg) {
        push(@incodes, pos($tmptext1)-2);
    }
    push(@incodes, length($tmptext1));
    my $i = 1;
    while (@incodes) {
        $pos2 = shift(@incodes) ;
        my $tmptext3 = "";
        $tmptext3 = substr($tmptext1, $pos1, $pos2-$pos1);
        $tmptext3 =~ s/$ctl_in.*$ctl_out//s;
        $tmptext3 =~ s/$ctl_in.*//s;
        $tmptext2 .= $tmptext3;
        $i++;
        $pos1 = $pos2;
    }
    $$textref = $tmptext2;
}

# convert utf-16 to euc
# require Perl5.8 or unicode.pl
sub u16toe($) {
    my ($tmp) = @_;
    if ($English::PERL_VERSION >= 5.008) {
        eval 'use Encode qw/from_to Unicode JP/;';
        Encode::from_to($$tmp, "UTF-16BE", "euc-jp");
    } else {
        eval require 'unicode.pl';
        my @unicodeList = unpack("n*", $$tmp);
        $$tmp = unicode::u2e(@unicodeList);
    }
}

1;
