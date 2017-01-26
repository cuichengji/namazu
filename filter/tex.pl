#
# -*- Perl -*-
# $Id: tex.pl,v 1.7.8.5 2007-01-14 04:12:04 opengl2772 Exp $
# Copyright (C) 1999 Satoru Takabayashi ,
#               2004-2007 Namazu Project All rights reserved.
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

package tex;
use strict;
require 'util.pl';
require 'gfilter.pl';

my $texconvpath = undef;
my @texconvopts = undef;

sub mediatype() {
    return ('application/x-tex');
}

sub status() {
    $texconvpath = util::checkcmd('detex');
    @texconvopts = ("-n");
    return 'yes' if (defined $texconvpath);
    return 'no';
}

sub recursive() {
    return 0;
}

sub pre_codeconv() {
    return 1;
}

sub post_codeconv () {
    return 0;
}

sub add_magic ($) {
    my ($magic) = @_;

    $magic->addSpecials("application/x-tex",
			"^\\\\document(style|class)",
			"^\\\\begin\\{document\\}",
			"^\\\\section\\{[^}]+\\}");

    # FIXME: very ad hoc.
    $magic->addFileExts('\\.tex$', 'application/x-tex');
    return;
}

sub filter ($$$$$) {
    my ($orig_cfile, $cont, $weighted_str, $headings, $fields)
      = @_;
    my $cfile = defined $orig_cfile ? $$orig_cfile : '';

    util::vprint("Processing tex file ... (using  '$texconvpath')\n");

    if ($$cont =~ m/\\title\{(.*?)\}/s) {
	$fields->{'title'} = $1;
	$fields->{'title'} =~ s/\\\\/ /g;
    }
    if ($$cont =~ m/\\author\{(.*?)\}/s) {
	$fields->{'author'} = $1;
	$fields->{'author'} =~ s/\\\\/ /g;
    }
    if ($$cont =~ m/\\begin\{abstract\}(.*?)\\end\{abstract\}/s) {
	$fields->{'summary'} = $1;
	$fields->{'summary'} =~ s/\\\\/ /g;
    }

    my $tmpfile = util::tmpnam('NMZ.tex');
    {
	my $fh = util::efopen("> $tmpfile");
	print $fh $$cont;
        util::fclose($fh);
    }
    {
	my @cmd = ($texconvpath, @texconvopts, $tmpfile);
        my $fh_out = IO::File->new_tmpfile();
        my $status = util::syscmd(
            command => \@cmd,
            option => {
                "stdout" => $fh_out,
                "stderr" => "/dev/null",
            },
        );
	my $size = util::filesize($fh_out);
	if ($size == 0) {
            util::fclose($fh_out);
            unlink $tmpfile;
	    return "Unable to convert file ($texconvpath error occurred).";
	}
	if ($size > $conf::FILE_SIZE_MAX) {
            util::fclose($fh_out);
            unlink $tmpfile;
	    return 'Too large tex file.';
	}
	$$cont = util::readfile($fh_out);
        util::fclose($fh_out);
    }
    unlink $tmpfile;

    codeconv::normalize_document($cont);

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
