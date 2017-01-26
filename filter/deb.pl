#
# -*- Perl -*-
# $Id: deb.pl,v 1.5.4.10 2008-05-09 07:22:08 opengl2772 Exp $
# Copyright (C) 2000-2008 Namazu Project All rights reserved ,
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

package deb;
use strict;
require 'util.pl';
require 'gfilter.pl';

my $dpkgpath = undef;
my @dpkgopts = undef;

sub mediatype() {
    return ('application/x-deb');
}

sub status() {
    $dpkgpath = util::checkcmd('dpkg');
    @dpkgopts = ("--info");
    return 'no' unless (defined $dpkgpath);
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
    $magic->addFileExts('\\.deb$', 'application/x-deb');
    return;
}

sub filter ($$$$$) {
    my ($orig_cfile, $cont, $weighted_str, $headings, $fields)
	= @_;
    my $cfile = defined $orig_cfile ? $$orig_cfile : '';

    util::vprint("Processing deb file ... (using  '$dpkgpath')\n");

    my $tmpfile = util::tmpnam('NMZ.deb');
    {	
	my $fh = util::efopen("> $tmpfile");
	print $fh $$cont;
        util::fclose($fh);
    }
    {
        my %env = (
            "LC_ALL" => $util::LANG,
            "LANGUAGE" => $util::LANG,
        );
	my @cmd = ($dpkgpath, @dpkgopts, $tmpfile);
        my $fh_out = IO::File->new_tmpfile();
        my $status = util::syscmd(
            command => \@cmd,
            option => {
                "stdout" => $fh_out,
                "stderr" => "/dev/null",
            },
            env => \%env,
        );
	my $size = util::filesize($fh_out);
	if ($size == 0) {
            util::fclose($fh_out);
            unlink $tmpfile;
	    return "Unable to convert file ($dpkgpath error occurred)";
	}
	if ($size > $conf::FILE_SIZE_MAX) {
            util::fclose($fh_out);
            unlink $tmpfile;
	    return 'Too large deb file';
	}
	$$cont = util::readfile($fh_out);
        util::fclose($fh_out);
    }
    unlink $tmpfile;

    codeconv::normalize_document($cont);

    dpkg_filter($cont, $weighted_str, $fields, $headings);

    gfilter::line_adjust_filter($cont);
    gfilter::line_adjust_filter($weighted_str);
    gfilter::white_space_adjust_filter($cont);
    $fields->{'title'} = gfilter::filename_to_title($cfile, $weighted_str)
	unless $fields->{'title'};
    gfilter::show_filter_debug_info($cont, $weighted_str,
				    $fields, $headings);

    return undef;
}

sub dpkg_filter ($$$$) {
    my ($contref, $weighted_str, $fields, $headings) = @_;

    deb::get_title($contref, $weighted_str, $fields);
    deb::get_author($contref, $fields);
#    deb::get_date($contref, $fields);
    deb::get_size($contref, $fields);
    deb::get_summary($contref, $fields);

    return;
}


# Below is the sample result of 'dpkg --info deb'.
#
#  new debian package, version 2.0.
#  size 30606 bytes: control archive= 1247 bytes.
#      351 bytes,    12 lines      control
#     1174 bytes,    18 lines      md5sums
#      389 bytes,    11 lines   *  postinst             #!/bin/sh
#      143 bytes,     4 lines   *  postrm               #!/bin/sh
#      184 bytes,     6 lines   *  prerm                #!/bin/sh
#  Package: irb
#  Version: 1.6.2-1
#  Section: interpreters
#  Priority: optional
#  Architecture: all
#  Depends: ruby (>= 1.6.2-1), libreadline-ruby (>= 1.6.2-1)
#  Installed-Size: 139
#  Maintainer: akira yamada <akira@debian.org>
#  Source: ruby
#  Description: The Intaractive Ruby.
#   The irb is acronym for Interactive RuBy.  It evaluates ruby expression
#   from the terminal.

sub get_title ($$$) {
    my ($contref, $weighted_str, $fields) = @_;

    if ($$contref =~ /^ Description: (.*)/m) {
	my $tmp = $1;
	$fields->{'title'} = $tmp;
	my $weight = $conf::Weight{'html'}->{'title'};
	$$weighted_str .= "\x7f$weight\x7f$tmp\x7f/$weight\x7f\n";
    }
}

sub get_author ($$) {
    my ($contref, $fields) = @_;

    if ($$contref =~ /^ Maintainer: (.*)/m) {
	my $tmp = $1;
	$fields->{'author'} = $tmp;
    }
}

sub get_size ($$) {
    my ($contref, $fields) = @_;

    if ($$contref =~ /^ size (\d+) bytes:/m) {
	my $tmp = $1;
	$fields->{'size'} = $tmp;
    }
}

sub get_summary ($$) {
    my ($contref, $fields) = @_;

    if ($$contref =~ /^.*Description:[^\n]*\n(.*)/is) {
	my $tmp = $1;
	$fields->{'summary'} = $tmp;
    }
}

1;
