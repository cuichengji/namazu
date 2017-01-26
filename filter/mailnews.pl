#
# -*- Perl -*-
# $Id: mailnews.pl,v 1.27.4.16 2008-05-09 08:37:44 opengl2772 Exp $
# Copyright (C) 1997-2000 Satoru Takabayashi ,
#               1999 NOKUBI Takatsugu ,
#               2001,2003-2008 Namazu Project All rights reserved.
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

package mailnews;
use strict;
require 'util.pl';
require 'gfilter.pl';
require 'html.pl';

my $has_base64 = undef;
my $htmlmail = "";

sub mediatype() {
    return ('message/rfc822', 'message/news');
}

sub status() {
    $has_base64 = 1 if (util::checklib('MIME/Base64.pm') &&
			util::checklib('MIME/QuotedPrint.pm'));
    return 'yes';
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
    return;
}

sub filter ($$$$$) {
    my ($orig_cfile, $cont, $weighted_str, $headings, $fields)
      = @_;
    my $cfile = defined $orig_cfile ? $$orig_cfile : '';

    util::vprint("Processing mail/news file ...\n");

    uuencode_filter($cont);
    mailnews_filter($cont, $weighted_str, $fields);
    if ($htmlmail) {
        html::html_filter($cont, $weighted_str, $fields, $headings);
    }
    mailnews_citation_filter($cont, $weighted_str);

    gfilter::line_adjust_filter($cont);
    gfilter::line_adjust_filter($weighted_str);
    gfilter::white_space_adjust_filter($cont);
    gfilter::white_space_adjust_filter($weighted_str);
    gfilter::show_filter_debug_info($cont, $weighted_str,
			   $fields, $headings);
    return undef;
}

# Original of this code was contributed by <furukawa@tcp-ip.or.jp>.
sub mailnews_filter ($$$) {
    my ($contref, $weighted_str, $fields) = @_;

    my $boundary = "";
    my $line     = "";
    my $partial  = 0;
    my $cont_encode = "";
    my $textplain = "";

    $htmlmail = "";

    $$contref =~ s/^\s+//;
    # Don't handle if first like does'nt seem like a mail/news header.
    return unless $$contref =~ /(^\S+:|^from )/i;

    my @tmp = split(/\n/, $$contref);
  HEADER_PROCESSING:
    while (@tmp) {
	$line = shift @tmp;
	last if ($line =~ /^$/);  # if an empty line, header is over
	# Connect the two lines if next line has leading spaces
	while (defined($tmp[0]) && $tmp[0] =~ /^\s+/) {
	    # if connection is Japanese character, remove spaces
	    # from Furukawa-san's idea [1998-09-22]
	    my $nextline = shift @tmp;
	    $line =~ s/([\xa1-\xfe])\s+$/$1/;
	    $nextline =~ s/^\s+([\xa1-\xfe])/$1/;
	    $line .= $nextline;
	}

	# Handle fields.
	if ($line =~ s/^subject:\s*//i) {
	    $fields->{'title'} = $line;
	    # Skip [foobar-ML:000] for a typical mailing list subject.
	    # Practically skip first [...] for simple implementation.
	    $line =~ s/^\[.*?\]\s*//;

	    # Skip 'Re:'
	    $line =~ s/\bre:\s*//gi;

	    my $weight = $conf::Weight{'html'}->{'title'};
	    $$weighted_str .= "\x7f$weight\x7f$line\x7f/$weight\x7f\n";
        } elsif ($line =~ s/^content-type:\s*//i) {
            if ($line =~ /multipart.*boundary="(.*?)"/si ||
            $line =~ /multipart.*boundary=(.*?)(?:\s|$)/mi) {
                $boundary = $1;
                util::dprint("((boundary: $boundary))\n");
            } elsif ($line =~ m!message/partial;\s*(.*)!i) {
                # The Message/Partial subtype routine [1998-10-12]
                # contributed by Hiroshi Kato <tumibito@mm.rd.nttdata.co.jp>
                $partial = $1;
                util::dprint("((partial: $partial))\n");
            } elsif ($line =~ m!text/html!i) {
                # The simplest form of an HTML email message.
                util::dprint("text/html mail\n");
                $htmlmail = 'yes';
            } elsif ($line =~ m!text/plain!i) {
                $textplain = 'yes';
            } elsif ($line !~ m!text/plain!i) {
                $$contref = '';
                return;
            }
        } elsif ($line =~ s/^content-transfer-encoding:\s*(\S+)$//i) {
            $cont_encode = lc($1);
	} elsif ($line =~ /^(\S+):\s*(.*)/i) {
	    my $name = $1;
	    my $value = $2;
	    $fields->{lc($name)} = $value;
	    if ($name =~ /^($conf::REMAIN_HEADER)$/io) {
		# keep some fields specified REMAIN_HEADER for search keyword
		my $weight = $conf::Weight{'headers'};
		$$weighted_str .=
		    "\x7f$weight\x7f$value\x7f/$weight\x7f\n";
	    }
	}
    }
    if ($partial) {
	# MHonARC makes several empty lines between header and body,
	# so remove them.
	while(@tmp) {
	    last if (! $line =~ /^\s*$/);
	    $line = shift @tmp;
	}
	undef $partial;
	goto HEADER_PROCESSING;
    }
    $$contref = join("\n", @tmp);

    # Handle MIME multipart message.
    if ($boundary) {
	$boundary =~ s/(\W)/\\$1/g;
	$$contref =~ s/This is multipart message.\n//i;

	multipart_process($contref, $boundary, $weighted_str, $fields);

    } elsif ($textplain && $cont_encode =~ m/base64/) {
        base64_filter($contref);
        codeconv::codeconv_document($contref);
    } elsif ($textplain && $cont_encode =~ m/quoted-printable/) {
        quotedprint_filter($contref);
        codeconv::codeconv_document($contref);
    }
}

# Prototype declaration for avoiding
# "multipart_process() called too early to check prototype at ..." warnings.
sub multipart_process($$$$);

sub multipart_process ($$$$) {
    my ($contref, $boundary, $weighted_str, $fields) = @_;

    # MIME multipart processing,
    # modified by Furukawa-san's patch on [1998/08/27]
    $$contref =~ s/--$boundary(?:--)?\n?/\xff/g;
    $$contref =~ s/\xff[^\xff]*$//s;
    my (@parts) = split(/\xff/, $$contref);
    $$contref = '';
    for $_ (@parts) {
	if (s/^(.*?\n\n)//s) {
	    my ($head) = $1;
	    my ($body) .= $_;
	    my $contenttype = "";
	    my $cont_encode = "";
	    if ($head =~ m!^content-type:\s*(\S+?);?\s!mi) {
		$contenttype = lc($1);
		util::dprint("((Content-Type: $contenttype))\n");
	    }

	    if ($head =~ m!^content-transfer-encoding:\s*(\S+)$!mi) {
		$cont_encode = lc($1);
		util::dprint("((Content-Transfer-Encode: $cont_encode))\n");
	    }

	    # Image data must not be including text data.
	    if ($contenttype !~ m!image/!) {
		if ($cont_encode =~ m/base64/) {
		    base64_filter(\$body);
		} elsif ($cont_encode =~ m/quoted-printable/) {
		    quotedprint_filter(\$body);
		}

		if ($contenttype =~ m!text/plain!) {
                    codeconv::codeconv_document(\$body);
		    $$contref .= $body;
		} elsif ($contenttype =~ m!multipart/alternative!) {
                    if ($head =~ /boundary="(.*?)"/si ||
                    $head =~ /boundary=(.*?)(?:\s|$)/mi) {
			my $boundary2 = $1;
			util::dprint("((boundary: $boundary2))\n");
			$boundary2 =~ s/(\W)/\\$1/g;
			multipart_process(\$body, $boundary2, $weighted_str, $fields);
			$$contref .= $body;
		    }
		} elsif ($body ne "") {
		    nesting_filter(\$head, \$body, $contenttype, $weighted_str);
		    $$contref .= $body;
		}
	    }
	}
        $$contref .= " ";
    }
}


# Make mail/news citation marks not to be indexed.
# And a greeting message at the beginning.
# And a meaningless message such as "foo wrote:".
# Thanks to Akira Yamada for great idea.
sub mailnews_citation_filter ($$) {
    my ($contref, $weighted_str) = @_;

    my $omake = "";
    $$contref =~ s/^\s+//;
    my @tmp = split(/\n/, $$contref);
    $$contref = "";

    # Greeting at the beginning (first one or two lines)
    for (my $i = 0; $i < 2 && defined($tmp[$i]); $i++) {
	if ($tmp[$i] =~ /(^\s*((([\xa1-\xfe][\xa1-\xfe]){1,8}|([\x21-\x7e]{1,16}))\s*(。|．|\.|，|,|、|\@|＠|の)\s*){0,2}\s*(([\xa1-\xfe][\xa1-\xfe]){1,8}|([\x21-\x7e]{1,16}))\s*(です|と申します|ともうします|といいます)(.{0,2})?\s*$)/) {
	    # for searching debug info by perl -n00e 'print if /^<<<</'
	    util::dprint("\n\n<<<<$tmp[$i]>>>>\n\n");
	    $omake .= $tmp[$i] . "\n";
	    $tmp[$i] = "";
        }
    }

    # Isolate citation parts.
    for my $line (@tmp) {
	# Don't do that if there is an HTML tag at first.
	if ($line !~ /^[^>]*</ &&
	    $line =~ s/^((\S{1,10}>)|(\s*[\>\|\:\#]+\s*))+//) {
	    $omake .= $line . "\n";
	    $$contref .= "\n";  # Insert LF.
	    next;
	}
	$$contref .= $line. "\n";
    }
	
    # Process text as chunks of paragraphs.
    # Isolate meaningless message such as "foo wrote:".
    @tmp = split(/\n\n+/, $$contref);
    $$contref = "";
    my $i = 0;
    for my $line (@tmp) {
	# Complete excluding is impossible. I tnink it's good enough.
        # Process only first five paragrahs.
	# And don't handle the paragrah which has five or longer lines.
	# Hmm, this regex looks very hairly.
	if ($i < 5 && ($line =~ tr/\n/\n/) <= 5 && $line =~ /(^\s*(Date:|Subject:|Message-ID:|From:|件名|差出人|日時))|(^.+(返事です|reply\s*です|曰く|いわく|書きました|言いました|話で|wrote|said|writes|says)(.{0,2})?\s*$)|(^.*In .*(article|message))|<\S+\@[\w\-\.]+?\.\w+>/im) {
	    util::dprint("\n\n<<<<$line>>>>\n\n");
	    $omake .= $line . "\n";
	    $line = "";
	    next;
	}
	$$contref .= $line. "\n\n";
        $i++;
    }
    $$weighted_str .= "\x7f1\x7f$omake\x7f/1\x7f\n";
}

# Skip uuencode and BinHex texts.
# Original of this code was contributed by <furukawa@tcp-ip.or.jp>.
sub uuencode_filter ($) {
    my ($content) = @_;
    my @tmp = split(/\n/, $$content);
    $$content = "";

    my $uuin = 0;
    while (@tmp) {
	my $line = shift @tmp;
	$line .= "\n";

	# Skip BinHex texts.
	# All lines will be skipped.
	last if $line =~ /^\(This file must be converted with BinHex/; #)

	# Skip uuencode texts.
	# References : SunOS 4.1.4: man 5 uuencode
	#              FreeBSD 2.2: uuencode.c
	# For avoiding accidental matching, check a format.
	#
	# There are many netnews messages which is separated into several
	# files. This kind of files has usually no "begin" line.
	# This function handle them as well.
	#
	# There are two fashion for line length 62 and 63.
	# This function handle both.
	#
	# In the case of following the specification strictly,
	# int((ord($line) - ord(' ') + 2) / 3)
	#     != (length($line) - 2) / 4
	# but it can be transformed into a simple equation.
	# 4 * int(ord($line) / 3) != length($line) + $uunumb;

        # Hey, SunOS's uuencode use SPACE for encoding.
        # But allowing SPACE is dangerous for misrecognizing.
	# For compromise, only the following case are acceptable.
        #   1. inside of begin - end
        #   2. previous line is recognized as uuencoded line
	#      and ord is identical with previous one.
	
	# a line consists of only characters of 0x20-0x60 is recognized
	# as uuencoded line. v1.1.2.3 (bug fix)

        $uuin = 1, next if $line =~ /^begin [0-7]{3,4} \S+$/;
        if ($line =~ /^end$/) {
            $uuin = 0,next if $uuin;
        } else {
            # Restrict ord value in range of 32-95.
	    my $uuord = ord($line);
	    $uuord = 32 if $uuord == 96;

            # if the line of uunumb = 38 is over this loop,
	    # a normal line of 63 length can be ruined accidentaly.
            my $uunumb = (length($line)==63)? 37: 38;

            if ((32 <= $uuord && $uuord < 96) &&
                length($line) <= 63 &&
                (4 * int($uuord / 3) == length($line) + $uunumb)) {

                if ($uuin == 1 || $uuin == $uuord) {
                    next if $line =~ /^[\x20-\x60]+$/;
                } else {
		    # Be strict for files which doesn't begin with "begin".
                    $uuin = $uuord, next if $line =~ /^M[\x21-\x60]+$/;
                }
            }
        }
        $uuin = 0;
        $$content .= $line;
    }
}

sub base64_filter ($) {
    my ($bodyref) = @_;
    if ($has_base64 && $var::Opt{'decodebase64'}) {
	eval 'use MIME::Base64 ();';
	$$bodyref = MIME::Base64::decode($$bodyref);
    } else {
	$$bodyref = "";
    }
}

sub quotedprint_filter ($) {
    my ($bodyref) = @_;
    if ($has_base64 && $var::Opt{'decodebase64'}) {
	eval 'use MIME::QuotedPrint ();';
	$$bodyref = MIME::QuotedPrint::decode_qp($$bodyref);
    } else {
	$$bodyref = "";
    }
}

sub nesting_filter ($$$$) {
    my ($headref, $bodyref, $mmtype, $weighted_str) = @_;
    my $err = undef;
    my $dummy_shelterfname = "";
    my $headings = "";
    my %fields;
    my $filename = "";
    if ($$headref =~ m!^content-disposition:\s*\S+\s*filename="(.+?)"!smi) {
	$filename = $1;

	#AL-Mail divides filename into some lines when MIME B encoding.
	$filename =~ s/\s+//g;

    } elsif ($$headref =~ m!^content-location:\s*(\S+)!mi) {
	$filename = $1;

    } elsif ($$headref =~ m!^content-disposition:\s*\S+\s*(filename\*.+?[^;])$!smi) {
	#RFC2231 MIME encoded
	$filename =$1;
	$filename =~ s/;.+?=//smg;
	(my $charset, my $lang, my $tmp) = ($filename =~ /=(.+)'(.+)'(.+)/);
	if ($tmp) {
	    $tmp =~ s/%(\w\w)/chr(hex($1))/eg;
	    $filename = $tmp;
	    # codeconv::toeuc(\$filename);
            codeconv::codeconv_document(\$filename);
	} else {
	    $filename =~ s/filename.*=//;
	}
    }
    util::dprint("((Attached filename: $filename))\n");

    if ($filename =~ m!^($conf::DENY_FILE)$!i ) {
	util::vprint(sprintf(_("Denied:	%s"), $filename));
	$err = "Denied file.";
	return $err;
    } elsif ($filename !~ m!^($conf::ALLOW_FILE)$!i) {
	util::vprint(sprintf(_("Not allowed:	%s"), $filename));
	$err = "Not allowed file.";
	return $err;
    }

    #if ($mmtype =~ m!application/octet-stream!) {
	$mmtype = undef;
    #}

    my ($kanji, $mtype) = mknmz::apply_filter(\$filename, $bodyref,
			$weighted_str, \$headings, \%fields,
			$dummy_shelterfname, $mmtype);
    if ($mtype =~ /; x-system=unsupported$/) {
	$$bodyref = "";
        $err = $mtype;
	util::dprint("filter/mailnews.pl gets error message \"$err\"");
    } elsif ($mtype =~ /; x-error=(.*)$/) {
        $$bodyref = "";
        $err = $1;
        util::dprint("filter/mailnews.pl gets error message \"$err\"");
    } else {
	$$bodyref .= " ". $filename;
	gfilter::show_filter_debug_info($bodyref, $weighted_str,
					\%fields, \$headings);
    }
    return $err;
}

1;
