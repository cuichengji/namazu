#
# -*- Perl -*-
# $Id: extzip.pl,v 1.2.2.5 2014-02-11 13:50:19 opengl2772 Exp $
# Copyright (C) 2008-2014 Tadamasa Teranishi All rights reserved.
# Copyright (C) 2008-2014 Namazu Project All rights reserved.
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

package extzip;
use strict;
use English;
require 'util.pl';

use vars qw($zip_read $zip_membersMatching);

$zip_read = undef;
$zip_membersMatching = undef;

# ZIP
use constant NMZ_AZ_OK           => 0;
use constant NMZ_AZ_STREAM_END   => 1;
use constant NMZ_AZ_ERROR        => 2;
use constant NMZ_AZ_FORMAT_ERROR => 3;
use constant NMZ_AZ_IO_ERROR     => 4;

my $_converter = '';
my $_unzippath = undef;
my @_unzipopts = ();

sub setup()
{
    return 'yes' if (defined $zip_read);

    if (util::checklib('Archive/Zip.pm')) {
        eval 'use Archive::Zip;';
        if (util::checklib('IO/String.pm')) {
            eval 'use IO::String;';
            $zip_read = \&_az_is_zread;
            $zip_membersMatching = \&_az_is_zmembersMatching;
            $_converter = 'module_archive::zip, module_io::string';
        } else {
            $zip_read = \&_az_zread;
            $zip_membersMatching = \&_az_zmembersMatching;
            $_converter = 'module_archive::zip';
        }
        return 'yes';
    }

    $_unzippath = util::checkcmd('unzip');
    if (defined $_unzippath) {
        $zip_read = \&_unzip_zread;
        @_unzipopts = ("-p");
        $zip_membersMatching = \&_unzip_zmembersMatching;
        $_converter = 'unzip';
        return 'yes';
    }

    $zip_read = undef;
    $zip_membersMatching = undef;
    return 'no';
}

sub converter()
{
    return $_converter;
}

#
# zip_read
#

sub _unzip_zread($$$)
{
    my ($contref, $filename, $conts) = @_;

    util::vprint("Processing zip file ... (using  '$_unzippath')\n");

    my $tmpfile = '';
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

    my @cmd = ($_unzippath, @_unzipopts, $tmpfile, $filename);
    my $status = util::syscmd(
        command => \@cmd,
        option => {
            "stdout" => $conts,
            "stderr" => "/dev/null",
            "mode_stdout" => "wb",
            "mode_stderr" => "wt",
        },
    );
    unlink $tmpfile;

    return "Unable to convert file ($_unzippath error occurred)."
        if ($status != 0);

    my $size = length($$conts);
    if ($size == 0) {
        util::dprint("$filename: filesize is 0");
        return "Unable to convert file ($_unzippath error occurred).";
    } elsif ($size > $conf::FILE_SIZE_MAX) {
        util::dprint("$filename: Too large zip file");
        return 'Too large zip file.';
    }

    return undef;
}

#
# use Archive::Zip module
#

sub _az_is_zread($$$)
{
    my ($contref, $filename, $conts) = @_;

    util::vprint("Processing zip file ... (using  Archive::Zip, IO::String module)\n");

    my $io = IO::String->new($$contref);

    $$conts = '';

    my $zip = Archive::Zip->new();
    my $err = $zip->readFromFileHandle($io);
    if ($err != NMZ_AZ_OK) {
        util::dprint("Archive::Zip: there was a error($err)");
        return "Unable to convert file (Archive::Zip error occurred).";
    }

    my $member = $zip->memberNamed($filename);
    return "Not found '$filename'" if (!defined $member);
    my $size = $member->uncompressedSize();
    if ($size == 0) {
        my $fname = $member->fileName();
        util::dprint("$fname: filesize is 0");
        return "Unable to convert file (Archive::Zip error occurred).";
    } elsif ($size > $conf::FILE_SIZE_MAX) {
        my $fname = $member->fileName();
        util::dprint("$fname: Too large zip file");
        return 'Too large zip file.';
    }

    $$conts = $zip->contents($member);

    return undef;
}

sub _az_zread($$$)
{
    my ($contref, $filename, $conts) = @_;

    util::vprint("Processing zip file ... (using  Archive::Zip module)\n");

    my $tmpfile = '';
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

    $$conts = '';

    my $zip = Archive::Zip->new();
    my $err = $zip->read($tmpfile);
    if ($err != NMZ_AZ_OK) {
        util::dprint("Archive::Zip: there was a error($err)");
        unlink $tmpfile;
        return "Unable to convert file (Archive::Zip error occurred).";
    }

    my $member = $zip->memberNamed($filename);
    if (!defined $member) {
        unlink $tmpfile;
    	return "Not found '$filename'";
	}
    my $size = $member->uncompressedSize();
    if ($size == 0) {
        my $fname = $member->fileName();
        util::dprint("$fname: filesize is 0");
        unlink $tmpfile;
        return "Unable to convert file (Archive::Zip error occurred).";
    } elsif ($size > $conf::FILE_SIZE_MAX) {
        my $fname = $member->fileName();
        util::dprint("$fname: Too large zip file");
        unlink $tmpfile;
        return 'Too large zip file.';
    }

    $$conts = $zip->contents($member);

    unlink $tmpfile;
    return undef;
}

#
# zip membersMatching
#

sub _unzip_zmembersMatching($$$) {
    my ($zipref, $pattern, $pagesref) = @_;

    util::vprint("MembersMatching ... (using  '$_unzippath')\n");

    my $tmpfile = '';
    my $uniqnumber = int(rand(10000));
    do {
        $tmpfile = util::tmpnam('NMZ.zip' . substr("000$uniqnumber", -4));
        $uniqnumber++;
    } while (-f $tmpfile);
    {
        my $fh = util::efopen("> $tmpfile");
        print $fh $$zipref;
        util::fclose($fh);
    }

    my @unzipopts_getlist = ("-Z", "-1");
    my @cmd = ($_unzippath, @unzipopts_getlist, $tmpfile);
    my $file_list;
    my $status = util::syscmd(
        command => \@cmd,
        option => {
            "stdout" => \$file_list,
            "stderr" => "/dev/null",
            "mode_stdout" => "wt",
            "mode_stderr" => "wt",
        },
    );
    if ($status == 0) {
        while ($file_list =~ m/^($pattern)$/mgx) {
            my $filename = $1;
            push(@$pagesref, $filename);
        }
    }
    unlink $tmpfile;
    return undef;
}

#
# use Archive::Zip module
#

sub _az_is_zmembersMatching($$$) {
    my ($zipref, $pattern, $pagesref) = @_;

    util::vprint("MembersMatching ... (using  Archive::Zip, IO::String module)\n");

    my $io = IO::String->new($$zipref);

    my $zip = Archive::Zip->new();
    my $err = $zip->readFromFileHandle($io);
    if ($err != NMZ_AZ_OK) {
        util::dprint("Archive::Zip: there was a error($err)");
        return "Archive::Zip: there was a error($err)";
    }

    my @members = $zip->membersMatching("^($pattern)\$");
    foreach my $member (@members) {
        push(@$pagesref, $member->fileName());
    }

    return undef;
}

sub _az_zmembersMatching($$$) {
    my ($zipref, $pattern, $pagesref) = @_;

    util::vprint("MembersMatching ... (using  Archive::Zip module)\n");

    my $tmpfile = '';
    my $uniqnumber = int(rand(10000));
    do {
        $tmpfile = util::tmpnam('NMZ.zip' . substr("000$uniqnumber", -4));
        $uniqnumber++;
    } while (-f $tmpfile);
    {
        my $fh = util::efopen("> $tmpfile");
        print $fh $$zipref;
        util::fclose($fh);
    }

    my $zip = Archive::Zip->new();
    my $err = $zip->read($tmpfile);
    if ($err != NMZ_AZ_OK) {
        util::dprint("Archive::Zip: there was a error($err)");
        unlink $tmpfile;
        return "Archive::Zip: there was a error($err)";
    }

    my @members = $zip->membersMatching("^($pattern)\$");
    foreach my $member (@members) {
        push(@$pagesref, $member->fileName());
    }

    unlink $tmpfile;
    return undef;
}

1;
