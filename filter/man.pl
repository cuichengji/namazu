#
# -*- Perl -*-
# $Id: man.pl,v 1.26.8.9 2008-05-09 07:46:45 opengl2772 Exp $
# Copyright (C) 1997-2000 Satoru Takabayashi ,
#               1999 NOKUBI Takatsugu ,
#               2000-2008 Namazu Project All rights reserved.
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

package man;
use strict;
require 'util.pl';
require 'gfilter.pl';

my $roffpath = undef;
my @roffopts = undef;
my %env = ();

sub mediatype() {
    return ('text/x-roff');
}

sub status() {
    $roffpath = util::checkcmd('jgroff');
    $roffpath = util::checkcmd('groff') unless (defined $roffpath);
    $roffpath = util::checkcmd('nroff') unless (defined $roffpath);
    unless (defined $roffpath) {
	return 'no';
    }
    %env = (
        "LC_ALL" => $util::LANG,
        "LANGUAGE" => $util::LANG,
    );

    if (util::islang("ja") && $roffpath =~ /\bj?groff$/) {
	# Check wheter -Tnippon is valid.
	my @cmd = ($roffpath, "-Tnippon", util::devnull());
        my $status = util::syscmd(
            command => \@cmd,
            option => {
                "stdout" => "/dev/null",
                "stderr" => "/dev/null",
            },
            env => \%env,
        );
	if ($status == 0) {
	    @roffopts = ('-man', '-Wall', '-Tnippon');
	} else {
	    @roffopts = ('-man', '-Wall', '-Tascii');
	}
    } elsif ($roffpath =~ /\bj?groff$/) {
	@roffopts = ('-man', '-Tascii');
    } elsif ($roffpath =~ /nroff$/) {
	@roffopts = ('-man');
    } else {
	return 'no';
    }
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
    return;
}

sub filter ($$$$$) {
    my ($orig_cfile, $cont, $weighted_str, $headings, $fields)
	= @_;
    my $cfile = defined $orig_cfile ? $$orig_cfile : '';

    util::vprint("Processing man file ... (using  '$roffpath @roffopts')\n");

    my $tmpfile = util::tmpnam('NMZ.man');
    {
	my $fh = util::efopen("> $tmpfile");

	# Make groff output one paragraph per one line.
	# Thanks to Tatsuo SEKINE <tsekine@isoternet.org> for his suggestion.
	print $fh ".ll 100i\n";

	print $fh $$cont;
        util::fclose($fh);
    }
    {
	my @cmd = ($roffpath, @roffopts, $tmpfile);
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
	    return "Unable to convert file ($roffpath error occurred)";
	}
	if ($size > $conf::FILE_SIZE_MAX) {
            util::fclose($fh_out);
            unlink $tmpfile;
	    return 'Too large man file';
	}
	$$cont = util::readfile($fh_out);
        util::fclose($fh_out);
    }
    unlink $tmpfile;

    # codeconv::toeuc($cont);
    codeconv::codeconv_document($cont);

    man_filter($cont, $weighted_str, $fields);

    gfilter::line_adjust_filter($cont);
    gfilter::line_adjust_filter($weighted_str);
    gfilter::white_space_adjust_filter($cont);
    $fields->{'title'} = gfilter::filename_to_title($cfile, $weighted_str)
	unless $fields->{'title'};
    gfilter::show_filter_debug_info($cont, $weighted_str,
				    $fields, $headings);
    return undef;
}

# This is not perfect but works not bad.
sub man_filter ($$$) {
    my ($contref, $weighted_str, $fields) = @_;
    my $name = "";

    # remove escape sequence
    $$contref =~ s/\x1b\[[01]m//gs;

    # processing like col -b (2byte character acceptable)
    $$contref =~ s/_\x08//g;
    $$contref =~ s/\x08{1,2}([\x20-\x7e]|[\xa1-\xfe]{2})//g;

    $$contref =~ s/^\s+//gs;

    $$contref =~ /^(.*?)\s*\S*$/m;
    my $title = "$1";
    $fields->{'title'} = $title;
    my $weight = $conf::Weight{'html'}->{'title'};
    $$weighted_str .= "\x7f$weight\x7f$title\x7f/$weight\x7f\n";

    if ($$contref =~ /^(?:NAME|名前|名称)\s*\n(.*?)\n\n/ms) {
	$name = "$1::\n";
	$weight = $conf::Weight{'html'}->{'h1'};
	$$weighted_str .= "\x7f$weight\x7f$1\x7f/$weight\x7f\n";
    }

    if ($$contref =~
	s/\A(.+^(?:DESCRIPTION 解説|DESCRIPTIONS?|SHELL GRAMMAR|INTRODUCTION|【概要】|解説|説明|機能説明|基本機能説明)\s*\n)//ims)
    {
	$$contref = $name . $$contref;
	$$weighted_str .= "\x7f1\x7f$1\x7f/1\x7f\n";
    }
}

1;
