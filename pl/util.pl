#
# -*- Perl -*-
# $Id: util.pl,v 1.22.4.17 2017-01-09 13:44:00 opengl2772 Exp $
# Copyright (C) 1997-1999 Satoru Takabayashi All rights reserved.
# Copyright (C) 2000-2017 Namazu Project All rights reserved.
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

package util;
use strict;
use English;
use IO::File;
require 'time.pl';

use vars qw($LANG_MSG $LANG);
$LANG_MSG = "C";           # language of messages
$LANG = "C";               # language of text processing

#  rename() with consideration for OS/2
sub Rename($$) {
    my ($from, $to) = @_;

    return unless -e $from;
    unlink $to if (-f $from) && (-f $to); # some systems require this
    if (0 == rename($from, $to)) {
        cdie("rename($from, $to): $!\n");
    }
    dprint(_("Renamed: ")."$from, $to\n");
}

sub efopen ($) {
    my ($fname) = @_;

    my $fh = fopen($fname) || cdie("$fname: $!\n");

    return $fh;
}

sub fopen ($) {
    my ($fname) = @_;
    my $fh = new IO::File;

    if ($fh->open($fname)) {
        binmode($fh);
    } else {
        $fh = undef;
    }

    return $fh;
}

sub fclose ($) {
    my ($arg) = @_;

    if (ref $arg) {
        if ($arg =~ /^(IO::File|FileHandle)/) {
            my $fh = $arg;
            $fh->flush;
            cdie("write error: $!\n") if ($fh->error);
            $fh->close();
            return undef;
        }
    }

    warn "$arg: " . _("not an IO::File/FileHandle object!\n");
    return undef;
}

sub dprint (@) {
    if ($var::Opt{'debug'}) {
        for my $str (@_) {
            map {print STDERR '// ', $_, "\n"} split "\n", $str;
        }
    }
}

sub vprint (@) {
    if ($var::Opt{'verbose'} || $var::Opt{'debug'}) {
        for my $str (@_) {
            map {print STDERR '@@ ', $_, "\n"} split "\n", $str;
        }
    }
}

sub commas ($) {
    my ($num) = @_;

    $num = "0" if ($num eq "");
#    1 while $num =~ s/(.*\d)(\d\d\d)/$1,$2/;
    # from Mastering Regular Expressions
    $num =~ s<\G((?:^-)?\d{1,3})(?=(?:\d\d\d)+(?!\d))><$1,>g;
    $num;
}

# RFC 822 format
sub rfc822time ($)
{
    my ($time) = @_;

    my @week_names = ("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat");
    my @month_names = ("Jan", "Feb", "Mar", "Apr", "May", "Jun",
		       "Jul", "Aug", "Sep", "Oct", "Nov", "Dec");
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst)
	= localtime($time);

    return sprintf("%s, %.2d %s %d %.2d:%.2d:%.2d %s",
		   $week_names[$wday],
		   $mday, $month_names[$mon], $year + 1900,
		   $hour, $min, $sec, time::gettimezone());
}

sub readfile ($) {
    my ($arg) = @_;

    my $fh;
    if (ref $arg) {
        if ($arg =~ /^(IO::File|FileHandle)/) {
            $fh = $arg;
        } else {
            warn "$arg: " . _("not an IO::File/FileHandle object!\n");
            return '';
        }
    } else {
        $fh = efopen($arg);
    }

    my $cont = "";
    my $size = -s $fh;
#    if ($size > $conf::FILE_SIZE_LIMIT) {
#	warn "$arg: too large!\n";
#	return '';
#    }
    read $fh, $cont, $size;

    unless (ref $arg) {
        fclose($fh);
    }
    return $cont;
}

sub writefile ($$) {
    my ($arg, $cont) = @_;

    my $fh;
    if (ref $arg) {
        if ($arg =~ /^(IO::File|FileHandle)/) {
            $fh = $arg;
        } else {
            warn "$arg: " . _("not an IO::File/FileHandle object!\n");
            return undef;
        }
    } else {
        $fh = efopen("> $arg");
    }

    print $fh $$cont;

    unless (ref $arg) {
        fclose($fh);
    }
    return undef;
}

sub filesize($) {
    my ($arg) = @_;
    my $fh;
    if (ref $arg) {
        if ($arg =~ /^(IO::File|FileHandle)/) {
            $fh = $arg;
        } else {
            warn "$arg: " . _("not an IO::File/FileHandle object!\n");
            return '';
        }
    } else {
        $fh = fopen($arg) || return 0; # in case file is removed after find_file
	                               # 2.0.7 had problem
    }
    my $size = -s $fh;
    unless (ref $arg) {
        fclose($fh);
    }
    return $size;
}

# checklib ... check existence of library file
sub checklib ($) {
    my $libfile = shift;
    for my $path (@INC) {
        my $cpath = "$path/$libfile";
        return 1 if -e $cpath;
    }
    return 0;
}

# checkcmd ... check command path
sub checkcmd ($) {
    my $cmd = shift;
    my $pd = ':';
    $pd = ';' if (($English::OSNAME eq "MSWin32") || ($English::OSNAME eq "os2"));

    for my $dir (split(/$pd/, $ENV{'PATH'})) {
        next if ($dir eq '');
        win32_yen_to_slash(\$dir);
        return "$dir/$cmd" if (-x "$dir/$cmd" && ! -d "$dir/$cmd");
        return "$dir/$cmd.com" if (-x "$dir/$cmd.com" &&
            (($English::OSNAME eq "MSWin32") || ($English::OSNAME eq "os2")));
        return "$dir/$cmd.exe" if (-x "$dir/$cmd.exe" &&
            (($English::OSNAME eq "MSWin32") || ($English::OSNAME eq "os2")));
        return "$dir/$cmd.bat" if (-x "$dir/$cmd.bat" &&
            ($English::OSNAME eq "MSWin32"));
        return "$dir/$cmd.cmd" if (-x "$dir/$cmd.cmd" &&
            ($English::OSNAME eq "os2"));
    }
    return undef;
}

# tmpnam ... make temporary file name
sub tmpnam ($) {
    my ($base) = @_;
    cdie("util::tmpnam: Set \$var::OUTPUT_DIR first!\n")
	if $var::OUTPUT_DIR eq "";
    my $tmpnam = "$var::OUTPUT_DIR/$base.tmp";
    dprint("tmpnam: $tmpnam\n");
    return $tmpnam;
}

# cdie ... clean files before die
sub cdie (@) {
    my (@msgs)  = @_;

    remove_tmpfiles();
    print STDERR "mknmz: ", @msgs;
    print STDERR "\n" unless $msgs[$#msgs] =~ /\n$/;
    exit 2;
}

# remove_tmpfiles ... remove temporary files which mknmz would make
sub remove_tmpfiles () {
    return unless defined $var::OUTPUT_DIR;

    my @list = glob "$var::OUTPUT_DIR/NMZ.*.tmp";
    push @list, $var::NMZ{'err'}   if -z $var::NMZ{'err'}; # if size == 0
    push @list, $var::NMZ{'lock'}  if -f $var::NMZ{'lock'};
    push @list, $var::NMZ{'lock2'} if -f $var::NMZ{'lock2'};
    dprint(_("Remove temporary files:"), @list);
    unlink @list;
}

sub set_lang () {
    for my $cand (("LANGUAGE", "LC_ALL", "LC_MESSAGES", "LANG")) {
	if (defined($ENV{$cand})) {
	    $util::LANG_MSG = $ENV{$cand};
	    last;
	}
    }
    for my $cand (("LC_ALL", "LC_CTYPE", "LANG")) {
	if (defined($ENV{$cand})) {
	    $util::LANG = $ENV{$cand};
	    last;
	}
    }
    # print "LANG: $util::LANG\n";
}

sub islang_msg($) {
    my ($lang) = @_;

    if ($util::LANG_MSG =~ /^$lang/i) {  # prefix matching
	return 1;
    } else {
	return 0;
    }
}

sub islang($) {
    my ($lang) = @_;

    if ($util::LANG =~ /^$lang/i) {  # prefix matching
	return 1;
    } else {
	return 0;
    }
}

sub assert($$) {
    my ($bool, $msg) = @_;

    if (!$bool) {
	die _("ASSERTION ERROR!: ")."$msg";
    }
}

# Since it is an old subroutine, it is prohibition of use.
# It exists only for back compatibility.
sub systemcmd {
    if ($English::OSNAME eq "MSWin32" || $English::OSNAME eq "os2") {
	my @args = ();
	foreach my $tmp (@_) {
	    $tmp =~ s!/!\\!g;
	    push @args, $tmp;
	}
	system(@args);
    } else {
	system(@_);
    }
}

sub syscmd(%)
{
    my $status = undef;
    my %arg = @_;
    my @args = @{$arg{command}} if (defined $arg{command});
    my %option = %{$arg{option}} if (defined $arg{option});
    my %env = %{$arg{env}} if (defined $arg{env});

    dprint(_("Invoked: ") . join(' ', @args));

    # default option
    $option{stdout} = '/dev/null' unless(defined $option{stdout});
    $option{stderr} = '/dev/null' unless(defined $option{stderr});
    $option{mode_stdout} = 'wt' unless(defined $option{mode_stdout});
    $option{mode_stderr} = 'wt' unless(defined $option{mode_stderr});
    $option{maxsize} = -1 unless(defined $option{maxsize});

    my $handle_out = undef;
    my $handle_err = undef;
    if (ref $option{stdout}) {
        if ($option{stdout} =~ /^(IO::File|FileHandle)/) {
            $handle_out = $option{stdout};
        }
    }
    if (ref $option{stderr}) {
        if ($option{stderr} =~ /^(IO::File|FileHandle)/) {
            $handle_err = $option{stderr};
        }
    }

    my $same = 0;
    if ($option{stdout} eq $option{stderr}) {
        $same = 1;
    }

    my $mode_stdout;
    my $mode_stderr;
    if ($option{mode_stdout} =~ /^w/i) {
        $mode_stdout = '>';
    } elsif ($option{mode_stdout} =~ /^a/i) {
        $mode_stdout = '>>';
    } else {
        warn "unknown mode. : " . quotemeta($option{mode_stdout});
        $mode_stdout = '>>';
    }
    if ($option{mode_stderr} =~ /^w/i) {
        $mode_stderr = '>';
    } elsif ($option{mode_stderr} =~ /^a/i) {
        $mode_stderr = '>>';
    } else {
        warn "unknown mode. : " . quotemeta($option{mode_stderr});
        $mode_stderr = '>>';
    }

    my $text_stdout = undef;
    my $text_stderr = undef;
    if ($option{mode_stdout} =~ /^.t/i) {
        $text_stdout = 1;
    }
    if ($option{mode_stderr} =~ /^.t/i) {
        $text_stderr = 1;
    }

    if ($English::OSNAME eq "MSWin32" || $English::OSNAME eq "os2") {
	foreach my $arg (@args) {
	    $arg =~ s!/!\\!g;
	}
        if ($args[0] =~ m/\.bat$/i) {
            my $conts = util::readfile($args[0]);
            codeconv::normalize_document(\$conts);
            if ($conts =~ m/^\@rem\s=\s'--\*-Perl-\*--/i) {
                @args = ("perl", @args);
            } else {
                my $comspec = "cmd";
                $comspec = $ENV{'COMSPEC'} if (defined $ENV{'COMSPEC'});
                if ($comspec =~ m/command\.com$/i) {
                    $comspec = pltests::checkcmd('win95cmd.exe');
                    unless (defined $comspec) {
                        cdie 'win95cmd.exe not found.';
                    }
                    $ENV{'COMSPEC'} = $comspec;
                }
                @args = ($comspec, "/d", "/x", "/c", @args);
            }
        }
    }

    dprint(_("Invoked: ") . join(' ', @args));

    my $fh_out = undef;
    my $fh_err = undef;

    if (defined $handle_out) {
        $fh_out = $handle_out;
    } else {
        $fh_out= IO::File->new_tmpfile();
    }
    if ($same) {
        $fh_err = $fh_out;
    } else {
        if (defined $handle_err) {
            $fh_err = $handle_err;
        } else {
            $fh_err = IO::File->new_tmpfile();
        }
    }

    {
        my $saveout = new IO::File (">&" . STDOUT->fileno()) or cdie "Can't dup STDOUT: $!";
        my $saveerr = new IO::File (">&" . STDERR->fileno()) or cdie "Can't dup STDERR: $!";
        STDOUT->fdopen($fh_out->fileno(), 'w') or cdie "Can't open fh_out: $!";
        STDERR->fdopen($fh_err->fileno(), 'w') or cdie "Can't open fh_out: $!";

        # backup $ENV{}
        my %backup;
        my ($key, $value);
        while(($key, $value) = each %env) {
            $backup{$key} = $ENV{$key};
            if (defined $value) {
                $ENV{$key} = $value;
            } else {
                delete $ENV{$key};
            }
        }

        # Use an indirect object: see Perl Cookbook Recipe 16.2 in detail.
        $status = system { $args[0] } @args;

        # restore $ENV{}
        while(($key, $value) = each %env) {
            if (defined $backup{$key}) {
                $ENV{$key} = $backup{$key};
            } else {
                delete $ENV{$key};
            }
        }

        STDOUT->fdopen($saveout->fileno(), 'w') or cdie "Can't restore saveout: $!";
        STDERR->fdopen($saveerr->fileno(), 'w') or cdie "Can't restore saveerr: $!";
    }

    # Note that the file position of filehandles must be rewinded.
    $fh_out->seek(0, SEEK_SET) or cdie "seek: $!";
    $fh_err->seek(0, SEEK_SET) or cdie "seek: $!";

    if (!defined $handle_out) {
        if (ref($option{stdout}) ne 'SCALAR') {
            if ($option{stdout} eq '/dev/null') {
                $fh_out->close();
            } else {
                my $conts_out = "";
                my $size = -s $fh_out;
                read $fh_out, $conts_out, $size;
                $fh_out->close();
                codeconv::normalize_nl(\$conts_out) if (defined $text_stdout);

                my $file = $option{stdout};
                if ($English::OSNAME eq "MSWin32" || $English::OSNAME eq "os2") {
                    $file =~ s!/!\\!g;
                }
                if (!open(OUT, "$mode_stdout$file")) {
                    warn "Can not open file. : $file";
                    return (1);
                }
                print OUT $conts_out;
                close(OUT);
            }
        } else {
            my $conts_out = $option{stdout};
            my $size = -s $fh_out;
            read $fh_out, $$conts_out, $size;
            $fh_out->close();
            codeconv::normalize_nl($conts_out) if (defined $text_stdout);
        }
    }

    if (!(defined $handle_err || $same)) {
        if (ref($option{stderr}) ne 'SCALAR') {
            if ($option{stderr} eq '/dev/null') {
                $fh_err->close();
            } else {
                my $conts_err = "";
                my $size = -s $fh_err;
                read $fh_err, $conts_err, $size;
                $fh_err->close();
                codeconv::normalize_nl(\$conts_err) if (defined $text_stderr);

                my $file = $option{stderr};
                if ($English::OSNAME eq "MSWin32" || $English::OSNAME eq "os2") {
                    $file =~ s!/!\\!g;
                }
                if (!open(OUT, "$mode_stderr$file")) {
                    warn "Can not open file. : $file";
                    return (1);
                }
                print OUT $conts_err;
                close(OUT);
            }
        } else {
            my $conts_err = $option{stderr};
            my $size = -s $fh_err;
            read $fh_err, $$conts_err, $size;
            $fh_err->close();
            codeconv::normalize_nl($conts_err) if (defined $text_stderr);
        }
    }

    return ($status);
}

# Returns a string representation of the null device.
# We can use File::Spec->devnull() on Perl-5.6, instead.
sub devnull {
    if ($English::OSNAME eq "MSWin32") {
	return "nul";
    } elsif ($English::OSNAME eq "os2") {
	return "/dev/nul";
    } elsif ($English::OSNAME eq "MacOS") {
	return "Dev:Null";
    } elsif ($English::OSNAME eq "VMS") {
	return "_NLA0:";
    } else { # Unix
	return "/dev/null";
    }
}

# convert \ to / with consideration for Shift_JIS Kanji code
sub win32_yen_to_slash ($) {
    my ($filenameref) = @_;
    if (($English::OSNAME eq "MSWin32") || ($English::OSNAME eq "os2")) {
        $$filenameref =~
                s!([\x81-\x9f\xe0-\xef][\x40-\x7e\x80-\xfc]|[\x01-\x7f])!
                $1 eq "\\" ? "/" : $1!gex;
    }
}

# Substitution of "-r" that doesn't correspond to ACL of NTFS
sub canopen($)
{
    my ($file) = @_;

    my $fh;

    return (-r $file) if ($English::OSNAME ne "MSWin32");

    $fh = new IO::File $file, "r";

    return 0 if (!defined $fh);

    $fh->close();

    return 1;
}

1;
