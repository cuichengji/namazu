#
# -*- Perl -*-
# $Id: mp3.pl,v 1.1.2.18 2014-09-24 05:22:55 knok Exp $
# Copyright (C) 2002 Luc@2113.ch ,
#               2003-2008 Namazu Project All rights reserved ,
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

package mp3;
use strict;

require 'util.pl';
require 'gfilter.pl';

my $rpmpath = undef;

sub mediatype() {
    return ('audio/mpeg');
}

sub status() {
    # http://sourceforge.net/projects/pudge/
    if (util::checklib('MP3/Info.pm')) {
        eval 'use MP3::Info 1.01;';
        return 'yes' unless $@;
    }
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
    $magic->addMagicEntry("0\tstring\tID3\taudio/mpeg");
    return;
}

sub filter($$$$$) {
    my ($orig_cfile, $contref, $weighted_str, $headings, $fields)
      = @_;
    my $cfile = defined $orig_cfile ? $$orig_cfile : '';

    my $id3v2header = substr($$contref, 0, 3);
    unless ($id3v2header =~ /ID3/) {
        my $id3v1header = substr($$contref, -128, 3);
        unless ($id3v1header =~ /TAG/) {
            util::vprint("Couldn't find ID3 tag\n");
            $$contref = "";
            return undef;
        }
    }

    util::vprint("Processing mp3 file ... (using  MP3::Info module)\n");

    my $mp3;

    my $tmpfile  = util::tmpnam('NMZ.mp3');
    {
        my $fh = util::efopen("> $tmpfile");
        print $fh $$contref;
        util::fclose($fh);
    }
    $mp3 = $tmpfile;

    if ($MP3::Info::VERSION >= 1.10) {
        MP3::Info::use_mp3_utf8(0);
    }

    my $tagref = get_mp3tag($mp3);
    if (ref $tagref->{TITLE}) {
        $tagref = get_mp3tag($mp3, 2);
    }

    my $songname = defined $tagref->{TITLE} ? $tagref->{TITLE} : '';
    my $artist = defined $tagref->{ARTIST} ? $tagref->{ARTIST} : '';
    my $album = defined $tagref->{ALBUM} ? $tagref->{ALBUM} : '';
    my $year = defined $tagref->{YEAR} ? $tagref->{YEAR} : '';
    my $comment = defined $tagref->{COMMENT} ? $tagref->{COMMENT} : '';
    my $genre = defined $tagref->{GENRE} ? $tagref->{GENRE} : '';
    my $track = defined $tagref->{TRACKNUM} ? $tagref->{TRACKNUM} : '';

    $songname =~ s/\0//g;
    $artist =~ s/\0//g;
    $album =~ s/\0//g;
    $year =~ s/\0//g;
    $comment =~ s/\0//g;
    $genre =~ s/\0//g;
    $track =~ s/\0//g;

    my $data1 = "";
    $$contref = "";

    $data1 .= "Songname: $songname\n";
    $data1 .= "Artist: $artist\n";
    $data1 .= "Filename: " . gfilter::filename_to_title($cfile, $weighted_str);
    $data1 .= "\n\n";
    $data1 .= "Album: $album\n";
    $data1 .= "Comment: $comment\n";
    $data1 .= "Year: $year\n";
    $data1 .= "Genre: $genre\n";
    $data1 .= "Track: $track\n";

    # codeconv::toeuc(\$data1);
    codeconv::codeconv_document(\$data1);
    $$contref = $data1;
    mp3_filter($contref, $weighted_str, $fields, $headings);

    $data1 =~ /\n\n(.+)/sg;
    my $tmp = $1;
    mp3::get_summary($tmp, $fields);

    gfilter::line_adjust_filter($contref);
    gfilter::line_adjust_filter($weighted_str);
    gfilter::white_space_adjust_filter($contref);
    gfilter::show_filter_debug_info($contref, $weighted_str,
			   $fields, $headings);

    unlink $tmpfile;
    return undef;
}

sub mp3_filter($$$$) {
    my ($contref, $weighted_str, $fields, $headings) = @_;

    mp3::get_title($$contref, $weighted_str, $fields);
    mp3::get_author($$contref, $fields);
    mp3::get_album($$contref, $fields);
    $$contref =~ s/^\w+(:{1,1})?//gm;


    return;
}

sub get_title($$$) {
    my ($content, $weighted_str, $fields) = @_;

    if ($content =~ /Songname: (.*)/) {
	my $tmp = $1;
	$fields->{'title'} = $tmp;
    } else {
        $content =~ /Filename: (.*)/;
	my $tmp = $1;
	$fields->{'title'} = $tmp;
    }
    my $weight = $conf::Weight{'html'}->{'title'};
    $$weighted_str .= "\x7f$weight\x7f$fields->{'title'}\x7f/$weight\x7f\n";

}

sub get_author($$) {
    my ($content, $fields) = @_;

    if ($content =~ /Artist: (.*)/) {
	my $tmp = $1;
	$fields->{'author'} = $tmp;
    }
}

sub get_album($$) {
    my ($content, $fields) = @_;

    if ($content =~ /Album: (.*)/) {
	my $tmp = $1;
	$fields->{'album'} = $tmp;
    }
}

sub get_summary($$) {
    my ($content, $fields) = @_;
    $fields->{'summary'} = $content;
}

1;
