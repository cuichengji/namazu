#!/usr/bin/perl -w
#
# -*- Perl -*-
#
# $Id: nmzchkw.pl,v 1.1.4.1 2006-09-19 15:12:11 opengl2772 Exp $
#
# nmzchkw.pl - by Tadamasa Teranishi.
#

use strict;

sub nmzchkw($);
sub hr();
sub result($$$);

if (@ARGV){
    for my $argv (@ARGV){
        $argv =~ s/NMZ$// unless -d $argv;
        $argv = '.' if $argv eq '';
        &nmzchkw($argv);
    }
} else {
    &nmzchkw('.');
}

exit(0);

sub nmzchkw($)
{
    my ($dir) = @_;

    if (! -f "$dir/NMZ.wi") {
        print "Cannot open index. : $dir\n";
        return;
    }

    my $line;
    my $n = 0;
    my @data;
    my $pass = 0;
    my $err = 0;
    my $e = 0;

    open(NMZ_w, "$dir/NMZ.w") || die "Can not open file. : NMZ.w\n";
    while($line = <NMZ_w>) {
        push @data, $line;
        $n++;
    }
    close(NMZ_w);

    my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
        $atime,$mtime,$ctime,$blksize,$blocks) = stat("$dir/NMZ.wi");

    hr();
    printf "check 1\n";
    hr();

    my @nul = grep {/\x00/} @data;
    printf "nul           : %d\n", $#nul + 1;

    my @ctrl = grep {/[\x01-\x09\x0b-\x0c\x0e-\x1f\x7f]/} @data;
    printf "control       : %d\n", $#ctrl + 1;

    my @cr = grep {/\x0d]/} @data;
    printf "cr            : %d\n", $#cr + 1;

    my @msb = grep {/[\x80-\xff]/} @data;
    printf "0x80 - 0xff   : %d\n", $#msb + 1;


    result($#nul + 1 == 0, \$pass, \$err);

    hr();
    printf "check 2\n";
    hr();

    my @lf = grep {/\n/} @data;
    printf "lf            : %d\n", $#lf + 1;

    printf "NMZ.w:  words : %d\n", $n;
    printf "NMZ.wi: words : %d\n", $size / 4;

    $e = 0;
    $e = 1 if ($n != $#lf + 1);
    $e = 1 if ($n != $size / 4);
    result($e == 0, \$pass, \$err);

    hr();
    printf "check 3\n";
    hr();

    my $l;
    $e = 0;

    open(NMZ_wi, "$dir/NMZ.wi") || die "Can not open file. : NMZ.wi\n";
    open(NMZ_w, "$dir/NMZ.w") || die "Can not open file. : NMZ.w\n";
    $l = 0;
    $n = 0;
    while($line = <NMZ_w>) {
        my $data;
        read NMZ_wi, $data, 4;
        my $sz = unpack('N', $data);
        if ($l != $sz) {
            print "$n: $l $sz\n";
            $e = 1;
        }
        $l += length($line);
        $n++;
    }
    close(NMZ_w);
    close(NMZ_wi);

    result($e == 0, \$pass, \$err);

    hr();
    if ($err == 0) {
        printf "All check passed.\n";
    } else {
        printf "$err check failed.\n";
    }
}

sub hr()
{
    print "=" x 30 . "\n";
}

sub result($$$)
{
    my ($check, $pass, $err) = @_;

    if ($check) {
        $$pass++;
        printf "ok\n";
    } else {
        $$err++;
        printf "fail \!\!\n";
    }
}
