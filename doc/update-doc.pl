#! /usr/bin/perl -w
use strict;
use FileHandle;
#use NKF;

# 
# Get a list of directory names. 
# NOTE: the directory name corresponds to its language codes.
#
my @langs = grep { -d $_ && $_ ne "CVS" } glob '*';

#my @langs = qw(ja);

for my $lang (@langs) {
    #
    # Read manual.html
    #
    my $manfname = "$lang/manual.html";
    my $mancont  = readfile($manfname);

    #
    # Save backup file.
    #
    writefile("$manfname.bak", $mancont);

    #
    # Import query description from ../template/NMZ.body.
    #
    my $templfname = "../template/NMZ.body";
    $templfname = "$templfname.$lang" if -s "$templfname.$lang";
    my $query_desc = readfile($templfname);
#    $query_desc = nkf("-j", $query_desc) if $lang eq "ja";
    
    $mancont =~ s{(<!-- query -->).*(<!-- query -->)}
               {$1\n$query_desc$2}s;

    #
    # Import command line option from namazu --help and mknmz --help
    #
    my $language = "C";
    if ($lang eq "ja") {
        $language = "ja_JP.eucJP";
    }
    system("LANG=$language namazu --help > tmp1");
    system("LANG=$language mknmz  --help > tmp2");
    my $namazu_help = readfile("tmp1");
    my $mknmz_help  = readfile("tmp2");
    $namazu_help = encode($namazu_help);
    $mknmz_help  = encode($mknmz_help);
#    $namazu_help = nkf("-j", $namazu_help) if $lang eq "ja";
#    $mknmz_help  = nkf("-j", $mknmz_help) if $lang eq "ja";
    unlink "tmp1", "tmp2";

    # Indent
    $namazu_help =~ s/^/    /mg;
    $mknmz_help  =~ s/^/    /mg;

    $mancont =~ s{(<!-- namazu-option -->).*(<!-- namazu-option -->)}
               {$1\n<pre>\n$namazu_help</pre>\n$2}s;
    $mancont =~ s{(<!-- mknmz-option -->).*(<!-- mknmz-option -->)}
               {$1\n<pre>\n$mknmz_help</pre>\n$2}s;

    writefile("$manfname", $mancont);
}

sub readfile {
    my ($fname) = @_;

    my $fh = new FileHandle;
    $fh->open("$fname") || die "$fname: $!";
    binmode($fh);

    my $cont = "";
    my $size = -s $fh;
    read $fh, $cont, $size;

    $fh->close();

    return $cont;
}

sub writefile {
    my ($fname, $cont) = @_;

    my $fh = new FileHandle;
    $fh->open(">$fname") || die "$fname: $!";
    binmode($fh);

    print $fh $cont;

    $fh->close();
}

sub encode {
    my ($cont) = @_;

    $cont =~ s/&/&amp;/g;
    $cont =~ s/</&lt;/g;
    $cont =~ s/>/&gt;/g;
    
    return $cont;
}
