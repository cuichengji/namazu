#
# -*- Perl -*-
# document.pl - class for document
#
# $Id: document.pl,v 1.4.2.4 2009-01-29 17:02:53 opengl2772 Exp $
#
# Copyright (C) 2004 Yukio USUDA All rights reserved.
# Copyright (C) 2000-2009 Namazu Project All rights reversed.
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

package mknmz::document;
use strict;
use English;
use File::Copy;
require 'gfilter.pl';
require 'filter.pl';
require 'gettext.pl';

use File::MMagic;
my $Magic = new File::MMagic;
my $Filter = undef;

sub new {
    my $self = {};
    my $proto = shift @_;
    my $class = ref($proto) || $proto;
    bless($self, $class);

    return $self;
}

sub init {
    my $self = shift @_;
    unless ($Filter) {
        $Filter = mknmz::filter->new();
        $Filter->init($Magic);
    }
}

sub init_doc {
    my $self = shift @_;
    $self->{'_uri'} = shift @_;
    $self->{'_orig_filename'} = shift @_;
    $self->{'_contentref'} = shift @_;
    $self->{'_mimetype'} = shift @_;

    $self->{'_filename'} = undef;
    $self->{'_filtered'} = undef;
    $self->{'_weighted_str'} = undef;
    $self->{'_headings'} = undef;
    $self->{'_errmsg'} = undef;
    $self->{'_field_info'} = { 'author' => '', 'title' => '' };
    $self->_check_content();
    $self->{'_mimetype'} = $self->get_mimetype();
}


sub get_file_size {
    my $self = shift @_;

    return $self->{'_field_info'}{'size'};
}

sub get_text_size {
    my $self = shift @_;

    unless ($self->{'_filtered'}) {
        $self->get_filtered_contentref();
    }
    my $text_size = 0;
    if ($self->{'_contentref'}) {
        # Measure the text size after apply filter.
        $text_size
            = length(${$self->{'_contentref'}})
            + length($self->{'_weighted_str'});
    }
    return $text_size;
}

sub is_contain_kanji {
    my $self = shift @_;
    my $kanji = ${$self->{'_contentref'}} =~ tr/\xa1-\xfe/\xa1-\xfe/;
    $kanji += $self->{'_weighted_str'} =~ tr/\xa1-\xfe/\xa1-\xfe/;
    return $kanji;
}

sub get_field_info {
    my $self = shift @_;
    my $fieldname = shift @_;

    unless ($self->{'_filtered'}) {
        $self->get_filtered_contentref();
    }
    return $self->{'_field_info'}{$fieldname};
}

sub get_fields {
    my $self = shift @_;

    unless ($self->{'_filtered'}) {
        $self->get_filtered_contentref();
    }
    return %{$self->{'_field_info'}};
}

sub get_orig_filename {
    my $self = shift @_;
    return $self->{'_orig_filename'};
}

sub get_filename {
    my $self = shift @_;
    unless ( $self->{'_filename'}) {
        my $tmp = "";
        my $orig_filename = $self->get_orig_filename();
        $self->{'_filename'} = gfilter::filename_to_title($orig_filename, $tmp)
    }
    return $self->{'_filename'};
}

sub get_uri {
    my $self = shift @_;
    my $replace_uri = @_;
    unless ($self->{'_uri'}) {
        my $orig_filename = $self->get_orig_filename();

    }
    return $self->{'_uri'};
}

sub get_errmsg {
    my $self = shift @_;
    return $self->{'_errmsg'};
}

sub get_filtered_contentref {
    my $self = shift @_;
    unless ($self->{'_filtered'}) {
        my $mtype = $self->get_mimetype();
        my $content_encode = $self->get_content_encode();
        my ($weighted_str, $headings)
            = $Filter->apply_filter(\$self->{'_orig_filename'},
				$self->{'_contentref'},
				$mtype,
				$content_encode,
				\$self->{'_field_info'},
            );
        if ($weighted_str eq 0) {
            ${$self->{'_contentref'}} = "";
            $mtype = $headings;
        }
        $self->{'_weighted_str'} = $weighted_str;
        $self->{'_headings'} = $headings;
        $self->{'_filtered'} = 'yes';
        $self->{'_errmsg'} = _check_file($self->{'_orig_filename'},
            $self->get_file_size(),
            $self->get_text_size(),
            $mtype,
            $self->get_uri());
    }
    return $self->{'_contentref'};
}

sub get_mimetype {
    my $self = shift @_;
    unless ($self->{'_mimetype'}) {
        $self->{'_mimetype'} = _guess_mimetype($self->{'_orig_filename'},
						$self->{'_contentref'});
    }
    return $self->{'_mimetype'};
}

sub get_weighted_str {
    my $self = shift @_;
    return $self->{'_weighted_str'};
}

sub get_headings {
    my $self = shift @_;
    return $self->{'_headings'};
}

sub get_mtime {
    my $self = shift @_;
    my $mtime = (stat($self->{'_orig_filename'}))[9]
    unless util::isurl($self->{'_orig_filename'});
    $self->{'_field_info'}{'mtime'} = $mtime;
    return $self->{'_field_info'}{'mtime'};
}

sub get_content_encode {
    my $self = shift @_;
    unless ($self->{'_content_encode'}) {
        my $mimetype = $self->get_mimetype;
        if ($mimetype eq "text/html") {

        }
    }
    return $self->{'_content_encode'};
}

sub get_filter {
    my $self = shift @_;
    return $Filter;
}

sub get_mmagic {
    my $self = shift @_;
    return $Magic;
}

sub get_info {
    my $self = shift @_;
    my $name = shift @_;
    if ($name eq 'mmagic_ver') {
        return "$File::MMagic::VERSION" if $File::MMagic::VERSION;
        return "";
    }
}

#############################################################
#
# Decide the media type.
# FIXME: Very ad hoc. It's just a compromise. -- satoru
#
sub _decide_type ($$) {
    my ($name, $cont) = @_;
    return $name if (!defined $cont || $name eq $cont);

    util::dprint("decide_type: name: $name, cont: $cont\n");
    if ($cont =~ m!^text/plain! && $name =~ m!^text/plain!) {
        return $name;
    } elsif ($cont =~ m!^application/octet-stream! &&
             $name !~ m!^text/!) {
        return $name;
    } elsif ($cont =~ m!^application/(excel|powerpoint|msword)! &&
             $name !~ m!^application/octet-stream!)  {
        # FIXME: Currently File::MMagic 1.02's checktype_data()
        # is unreliable for them.
        return $name;
    } elsif ($cont =~ m!^application/x-zip! &&
             $name =~ m!^application/!) {
        # zip format is used other applications e.g. OpenOffice.
        # It is necessary to add to check extention.
        return $name;
    }
    return $cont;
}

sub _guess_mimetype ($$) {
    my ($cfile, $contref) = @_;

    my $mtype;
    my $called_dt = 0;
    {
        my $mtype_n = $Magic->checktype_byfilename($cfile);
        my $mtype_c = $Magic->checktype_data($$contref);
        my $mtype_m;
        $mtype_m = $Magic->checktype_magic($$contref)
          if ((!defined $mtype_c) ||
          $mtype_c =~
          /^(text\/html|text\/plain|application\/octet-stream)$/);
        $mtype_c = $mtype_m
          if (defined $mtype_m &&
          $mtype_m !~
          /^(text\/html|text\/plain|application\/octet-stream)$/);
        $mtype_c = 'text/plain' unless defined $mtype_c;
        if ($called_dt) {
            $mtype = $mtype_c;
        } else {
            $mtype = _decide_type($mtype_n, $mtype_c);
            $called_dt = 1;
        }
    }
    util::dprint(_("Detected type: ")."$mtype\n");
    return $mtype;
}

sub _check_content {
    my $self = shift @_;

    my $file_size;
    if (!defined ${$self->{'_contentref'}}) {
        my $cfile = $self->{'_orig_filename'};
        # for handling a filename which contains Shift_JIS code for Windows.
        # for handling a filename which contains including space.

        if (($cfile =~ /\s/) ||
            ($English::OSNAME eq "MSWin32"
            && $cfile =~ /[\x81-\x9f\xe0-\xef][\x40-\x7e\x80-\xfc]|[\x20\xa1-\xdf]/))
        {
            my $tmpfile = util::tmpnam("NMZ.win32");
            unlink $tmpfile if (-e $tmpfile);
            copy($self->{'_orig_filename'}, $tmpfile);

            $file_size = util::filesize($tmpfile); # not only file in feature.
            if ($file_size > $conf::FILE_SIZE_MAX) {
                $self->{'_errmsg'} =
                    _("is larger than your setup before filtered, skipped: ") . 'conf::FILE_SIZE_MAX (' . $conf::FILE_SIZE_MAX . ') < '. $file_size ;
                $self->{'_mimetype'} = 'x-system/x-error; x-error=file_size_max';
                unlink $tmpfile;
                return;
            }

            ${$self->{'_contentref'}} = util::readfile($tmpfile);

            unlink $tmpfile;
        } else {
            $file_size = util::filesize($cfile); # not only file in feature.
            if ($file_size > $conf::FILE_SIZE_MAX) {
                $self->{'_errmsg'} =
                    _("is larger than your setup before filtered, skipped: ") . 'conf::FILE_SIZE_MAX (' . $conf::FILE_SIZE_MAX . ') < '. $file_size ;
                $self->{'_mimetype'} = 'x-system/x-error; x-error=file_size_max';
                return;
            }

            ${$self->{'_contentref'}} = util::readfile($cfile);
        }
    } else {
        $file_size = length(${$self->{'_contentref'}});
    }
    $self->{'_field_info'}{'size'} = $file_size;
}

# check the file. No $msg is good.
#
sub _check_file ($$$$$) {
    my ($cfile, $cfile_size, $text_size, $mtype, $uri) = @_;

    my $msg = undef;
    if ($mtype =~ /; x-system=unsupported$/) {
        $mtype =~ s/; x-system=unsupported$//;
        $msg = _("Unsupported media type ")."($mtype)"._(" skipped.");
    } elsif ($mtype =~ /; x-error=file_size_max/) {
        $msg = _("is larger than your setup before filtered, skipped: ") . 'conf::FILE_SIZE_MAX (' . $conf::FILE_SIZE_MAX . ') < '. $cfile_size ;
    } elsif ($mtype =~ /; x-error=.*$/) {
        $mtype =~ s/^.*; x-error=(.*)$/$1/;
        $msg = $mtype;
    } elsif ($mtype =~ /^x-system/) {
        $msg = _("system error occurred! ")."($mtype)"._(" skipped.");
    } elsif (! -e $cfile) {
        $msg = _("does NOT EXIST! skipped.");
    } elsif (! util::canopen($cfile)) {
        $msg = _("is NOT READABLE! skipped.");
    } elsif ($text_size == 0 || $cfile_size == 0) {
        $msg = _("is 0 size! skipped.");
    } elsif ($mtype =~ /^application\/octet-stream/) {
        $msg = _("may be a BINARY file! skipped.");
    } elsif ($cfile_size > $conf::FILE_SIZE_MAX) {
        $msg = _("is larger than your setup before filtered, skipped: ") . 'conf::FILE_SIZE_MAX (' . $conf::FILE_SIZE_MAX . ') < '. $cfile_size ;
    } elsif ($text_size > $conf::TEXT_SIZE_MAX) {
        $msg = _("is larger than your setup after filtered, skipped: ") . 'conf::TEXT_SIZE_MAX (' . $conf::TEXT_SIZE_MAX . ') < '. $text_size ;
    }

    return $msg;
}


1;
