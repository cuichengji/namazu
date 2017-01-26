#
# -*- Perl -*-
# $Id: wakati.pl,v 1.9.8.10 2009-01-28 17:54:57 opengl2772 Exp $
# Copyright (C) 1997-1999 Satoru Takabayashi All rights reserved.
# Copyright (C) 2000-2009 Namazu Project All rights reserved.
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

package wakati;
use strict;

# Do wakatigaki processing for a Japanese text.
sub wakatize_japanese ($) {
    my ($content) = @_;

    my @tmp = wakatize_japanese_sub($content);

    # Remove words consists of only Hiragana characters
    # when -H option is specified.
    # Original of this code was contributed by <furukawa@tcp-ip.or.jp>.
    # [1997-11-13]
    # And do Okurigana processing. [1998-04-24]
    if ($var::Opt{'hiragana'} || $var::Opt{'okurigana'}) {
        for (my $ndx = 0; $ndx <= $#tmp; ++$ndx) {
	    $tmp[$ndx] =~ s/(\s)/ $1/g;
	    $tmp[$ndx] = ' ' . $tmp[$ndx];
	    if ($var::Opt{'okurigana'}) {
		$tmp[$ndx] =~ s/((?:[^\xa4][\xa1-\xfe])+)(?:\xa4[\xa1-\xf3])+ /$1 /g;
	    }
	    if ($var::Opt{'hiragana'}) {
		$tmp[$ndx] =~ s/ (?:\xa4[\xa1-\xf3])+ //g;
	    }
        }
    }

    # Collect only noun words when -m option is specified.
    if ($var::Opt{'noun'}) {
	$$content = "";
	$$content .= shift(@tmp) =~ /(.+ )\xcc\xbe\xbb\xec/ ? $1 : "" while @tmp;
	# noun (meisi) in Japanese "cc be bb ec"
    } else {
	$$content = join("\n", @tmp);
    }
    $$content =~ s/^\s+//gm;
    $$content =~ s/\s+$//gm;
    $$content =~ s/ +/ /gm;
    $$content .= "\n";
    util::dprint(_("-- wakatized content --\n")."$$content\n");
}

sub wakatize_japanese_sub ($) {
    my ($content) = @_;
    my $str = "";
    my @tmp = ();

    if ($conf::WAKATI =~ /^module_(\w+)/) {
	my $module = $1;
	if ($module eq "kakasi") {
	    $str = $$content;
	    $str =~ s/([\x80-\xff]+)/{my $text = Text::Kakasi::do_kakasi($1); " $text ";}/ge;
	} elsif ($module eq "chasen") {
            if ($var::Opt{'noun'}) {
	        $str = Text::ChaSen::sparse_tostr_long($$content);
            } else {
                $str = $$content;
	        $str =~ s/([\x80-\xff]+)/{my $text = Text::ChaSen::sparse_tostr_long($1); " $text ";}/ge;
            }
	} elsif ($module eq "mecab") {
	    use vars qw($t);
	    if (!defined $t) {
		require MeCab;
		import MeCab;
                eval '$t = new MeCab::Tagger("-Owakati");' or
                    $t = new MeCab::Tagger([qw(mecab -O wakati)]);
	    }
	    END {
		$t->DESTROY() if defined $t;
	    };
            $str = $$content;
            $str =~ s/([\x80-\xff]+)/{my $s = $1; my $text = $t->parse($s); " $text ";}/ge;
	} else {
	    util::cdie(_("invalid wakati module: ")."$module\n");
	}
        util::dprint(_("-- wakatized bare content --\n")."$str\n\n");
	@tmp = split('\n', $str);
    } else {
	my $tmpfile = util::tmpnam("NMZ.wakati");
        util::dprint(_("wakati: using ")."$conf::WAKATI\n");
	# Don't use IPC::Open2 because it's not efficent.
        if ($var::Opt{'noun'}) {
            my $fh_wakati = util::efopen("|$conf::WAKATI > $tmpfile");
            print $fh_wakati $$content;
            util::fclose($fh_wakati);
        } else {
            $str = $$content;

            my $redirect = ">";
            while(1) {
                if ($str =~ s/^([\x80-\xff]+)//s) {
                    my $fh_wakati = util::efopen("|$conf::WAKATI $redirect $tmpfile");
                    print $fh_wakati " $1\n";
                    util::fclose($fh_wakati);
                } elsif ($str =~ s/^([\x00-\x7f]+)//s) {
                    my $fh_wakati = util::efopen("$redirect $tmpfile");
                    print $fh_wakati " $1 ";
                    util::fclose($fh_wakati);
                } else {
                    last;
                }

                $redirect = ">>";
            }
	}
	{
	    my $fh_wakati = util::efopen($tmpfile);
	    @tmp = <$fh_wakati>;
	    chomp @tmp;
            util::fclose($fh_wakati);
	}
	unlink $tmpfile;
    }

    return @tmp;
}

1;
