#
# -*- Perl -*-
# $Id: xdoc2txt.pl,v 1.1.2.6 2008-04-30 14:46:35 opengl2772 Exp $
# Copyright (C) 2004 HANAI,Akira All rights reserved.
# Copyright (C) 2005 Yukio USUDA All rights reserved.
# Copyright (C) 2005-2008 Namazu Project All rights reserved.
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

package xdoc2txt;
use strict;
use English;
require 'util.pl';
require 'gfilter.pl';

my $wordconvpath  = undef;
my $wordconvversion = 0.00;

sub mediatype() {
    my @media = qw(
	application/msword
	application/rtf
	application/pdf
	application/powerpoint
	application/excel
	application/x-js-taro
	application/ichitaro6
	application/ichitaro7
    );

    status();

    if ($wordconvversion >= 1.26) {
        push(@media,
            'application/vnd.openxmlformats-officedocument.wordprocessingml');
        push(@media,
            'application/vnd.openxmlformats-officedocument.spreadsheetml');
        push(@media,
            'application/vnd.openxmlformats-officedocument.presentationml');
    }

    return @media;
}

sub status() {
    $wordconvpath = util::checkcmd('xdoc2txt');
    return 'no' unless defined $wordconvpath;
    {
        my @cmd = ($wordconvpath, "-v");
        my $fh_out = IO::File->new_tmpfile();
        my $status = util::syscmd(
            command => \@cmd,
            option => {
                "stdout" => "/dev/null",
                "stderr" => $fh_out,
            },
        );
        $wordconvversion = util::readfile($fh_out);
        codeconv::normalize_document(\$wordconvversion);
        util::fclose($fh_out);

        if ($wordconvversion =~ m/(\d+\.\d+).*/) {
            $wordconvversion = $1;
        } else {
            $wordconvversion = 0.00;
        }
        util::dprint("$wordconvpath : $wordconvversion\n");
    }
    if ($English::PERL_VERSION >= 5.008) {
        eval 'use Encode qw/ from_to /;';
        if ($@) {return 'no'};
        eval 'use Encode::Guess qw/ shiftjis utf-8 /;';
        if ($@) {return 'no'};

        return 'yes';
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

    # FIXME: very ad hoc.
    $magic->addFileExts('\\.docx$', 'application/vnd.openxmlformats-officedocument.wordprocessingml');
    # FIXME: very ad hoc. Excel
    $magic->addFileExts('\\.xls$', 'application/excel');
    $magic->addFileExts('\\.xlsx$', 'application/vnd.openxmlformats-officedocument.spreadsheetml');
    $magic->addFileExts('\\.xlsm$', 'application/vnd.ms-excel.sheet.macroEnabled');
    $magic->addFileExts('\\.xlsb$', 'application/vnd.ms-excel.sheet.binary.macroEnabled');
    # FIXME: very ad hoc. PowerPoint
    $magic->addFileExts('\\.pp[st]$', 'application/powerpoint');
    $magic->addFileExts('\\.pp[st]x$', 'application/vnd.openxmlformats-officedocument.presentationml');
    # FIXME: very ad hoc. Visio
    $magic->addFileExts('\\.vs[dst]$', 'application/vnd.visio');
    $magic->addFileExts('\\.v[dst]x$', 'application/vnd.visio');
    # FIXME: very ad hoc. Ichitaro
    $magic->addFileExts('\\.jsw$', 'application/ichitaro4');
    $magic->addFileExts('\\.jaw$|\\.jtw$', 'application/ichitaro5');
    $magic->addFileExts('\\.jbw$|\\.juw$', 'application/ichitaro6');
    $magic->addFileExts('\\.jfw$|\\.jvw$', 'application/ichitaro7');
    $magic->addFileExts('\\.jtd$|\\.jtt$', 'application/x-js-taro');

    return;
}

sub filter ($$$$$) {
    my ($orig_cfile, $cont, $weighted_str, $headings, $fields)
      = @_;
    my $cfile = defined $orig_cfile ? $$orig_cfile : '';

    #Add extension to the conversion file name so that xdoc2txt.exe may
    #do the file distinction by the extension. 
    $cfile =~ /(\.[^\.]+)$/;
    my $ext = $1;
    $ext = '.ppt' if ($ext eq '.pps');
    $ext = '.pptx' if ($ext eq '.ppsx');
    my $tmpfile = util::tmpnam('NMZxdoc2txt');
    $tmpfile =~ s/\.tmp$/$ext/;
    util::writefile($tmpfile, $cont);
    {
        my @convopts = ("-e");
        my @cmd = ($wordconvpath, @convopts, $tmpfile);
        my $fh_out = IO::File->new_tmpfile();
        util::vprint("Processing file ... (using  '$wordconvpath')\n");
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
            return "Unable to convert file ($wordconvpath error occurred).";
        }
        if ($size > $conf::FILE_SIZE_MAX) {
            util::fclose($fh_out);
            unlink $tmpfile;
            return 'Too large file.';
        }
        $$cont = util::readfile($fh_out);
        util::fclose($fh_out);
    }
    my $prop = "";
    {
        my @convopts = ("-p");
        my @cmd = ($wordconvpath, @convopts, $tmpfile);
        my $fh_out = IO::File->new_tmpfile();
        util::vprint("Processing file ... (using  '$wordconvpath')\n");
        my $status = util::syscmd(
            command => \@cmd,
            option => {
                "stdout" => $fh_out,
                "stderr" => "/dev/null",
            },
        );
        my $size = util::filesize($fh_out);
        if ($size > $conf::FILE_SIZE_MAX) {
            util::fclose($fh_out);
            unlink $tmpfile;
            return 'Too large file.';
        }
        $prop = util::readfile($fh_out);
        util::fclose($fh_out);
    }
    unlink $tmpfile;

    codeconv::codeconv_document($cont);

    rm2byteutf8(\$prop);
    codeconv::codeconv_document(\$prop);

    if ($prop =~ /\<LastAuthor\>(.+)\<\/LastAuthor\>/) {
        $fields->{'author'} = $1;
    } elsif ($prop =~ /\<Author\>(.+)\<\/Author\>/) {
        $fields->{'author'} = $1;
    }

    if ($prop =~ /\<Title\>(.+)\<\/Title\>/) {
        $fields->{'title'} = $1;
    } elsif ($prop =~ /\<Subject\>(.+)\<\/Subject\>/) {
        $fields->{'title'} = $1;
    } else {
        $fields->{'title'} = gfilter::filename_to_title($cfile, $weighted_str);
    }

    gfilter::line_adjust_filter($cont);
    gfilter::line_adjust_filter($weighted_str);
    gfilter::white_space_adjust_filter($cont);
    gfilter::show_filter_debug_info($cont, $weighted_str,
               $fields, $headings);

    return undef;
}

sub rm2byteutf8 ($) {
    my ($property) = @_;

    my $enc = guess_encoding($$property);
    if (ref $enc) {
        $$property =~ s/[\xC2-\xDF][\x80-\xBF]/ /g if ($enc->name eq 'utf8');
        Encode::from_to($$property, $enc->name, 'euc-jp');
    } else {
        $$property = "";
        util::dprint("Encode::Guess couldn't find coding name");
    }
}

1;
