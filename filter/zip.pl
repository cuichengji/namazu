#
# -*- Perl -*-
# $Id: zip.pl,v 1.10.4.17 2008-09-01 14:43:23 opengl2772 Exp $
#  zip filter for Namazu
#  Copyright (C) 2004 MATSUMURA Namihiko <po-jp@counterghost.net>
#                2004 Yukio USUDA <usu@namazu.org>
#                2004-2008 Namazu Project All rights reserved.
#
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

package zip;
use strict;
require 'util.pl';

my $unzippath = undef;
my $_filter = undef;

sub mediatype() {
    return ('application/x-zip');
}

sub status() {
    if (util::checklib('Compress/Zlib.pm') and
    util::checklib('Archive/Zip.pm')) {
        $_filter = \&_az_filter;
        return 'yes';
    }

    $unzippath = util::checkcmd('unzip');
    $_filter = \&_unzip_filter;
    return 'yes' if (defined $unzippath);

    $_filter = undef;
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
    $magic->addFileExts('\\.zip$', 'application/x-zip');
    return;
}

sub filter ($$$$$) {
    my ($orig_cfile, $contref, $weighted_str, $headings, $fields)
      = @_;

    my $err = undef;
    $err = $_filter->($contref, $weighted_str, $headings, $fields);
    return $err;
}

sub _az_filter ($$$$) {
    my ($contref, $weighted_str, $headings, $fields) = @_;

    util::vprint("Processing zip file ... (using  Archive::Zip module)\n");

    my $tmpfile;
    my $uniqnumber = int(rand(10000));
    do {
        $tmpfile = util::tmpnam('NMZ.zip' . substr("000$uniqnumber", -4));
        $uniqnumber++;
    } while (-f $tmpfile);

    {
        my $fh = util::efopen("> $tmpfile");
        print $fh $$contref;
        util::fclose($fh);
    }
    $$contref = '';

    eval 'use Archive::Zip;';
    my $zip = Archive::Zip->new();
    my $err = $zip->read($tmpfile);
    if ($err != 0) {
        util::dprint("Archive::Zip: there was a error");
        unlink($tmpfile);
        return 'Unable to convert zip file (Archive::Zip error occurred).';
    }
    {
        my $comment = $zip->zipfileComment();
        my @filenames = $zip->memberNames();
        my $tmp = join(" ", @filenames);
        # codeconv::toeuc(\$tmp);
        codeconv::codeconv_document(\$tmp);
        $$contref = $comment . " " . $tmp . " ";
    }
    my @members = $zip->members();
    my $member;
    foreach $member (@members) {
        next if (($member->isEncrypted() or $member->isDirectory()));

        my $size = $member->uncompressedSize();
        my $fname = $member->fileName();
        if ($size == 0) {
            util::dprint("$fname: filesize is 0");
        } elsif ($size > $conf::FILE_SIZE_MAX) {
            util::dprint("$fname: Too large ziped file");
        } elsif ($fname =~ m!^($conf::DENY_FILE)$!i) {
            # codeconv::toeuc(\$fname);
            codeconv::codeconv_document(\$fname);
            util::vprint(sprintf(_("Denied:	%s"), $fname));
        } elsif ($fname !~ m!^($conf::ALLOW_FILE)$!i) {
            # codeconv::toeuc(\$fname);
            codeconv::codeconv_document(\$fname);
            util::vprint(sprintf(_("Not allowed:	%s"), $fname));
        } else {
            my $con = $zip->contents($member);
            if ($con) {
                my $unzippedname = "unzipped_content";
                if ($fname =~ /.*(\..*)/) {
                    $unzippedname = $unzippedname . $1;
                }
                my $err = zip::nesting_filter($unzippedname, \$con, $weighted_str);
                if (defined $err) {
                    util::dprint("filter/zip.pl gets error message \"$err\"");
                }
                $$contref .= $con . " ";
            }
        }
    }
    unlink($tmpfile);
    return undef;
}

sub _unzip_filter ($$$$) {
    my ($contref, $weighted_str, $headings, $fields) = @_;

    util::vprint("Processing zip file ... (using  '$unzippath')\n");

    my $tmpfile;
    my $uniqnumber = int(rand(10000));
    do {
        $tmpfile = util::tmpnam('NMZ.zip' . substr("000$uniqnumber", -4));
        $uniqnumber++;
    } while (-f $tmpfile);

    {
        my $fh = util::efopen("> $tmpfile");
        print $fh $$contref;
        util::fclose($fh);
    }
    $$contref = '';

    my @cmd = ("$unzippath", "-P", "passwd", "-qq", "-t", "$tmpfile");
    my $status = util::syscmd(
        command => \@cmd,
        option => {
            "stdout" => "/dev/null",
            "stderr" => "/dev/null",
        },
    );
    if ($status != 0) {
        unlink($tmpfile);
        return 'Unable to convert zip file (maybe copying protection)';
    }

    my $tmpfile2 = util::tmpnam('NMZ.zip_comment');
    @cmd = ("$unzippath", "-z", "-qq", "$tmpfile");
    $status = util::syscmd(
        command => \@cmd,
        option => {
            "stdout" => $tmpfile2,
            "stderr" => "/dev/null",
        },
    );
    if ($status == 0) {
        my $summary = util::readfile("$tmpfile2");
        # codeconv::toeuc(\$summary);
        codeconv::codeconv_document(\$summary);
        $$contref .= $summary . " ";
    }

    my %files;
    my $filenames = undef;
    @cmd = ("$unzippath", "-Z", "$tmpfile");
    $status = util::syscmd(
        command => \@cmd,
        option => {
            "stdout" => $tmpfile2,
            "stderr" => "/dev/null",
        },
    );
    if ($status == 0) {
        my $filelist = util::readfile("$tmpfile2");
        codeconv::normalize_document(\$filelist);
        while ($filelist =~/\n\S+\s+	# permission
                        \S+\s+		# version
                        (\S+)\s+	# filesystem
                        (\d+)\s+	# filesize
                        \S+\s+		#
                        \S+\s+		#
                        \S+\s+		# day-month-year
                        \S+\s+		# hour:min
                        (.+)/gx) {	# filename
            my $filename = $3;
            $files{$filename} = $2;
            my $filesystem = $1;
            # The unzip output japanese filename incorrectly when filesystem
            # attribute is 'fat' or 'hpfs'.
            if ($filesystem =~ /unx|ntf/) {
                $filename = './' . $filename;
                # codeconv::toeuc(\$filename);
                codeconv::codeconv_document(\$filename);
                $filename = gfilter::filename_to_title($filename, $weighted_str);
                $filenames .= $filename . " ";
            }
        }
    }
    $$contref .= $filenames . " " if (defined $filenames);

    unlink($tmpfile2);

    my $fname;
    foreach $fname (keys %files) {
        my $size = $files{$fname};
        if ($size == 0) {
            util::dprint("$fname: filesize is 0");
        } elsif ($size > $conf::FILE_SIZE_MAX) {
            util::dprint("$fname: Too large ziped file");
        } elsif ($fname =~ m!^($conf::DENY_FILE)$!i) {
            # codeconv::toeuc(\$fname);
            codeconv::codeconv_document(\$fname);
            util::vprint(sprintf(_("Denied:	%s"), $fname));
        } elsif ($fname !~ m!^($conf::ALLOW_FILE)$!i) {
            # codeconv::toeuc(\$fname);
            codeconv::codeconv_document(\$fname);
            util::vprint(sprintf(_("Not allowed:	%s"), $fname));
        } else {
            my $con = "";
            my @cmd = ("$unzippath", "-p", "$tmpfile", "$fname");
            my $status = util::syscmd(
                command => \@cmd,
                option => {
                    "stdout" => \$con,
                    "stderr" => "/dev/null",
                    "mode_stdout" => "wb",
                    "mode_stderr" => "wt",
                },
            );
            my $unzippedname = "unzipped_content";
            if ($fname =~ /.*(\..*)/) {
                $unzippedname = $unzippedname . $1;
            }
            my $err = zip::nesting_filter($unzippedname, \$con, $weighted_str);
            if (defined $err) {
                util::dprint("filter/zip.pl gets error message \"$err\"");
            }
            $$contref .= $con . " ";
        }
    };
    unlink($tmpfile);
    return undef;
}

sub nesting_filter ($$$){
    my ($filename, $contref, $weighted_str) = @_;
    my $err = undef;
    my $dummy_shelterfname = "";
    my $headings = "";
    my %fields;
    my $mmtype = undef;

    my ($kanji, $mtype) = mknmz::apply_filter(\$filename, $contref,
                        $weighted_str, \$headings, \%fields,
                        $dummy_shelterfname, $mmtype);

    if ($mtype =~ /; x-system=unsupported$/) {
        $$contref = "";
        $err = $mtype;
    } elsif ($mtype =~ /; x-error=(.*)$/) {
        $$contref = "";
        $err = $1;
    } else {
        gfilter::show_filter_debug_info($contref, $weighted_str,
                                        \%fields, \$headings);
        for my $field (keys %fields) {
            $$contref .= " ". $fields{$field};
        }
    }
    return $err;
}

1;
