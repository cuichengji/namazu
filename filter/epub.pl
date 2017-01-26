#
# -*- Perl -*-
# $Id: epub.pl,v 1.1.2.1 2013-08-21 16:48:09 opengl2772 Exp $
# Copyright (C) 2013 Tadamasa Teranishi All rights reserved.
#               2013 Namazu Project All rights reserved ,
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

package epub;
use strict;
use English;
require 'util.pl';
require 'gfilter.pl';
require 'html.pl';

my $rootfile = undef;
my $opsdir = undef;
my $language = 'en';

sub mediatype() {
    return ('application/epub+zip');
}

sub status() {
    if (ext::issupport('EXT_ZIP') eq 'yes') {
        if (ext::issupport('EXT_UTF8') eq 'yes') {
            return 'yes';
        }
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
    $magic->addFileExts('\\.epub$', 'application/epub+zip');
    return;
}

sub filter ($$$$$) {
    my ($orig_cfile, $contref, $weighted_str, $headings, $fields)
        = @_;
    my $err = undef;
	$err = filter_metainf($contref, $weighted_str, $fields);
    return $err if (defined $err);
    $err = filter_opf($contref, $weighted_str, $headings, $fields);
#    return $err if (defined $err);

    return $err;
}

sub filter_metainf ($$$) {
    my ($contref, $weighted_str, $fields) = @_;

    my $xml = "";
    my $err = $extzip::zip_read->($contref, 'META-INF/container.xml', \$xml);
    return $err if (defined $err);
    codeconv::normalize_nl(\$xml);


    $rootfile = epub::get_rootfile(\$xml);
    epub::decode_entity(\$rootfile);

    # Code conversion for Japanese document.
    $extutf8::codeconv_document->(\$rootfile);

	$opsdir = $rootfile;
	$opsdir =~ s![^/]*$!!s;

    return undef;
}

sub filter_contentfile ($$$$) {
    my ($contref, $weighted_str, $headings, $fields) = @_;

    codeconv::normalize_nl($contref);

    # Code conversion for Japanese document.
    $extutf8::codeconv_document->($contref);

	util::vprint("==================\n");
	util::vprint("$$contref\n");
	util::vprint("==================\n");

	html::html_filter($contref, $weighted_str, $fields, $headings);
	util::vprint("------------------\n");
	util::vprint("$$contref\n");
	util::vprint("------------------\n");

    return undef;
}

sub filter_opf ($$$$) {
    my ($contref, $weighted_str, $headings, $fields) = @_;

    my $xml = "";
    my $err = $extzip::zip_read->($contref, $rootfile, \$xml);
    return $err if (defined $err);
    codeconv::normalize_nl(\$xml);

	$xml =~ s!<guide[\s>]+.*</guide>!!s;
	$xml =~ s!<spine[\s>]+.*</spine>!!s;

    my $authorname = epub::get_author(\$xml);
    my $title = epub::get_title(\$xml);
	my $date = epub::get_date(\$xml);
	my $language = epub::get_language(\$xml);
    my $description = epub::get_description(\$xml);

    epub::decode_entity(\$authorname);
    epub::decode_entity(\$title);
    epub::decode_entity(\$date);
    epub::decode_entity(\$language);
    epub::decode_entity(\$description);

    # Code conversion for Japanese document.
    $extutf8::codeconv_document->(\$authorname);
    $extutf8::codeconv_document->(\$title);
    $extutf8::codeconv_document->(\$date);
    $extutf8::codeconv_document->(\$language);
    $extutf8::codeconv_document->(\$description);

	my $text = $description;
	while($xml =~ m!href\s*=\s*([\"\'])(.*?)\1\s+!g) {
		my $file = $2;
		if ($file =~ m!(.*\.x?html)!s) {
			my $contentfile = $opsdir . $1;
        	my $xml = "";
			$contentfile =~ s/%([\da-f]{2})/sprintf("%c", hex($1))/gei;
	    	util::vprint("%%%%%%%... $contentfile\n");
        	my $err = $extzip::zip_read->($contref, $contentfile, \$xml);
	    	util::dprint("%%%%%%%... $err\n") if (defined $err);
			next if (defined $err);
			filter_contentfile(\$xml, $weighted_str, $headings, $fields);
			$text .= $xml;
		}
	}
	$$contref = $text;

    if (!($authorname eq "")) {
        $fields->{'author'} = $authorname;
    }
    if (!($title eq "")) {
        $fields->{'title'} = $title;
        my $weight = $conf::Weight{'html'}->{'title'};
        $$weighted_str .= "\x7f$weight\x7f$title\x7f/$weight\x7f\n";
    }
    if (!($date eq "")) {
        $fields->{'date'} = $date;
    }

	util::vprint("description [$description]\n");
	if (!($description eq "")) {
		$fields->{'summary'} = $description;
	}

    gfilter::line_adjust_filter($contref);
    gfilter::line_adjust_filter($weighted_str);
    gfilter::white_space_adjust_filter($contref);
    gfilter::show_filter_debug_info($contref, $weighted_str,
                                    $fields, $headings);

    return undef;
}

sub get_rootfile($) {
  my ($contref) = @_;
  if ($$contref =~ m!<rootfile\s+(.*?)\s*/>!s) {
      my $cont = $1;
      if ($cont =~ m!full-path\s*=\s*([\"\'])(.*?)\1!s) {
          return $2;
      } else {
          return "";
      }
  } else {
      return "";
  }
}

sub get_author($) {
  my ($contref) = @_;
  if ($$contref =~ m!<dc:creator[^>]*>(.*?)</dc:creator>!s) {
      return $1;
  } else {
      return "";
  }
}

sub get_title($) {
  my ($contref) = @_;
  if ($$contref =~ m!<dc:title[^>]*>(.*?)</dc:title>!s) {
      return $1;
  } else {
      return "";
  }
}

sub get_date($) {
  my ($contref) = @_;
  my ($YYYY, $MM, $DD, $hh, $mm, $ss, $timezone) = (1900, 01, 01, 00, 00, 00, "GMT");

  if ($$contref =~ m!<dc:date[^>]*>(.*?)</dc:date>!s) {
      my $dstr = $1;
      if ($dstr =~ m!^(\d{4})-(\d{2})-(\d{2})(?:T(\d{2}):(\d{2})(?::(\d{2}))?(.*))?$!s) {
          $YYYY     = $1;
          $MM       = $2;
          $DD       = $3;
          $hh       = $4;
          $mm       = $5;
          $ss       = $6;
          $timezone = $7;

          $hh = 0			unless($hh);
          $mm = 0			unless($mm);
          $ss = 0			unless($ss);
          $timezone = "GMT"	unless($timezone);
          if ($timezone eq "Z") {
              $timezone = "GMT";
          }

          my @month = (
            "Jan", "Feb", "Mar", "Apr",
            "May", "Jun", "Jul", "Aug",
            "Sep", "Oct", "Nov", "Dec"
          );
          my $m = $month[$MM - 1];
          my $date = sprintf("%.2d %s %.4d %.2d:%.2d %s", 
              $DD, $m, $YYYY, $hh, $mm, $timezone);
          time::normalize_rfc822time(\$date);

          return $date;
      }
  }
  return "";
}

sub get_language($) {
  my ($contref) = @_;
  if ($$contref =~ m!<dc:language[^>]*>(.*?)</dc:language>!s) {
      return $1;
  } else {
      return "";
  }
}

sub get_description($) {
  my ($contref) = @_;
  if ($$contref =~ m!<dc:description[^>]*>(.*?)</dc:description>!s) {
      return $1;
  } else {
      return "";
  }
}

sub remove_all_tag ($) {
  my ($contref) = @_;
      $$contref =~ s/<[^>]*>/\n/gs;
      $$contref =~ s/\n+/\n/gs;
      $$contref =~ s/^\n+//;
}

#
# [obsolute] convert utf-8 to euc
#
sub utoe ($) {
    my ($tmp) = @_;

    $extutf8::utf8_to_eucjp->($tmp);
}

# Decode a numberd entity. Exclude an invalid number.
sub decode_numbered_entity ($) {
    my ($num) = @_;
    return ""
        if $num >= 0 && $num <= 8 ||  $num >= 11 && $num <= 31 || $num >=127;
    sprintf("%c", $num);
}

# Decode an entity. Ignore characters of right half of ISO-8859-1.
# Because it can't be handled in EUC encoding.
# This function provides sequential entities like: &quot &lt &gt;
sub decode_entity ($) {
    my ($text) = @_;

    return unless defined($$text);

    $$text =~ s/&#(\d{2,3})[;\s]/decode_numbered_entity($1)/ge;
    $$text =~ s/&#x([\da-f]+)[;\s]/decode_numbered_entity(hex($1))/gei;
    $$text =~ s/&quot[;\s]/\"/g; #"
    $$text =~ s/&apos[;\s]/\'/g; #"
    $$text =~ s/&amp[;\s]/&/g;
    $$text =~ s/&lt[;\s]/</g;
    $$text =~ s/&gt[;\s]/>/g;
    $$text =~ s/&nbsp[;\s]/ /g;
}

1;
