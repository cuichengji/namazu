#
# -*- Perl -*-
# $Id: hdml.pl,v 1.6.4.2 2008-05-09 07:32:14 opengl2772 Exp $
# Copyright (C) 1997-1999 Satoru Takabayashi All rights reserved.
# Copyright (C) 2000,2005-2008 Namazu Project All rights reserved.
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

package hdml;
use strict;
require 'util.pl';
require 'gfilter.pl';

sub mediatype() {
    return ('text/x-hdml');
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
    my $magic = shift @_;
    $magic->addSpecials('text/x-hdml', '<[Hh][Dd][Mm][Ll][^>]*>');
    return;
}

sub filter ($$$$$) {
    my ($orig_cfile, $cont, $weighted_str, $headings, $fields)
      = @_;
    my $cfile = defined $orig_cfile ? $$orig_cfile : '';

    util::vprint("Processing hdml file ...\n");

    hdml($cont, $weighted_str, $fields, $headings);

    gfilter::line_adjust_filter($cont);
    gfilter::line_adjust_filter($weighted_str);
    gfilter::white_space_adjust_filter($cont);
    gfilter::show_filter_debug_info($cont, $weighted_str,
			   $fields, $headings);
    return undef;
}

sub hdml ($$$$) {
    my ($contref, $weighted_str, $fields, $headings) = @_;

    hdml::escape_lt_gt($contref);
    $fields->{'title'} = hdml::get_title($contref, $weighted_str);
    hdml::get_img_alt($contref);
    hdml::get_title_attr($contref);
    hdml::normalize_hdml_element($contref);
    hdml::weight_element($contref, $weighted_str, $headings);
    hdml::remove_hdml_elements($contref);
    # restore entities of each content.
    hdml::decode_entity($contref);
    hdml::decode_entity($weighted_str);
    hdml::decode_entity($headings);
    for my $key (keys %{$fields}) {
	hdml::decode_entity(\$fields->{$key});
    }
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

sub get_title ($$) {
    my ($contref, $weighted_str) = @_;
    my $title = '';

    if ($$contref =~ s!<[A-Z]+[^>]*\s+TITLE\s*=\s*[\"\']?([^\"\'>]*)[\"\']?[^>]*>! $1 !i) {
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

# Get foo from <IMG ... ALT="foo">
# It's not to handle HTML strictly.
sub get_img_alt ($) {
    my ($contref) = @_;

    $$contref =~ s/<IMG[^>]*\s+ALT\s*=\s*[\"\']?([^\"\']*)[\"\']?[^>]*>/ $1 /gi; #"
}

# Get foo from <XXX ... TITLE="foo">
sub get_title_attr ($) {
    my ($contref) = @_;

    $$contref =~ s/<[A-Z]+[^>]*\s+TITLE\s*=\s*[\"\']?([^\"\']*)[\"\']?[^>]*>/ $1 /gi; #"
}

# Normalize elements like: <A HREF...> -> <A>
sub normalize_hdml_element ($) {
    my ($contref) = @_;

    $$contref =~ s/<([!\w]+)\s+[^>]*>/<$1>/g;
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
	$$headings .= $tmp if $element =~ /^H[1-6]$/i && ! $var::Opt{'NoHeadAbst'}
	    && $tmp;
	my $weight = $element =~ /^H[1-6]$/i && ! $var::Opt{'NoHeadAbst'} ?
	    $conf::Weight{'html'}->{$element} : $conf::Weight{'html'}->{$element} - 1;
	$$weighted_str .= "\x7f$weight\x7f$tmp\x7f/$weight\x7f\n" if $tmp;
    }
}

sub weight_element_sub ($$$) {
    my ($element, $text, $tmp) = @_;

    my $space = element_space($element);
    $text =~ s/<[^>]*>//g;
    $$tmp .= "$text " if (length($text)) < $conf::INVALID_LENG;
    $element =~ /^H[1-6]$/i && ! $var::Opt{'NoHeadAbst'}  ? " " : "$space$text$space";
}


# determine whether a given element should be delete or be substituted with space
sub element_space ($) {
    $_[0] =~ /^($conf::NON_SEPARATION_ELEMENTS)$/io ? "" : " ";
}

# remove all HTML elements. it's not perfect but almost works.
sub remove_hdml_elements ($) {
    my ($contref) = @_;

    # remove all comments
    $$contref =~ s/<!?--.*?-->//gs;

    # remove all elements
    $$contref =~ s!</?([A-Z]\w*)(?:\s+[A-Z]\w*(?:\s*=\s*(?:(["']).*?\2|[\w\-.]+))?)*\s*>!element_space($1)!gsixe;

}

# Decode a numberd entity. Exclude an invalid number.
sub decode_numbered_entity ($) {
    my ($num) = @_;
    return ""
	if $num >= 0 && $num <= 8 ||  $num >= 11 && $num <= 31 || $num >=127;
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
