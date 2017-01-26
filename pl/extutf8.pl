#
# -*- Perl -*-
# $Id: extutf8.pl,v 1.1.4.5 2008-07-26 06:14:37 opengl2772 Exp $
# Copyright (C) 2008 Tadamasa Teranishi All rights reserved.
# Copyright (C) 2008 Namazu Project All rights reserved.
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

package extutf8;
use strict;
use English;
require 'util.pl';
eval 'require NKF;';


use vars qw($utf8_to_eucjp $codeconv_document);

$utf8_to_eucjp = undef;
$codeconv_document = undef;

my $_converter = '';
my $_utfconvpath = undef;
my $_nkfversion = 0.00;

sub setup()
{
    return 'yes' if (defined $codeconv_document);

    if (!util::islang("ja")) {
        $utf8_to_eucjp = \&_utf8_to_usascii;
        $codeconv_document = \&_codeconv_document_usascii;
        $_converter = 'to_usascii';
        return 'yes';
    }

    eval '$_nkfversion = $NKF::VERSION;';
    $_nkfversion = 0.00 if (!defined $_nkfversion);
    if ($_nkfversion >= 2.04) {
        $utf8_to_eucjp = \&_nkf_utf8_to_eucjp;
        $codeconv_document = \&_nkf_codeconv_document;
        $_converter = 'module_nkf';
        return 'yes';
    }

    if ($English::PERL_VERSION >= 5.008) {
        eval 'use Encode qw/from_to Unicode JP/;';
        $utf8_to_eucjp = \&_encode_utf8_to_eucjp;
        $codeconv_document = \&_encode_codeconv_document;
        $_converter = 'module_encode';
        return 'yes';
    }

    $_utfconvpath = util::checkcmd('lv');
    if (defined $_utfconvpath) {
        $utf8_to_eucjp = \&_lv_utf8_to_eucjp;
        $codeconv_document = \&_lv_codeconv_document;
        $_converter = 'lv';
        return 'yes';
    }

    if (defined util::checklib('unicode.pl')) {
        eval require 'unicode.pl';
        $utf8_to_eucjp = \&_unicode_utf8_to_eucjp;
        $codeconv_document = \&_unicode_codeconv_document;
        $_converter = 'unicode.pl';
        return 'yes';
    }

    return 'no';
}

sub converter()
{
    return $_converter;
}

#
# 
#
sub _utf8_to_usascii($)
{
    my ($contref) = @_;

    codeconv::tousascii($contref);

    return $$contref;
}

sub _codeconv_document_usascii($)
{
    my ($contref) = @_;

    _utf8_to_usascii($contref);
    codeconv::normalize_document($contref);

    return $$contref;
}

#
# Conversion by "Encode"
#   Perl 5.8 or later
#
sub _encode_utf8_to_eucjp($)
{
    my ($contref) = @_;

    Encode::from_to($$contref, "utf-8", "euc-jp");

    return $$contref;
}

sub _encode_codeconv_document($)
{
    my ($contref) = @_;

    Encode::from_to($$contref, "utf-8", "euc-jp");
    codeconv::normalize_eucjp_document($contref);

    return $$contref;
}

#
# Conversion by "NKF Perl module"
#   version 2.04 or later
#
sub _nkf_utf8_to_eucjp($)
{
    my ($contref) = @_;

    $$contref = NKF::nkf("-Wex", $$contref);

    return $$contref;
}

sub _nkf_codeconv_document($)
{
    my ($contref) = @_;

    $$contref = NKF::nkf("-WemXZ1", $$contref);
    codeconv::normalize_document($contref);

    return $$contref;
}

#
# [obsolute] Conversion by "lv"
#   It is slow.
#
sub _lv_utf8_to_eucjp($)
{
    my ($contref) = @_;

    my $tmpfile  = util::tmpnam('NMZ.tmp.utf8');
    {
        my $fh = util::efopen("> $tmpfile");
        print $fh $$contref;
        util::fclose($fh);
    }

    $$contref = "";
    my @cmd = ($_utfconvpath, "-Iu8", "-Oej", $tmpfile);
    my $status = util::syscmd(
        command => \@cmd,
        option => {
            "stdout" => $contref,
            "stderr" => "/dev/null",
        },
    );

    unlink $tmpfile;

    return $$contref;
}

sub _lv_codeconv_document($)
{
    my ($contref) = @_;

    _lv_utf8_to_eucjp($contref);
    codeconv::normalize_eucjp_document($contref);

    return $$contref;
}

#
# [obsolute] Conversion by "unicode.pl"
#
sub _unicode_utf8_to_eucjp($)
{
    my ($contref) = @_;

    my @unicodeList = unicode::UTF8toUTF16($$contref);
    $$contref = unicode::u2e(@unicodeList);
    $$contref =~ s/\00//g;

    return $$contref;
}

sub _unicode_codeconv_document($)
{
    my ($contref) = @_;

    _unicode_utf8_to_eucjp($contref);
    codeconv::normalize_eucjp_document($contref);

    return $$contref;
}

1;
