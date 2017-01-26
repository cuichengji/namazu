#
# -*- Perl -*-
# $Id: html.pl,v 1.32.4.19 2008-05-09 07:51:00 opengl2772 Exp $
# Copyright (C) 1997-1999 Satoru Takabayashi All rights reserved.
# Copyright (C) 2000-2008 Namazu Project All rights reserved.
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

package html;
use strict;
require 'util.pl';
require 'gfilter.pl';

my $EMBEDDED_FILE = '\.(asp|jsp|php[3s]?|phtml)(?:\.gz)?';

sub mediatype() {
    return ('text/html');
}

sub status() {
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

    util::vprint("Processing html file ...\n");

    if ($var::Opt{'robotexclude'}) {
	my $err = isexcluded($cont);
	return $err if $err;
    }

    if ($cfile =~ /($EMBEDDED_FILE)$/o) {
       embedded_filter($cont);
    }

    html_filter($cont, $weighted_str, $fields, $headings);

    gfilter::line_adjust_filter($cont);
    gfilter::line_adjust_filter($weighted_str);
    gfilter::white_space_adjust_filter($cont);
    gfilter::show_filter_debug_info($cont, $weighted_str,
			   $fields, $headings);
    return undef;
}

# Check wheter or not the given URI is excluded.
sub isexcluded ($) {
    my ($contref) = @_;
    my $err = undef;

    if ($$contref =~ /META\s+NAME\s*=\s*([\'\"]?)ROBOTS\1\s+[^>]*
	CONTENT\s*=\s*([\'\"]?).*?(NOINDEX|NONE).*?\2[^>]*>/ix)  #"
    {
	$err = _("is excluded because of <meta name=\"robots\" ...>");
    }
    return $err;
}


sub html_filter ($$$$) {
    my ($contref, $weighted_str, $fields, $headings) = @_;

    html::escape_lt_gt($contref);
    $fields->{'title'} = html::get_title($contref, $weighted_str);
    html::get_author($contref, $fields);
    html::get_meta_tags($contref, $weighted_str, $fields);
#    html::get_img_alt($contref);
    html::get_alt_attr($contref) if "ALT" =~ /^(?:$conf::HTML_ATTRIBUTES)$/io;
    html::get_table_summary($contref) if "SUMMARY" =~ /^(?:$conf::HTML_ATTRIBUTES)$/io;
    html::get_title_attr($contref) if "TITLE" =~ /^(?:$conf::HTML_ATTRIBUTES)$/io;
    html::normalize_html_element($contref);
    html::erase_above_body($contref);
    html::remove_comments($contref);
    html::weight_element($contref, $weighted_str, $headings);
    html::remove_html_elements($contref);
    # restore entities of each content.
    html::decode_entity($contref);
    html::decode_entity($weighted_str);
    html::decode_entity($headings);
    for my $key (keys %{$fields}) {
	html::decode_entity(\$fields->{$key});
    }
}

# Get rid of HTML-embedded codes
sub embedded_filter ($) {
    my ($contref) = @_;

    # handle with ASP,JSP,PHP,VBScript,JScript and JavaScript.
    $$contref =~ s/<%.*?%>//gs;
    $$contref =~ s/<\?.*?\?>//gs;
    $$contref =~ s/<asp:.*?\/>//gs;
    $$contref =~ s/<jsp:.*?\/>//gs;
    $$contref =~ s/<script.*?<\/script>//igs;
}

# Convert independent < > s into entity references for escaping.
# Substitute twice for safe.
sub escape_lt_gt ($) {
    my ($contref) = @_;

    $$contref =~ s/\s<\s/ &lt; /g;
    $$contref =~ s/\s>\s/ &gt; /g;
    $$contref =~ s/\s<\s/ &lt; /g;
    $$contref =~ s/\s>\s/ &gt; /g;
}

sub get_author ($$) {
    my ($contref, $fields) = @_;

    # <META NAME="AUTHOR" CONTENT="author">
    # <LINK REV=MADE HREF="mailto:ccsatoru@vega.aichi-u.ac.jp">

    if ($$contref =~ m!<META\s[^>]*?NAME=([\"\']?)AUTHOR\1\s[^>]*?CONTENT=([\"\']?)(.*?)\2\s*/?>!is) {
        $fields->{'author'} = $3;
    } elsif ($$contref =~ m!<LINK\s[^>]*?HREF=([\"\']?)mailto:(.*?)\1\s*/?>!i) {
        $fields->{'author'} = $2;
    } elsif ($$contref =~ m!<ADDRESS[^>]*>(.*?)</ADDRESS>!is) {
	my $tmp = $1;
#	$tmp =~ s/\s//g;
	if ($tmp =~ /\b([\w\.\-]+\@[\w\.\-]+(?:\.[\w\.\-]+)+)\b/) {
	    $fields->{'author'} = $1;
	}
    }
}


# Get title from <title>..</title>
# It's okay to exits two or more <title>...</TITLE>.
# First one will be retrieved.
sub get_title ($$) {
    my ($contref, $weighted_str) = @_;
    my $title = '';

    if ($$contref =~ s!<TITLE[^>]*>(.*?)</TITLE>!!is) {
	$title = $1;
	$title =~ s/\s+/ /g;
	$title =~ s/^\s+//;
	$title =~ s/\s+$//;
	my $weight = $conf::Weight{'html'}->{'title'};
	$$weighted_str .= "\x7f$weight\x7f$title\x7f/$weight\x7f\n";
    } else {
	$title = $conf::NO_TITLE;
    }

    return $title;
}

# get foo bar from <META NAME="keywords|description" CONTENT="foo bar">
sub get_meta_tags ($$$) {
    my ($contref, $weighted_str, $fields) = @_;

    # <meta name="keywords" content="foo bar baz">

    my $weight = $conf::Weight{'metakey'};
    $$weighted_str .= "\x7f$weight\x7f$3\x7f/$weight\x7f\n"
	if $$contref =~ /<meta\s+name\s*=\s*([\'\"]?) #"
	    keywords\1\s+[^>]*content\s*=\s*([\'\"]?)([^>]*?)\2[^>]*>/ix; #"

    # <meta name="description" content="foo bar baz">
    $$weighted_str .= "\x7f$weight\x7f$3\x7f/$weight\x7f\n"
	if $$contref =~ /<meta\s+name\s*=\s*([\'\"]?)description #"
	    \1\s+[^>]*content\s*=\s*([\'\"]?)([^>]*?)\2[^>]*>/ix; #"

    if ($var::Opt{'meta'}) {
        my @keys = split '\|', $conf::META_TAGS;
        for my $key (@keys) {
            if ($key !~ m/^author$/i) {
                my $quotekey = quotemeta($key);
                while ($$contref =~ /<meta\s+name\s*=\s*([\'\"]?)$quotekey #"
                    \1\s+[^>]*content\s*=\s*([\'\"]?)([^>]*?)\2[^>]*>/gix)
                {
                    $fields->{$key} .= $3 . " ";
                }
                util::dprint("meta: $key: $fields->{$key}\n")
                    if defined $fields->{$key};
            }
        }
    }
}

# Get foo from <IMG ... ALT="foo">
# It's not to handle HTML strictly.
sub get_img_alt ($) {
    my ($contref) = @_;

    $$contref =~ s/(<IMG[^>]*)\s+ALT\s*=\s*([\"\'])(.*?)\2([^>]*>)/ $3 $1$4/gi;
    $$contref =~ s/(<IMG[^>]*)\s+ALT\s*=\s*([^\"\'\s>]*)([^>]*>)/ $2 $1$3/gi;
}

# Get foo from <XXX ... ALT="foo">
# It's not to handle HTML strictly.
sub get_alt_attr ($) {
    my ($contref) = @_;

    $$contref =~ s/(<[A-Z]+[^>]*)\s+ALT\s*=\s*([\"\'])(.*?)\2([^>]*>)/ $3 $1$4/gi;
    $$contref =~ s/(<[A-Z]+[^>]*)\s+ALT\s*=\s*([^\"\'\s>]*)([^>]*>)/ $2 $1$3/gi;
}

# Get foo from <TABLE ... SUMMARY="foo">
sub get_table_summary ($) {
    my ($contref) = @_;

    $$contref =~ s/(<TABLE[^>]*)\s+SUMMARY\s*=\s*([\"\'])(.*?)\2([^>]*>)/ $3 $1$4/gi;
    $$contref =~ s/(<TABLE[^>]*)\s+SUMMARY\s*=\s*([^\"\'\s>]*)([^>]*>)/ $2 $1$3/gi;
}

# Get foo from <XXX ... TITLE="foo">
sub get_title_attr ($) {
    my ($contref) = @_;

    $$contref =~ s/(<[A-Z]+[^>]*)\s+TITLE\s*=\s*([\"\'])(.*?)\2([^>]*>)/ $3 $1$4/gi;
    $$contref =~ s/(<[A-Z]+[^>]*)\s+TITLE\s*=\s*([^\"\'\s>]*)([^>]*>)/ $2 $1$3/gi;
}

# Normalize elements like: <A HREF...> -> <A>
sub normalize_html_element ($) {
    my ($contref) = @_;

    $$contref =~ s/<([!\w]+)\s+[^>]*>/<$1>/g;
}

# Remove contents above <body>.
sub erase_above_body ($) {
    my ($contref) = @_;

    $$contref =~ s/^.*<BODY[^>]*>//is;
}


# remove all comments. it's not perfect but almost works.
sub remove_comments ($) {
    my ($contref) = @_;

    # remove all comments
    $$contref =~ s/<!--.*?-->//gs;
}

# Weight a score of a keyword in a given text using %conf::Weight hash.
# This process make the text be surround by temporary tags
# \x7fXX\x7f and \x7f/XX\x7f. XX represents score.
# Sort keys of %conf::Weight for processing <a> first.
# Because <a> has a tendency to be inside of other tags.
# Thus, it does'not processing for nexted tags strictly.
# Moreover, it does special processing for <h[1-6]> for summarization.
sub weight_element ($$$ ) {
    my ($contref, $weighted_str, $headings) = @_;

    for my $element (sort keys(%{$conf::Weight{'html'}})) {
	my $tmp = "";
	$$contref =~ s!<($element)>(.*?)</$element>!weight_element_sub($1, $2, \$tmp)!gies;
	$$headings .= $tmp if $element =~ /^H[1-6]$/i && ! $var::Opt{'noheadabst'}
	    && $tmp;
	my $weight = $element =~ /^H[1-6]$/i && ! $var::Opt{'noheadabst'} ?
	    $conf::Weight{'html'}->{$element} : $conf::Weight{'html'}->{$element} - 1;
	$$weighted_str .= "\x7f$weight\x7f$tmp\x7f/$weight\x7f\n" if $tmp;
    }
}

sub weight_element_sub ($$$) {
    my ($element, $text, $tmp) = @_;

    my $space = element_space($element);
    $text =~ s/<[^>]*>//g;
    $$tmp .= "$text " if (length($text)) < $conf::INVALID_LENG;
    $element =~ /^H[1-6]$/i && ! $var::Opt{'noheadabst'}  ? " " : "$space$text$space";
}


# determine whether a given element should be delete or be substituted with space
sub element_space ($) {
    $_[0] =~ /^($conf::NON_SEPARATION_ELEMENTS)$/io ? "" : " ";
}

# remove all HTML elements. it's not perfect but almost works.
sub remove_html_elements ($) {
    my ($contref) = @_;

    # remove Office Markup <o:></o:>, <![]>
    $$contref =~ s#</?([A-Z]\w*):.*?>|<(!)\[.*?\]\s*/?>#element_space($1||$2)#gsixe;

    # remove all elements
    $$contref =~ s!</?([A-Z]\w*)(?:\s+[A-Z]\w*(?:\s*=\s*(?:(["']).*?\2|[\w\-.]+))?)*\s*/?>!element_space($1)!gsixe;

}

# Decode a numberd entity. Exclude an invalid number.
sub decode_numbered_entity ($) {
    my ($num) = @_;

    # FIXME: very ad hoc. (ISO-8859-1)
    return ""
        if (($num >= 0 && $num <= 31) || ($num >= 127 && $num <= 159) ||
        ($num >= 256));
    return ""
	if $num >=127 && util::islang('ja');
    sprintf ("%c",$num);
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
    $$text =~ s/&amp[;\s]/&/g;
    $$text =~ s/&lt[;\s]/</g;
    $$text =~ s/&gt[;\s]/>/g;
    $$text =~ s/&nbsp[;\s]/ /g;
}


# encode entities: only '<', '>', and '&'
sub encode_entity ($) {
    my ($tmp) = @_;

    $$tmp =~ s/&/&amp;/g;    # &amp; should be processed first
    $$tmp =~ s/</&lt;/g;
    $$tmp =~ s/>/&gt;/g;
    $$tmp;
}

1;
