#
# -*- Perl -*-
# $Id: taro56.pl,v 1.1.2.11 2008-05-09 08:48:08 opengl2772 Exp $
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

package taro56;
use strict;
require 'util.pl';
require 'gfilter.pl';


sub mediatype() {
    return ('application/ichitaro5', 'application/ichitaro6');
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
    my ($magic) = @_;

    # FIXME: very ad hoc.
    $magic->addFileExts('\\.jaw$', 'application/ichitaro5');
    $magic->addFileExts('\\.jbw$', 'application/ichitaro6');
    return;
}

sub filter ($$$$$) {
    my ($orig_cfile, $cont, $weighted_str, $headings, $fields)
      = @_;
    my $err = undef;
    $err = taro56filter($orig_cfile, $cont, $weighted_str, $headings, $fields);
    return $err;
}

sub taro56filter ($$$$$) {
    my ($orig_cfile, $cont, $weighted_str, $headings, $fields)
      = @_;
    my $cfile = defined $orig_cfile ? $$orig_cfile : '';
    my $err = undef;

    my $title = substr($$cont, 0x40, 64);
    $title =~ s/\x00//g;
    # codeconv::toeuc(\$title);
    codeconv::codeconv_document(\$title);
    $fields->{'title'} = $title;

    my @data = unpack("C*", $$cont);
    my $textsizep = pack("C4", $data[0x800], $data[0x801],
                               $data[0x802], $data[0x803]);
    my $textsize = unpack("V", $textsizep);
    if ((0x803 + $textsize) > length($$cont)){
        $err = "Warning: unknown file format.";
        return $err;
    }
    my $tmp;
    my $i = 0;
    my $code = "";
    while ( $i < $textsize) {
        my $code1 = $data[0x803 +$i];
        my $code2 = $data[0x804 +$i];
        my $code3 = $data[0x805 +$i];
        my $code4 = $data[0x806 +$i];
        if ($code1 == hex("fe")){
            if (($code2 == hex("41")) or ($code2 == hex("46"))
                                      or ($code2 == hex("45"))) {
                $code = pack("C", hex("0a"));
                $i++;
            }
        }elsif (($code1 == hex("1f")) and ($code2 == hex("00"))) {
            my $ctlcodesizep = pack("C2", $code3, $code4);
            my $ctlcodesize = unpack("v", $ctlcodesizep);
            $ctlcodesize = 5 if ($ctlcodesize == 0);
            $i = $i + $ctlcodesize -1;
        }elsif ($code1 == hex("1e")){
            if ($code2 == hex("05")){
                my $ctlcodesize = 30;
                $i = $i + $ctlcodesize -1;
            }elsif ($code2 == hex("80")){
                my $ctlcodesize = 12;
                $i = $i + $ctlcodesize -1;
            }
        }elsif ($code1 == hex("fd")){
            if (($code2 >= hex("23")) and ($code2 <= hex("2f"))) {
                $i++;
            }elsif ($code2 >= hex("83")){
                $i++;
            }
        }elsif (($code1 == hex("12")) and ($code3 >= hex("80"))) {
            $i = $i + 2;
        }elsif (($code1 >= hex("81")) and ($code1 <= hex("84"))
          and ($code2 >= hex("40")) and ($code2 < hex("fe"))) {
            $code = pack("CC", $code1, $code2);
            $i++;
        }elsif (($code1 >= hex("88")) and ($code1 <= hex("9f"))
          and ($code2 >= hex("40")) and ($code2 < hex("fe"))) {
            $code = pack("CC", $code1, $code2);
            $i++;
        }elsif (($code1 >= hex("e0")) and ($code1 <= hex("ea"))
          and ($code2 >= hex("40")) and ($code2 < hex("fe"))) {
            $code = pack("CC", $code1, $code2);
            $i++;
        }elsif (($code1 >= hex("20")) and ($code1 <= hex("7f"))) {
            $code = pack("C", $code1);
        } elsif ($code1 >= hex("80")) {
            $code = pack("CC", 0x81, 0xac);    # GETA
            $i++;
        }
        $i++;
        $tmp .= $code;
        $code = "";
    }

    $$cont = $tmp;

    # codeconv::toeuc($cont);
    codeconv::codeconv_document($cont);

    gfilter::line_adjust_filter($cont);
    gfilter::line_adjust_filter($weighted_str);
    gfilter::white_space_adjust_filter($cont);
    $fields->{'title'} = gfilter::filename_to_title($cfile, $weighted_str)
      unless $fields->{'title'};
    gfilter::show_filter_debug_info($cont, $weighted_str,
			   $fields, $headings);
    return undef;
}

1;
