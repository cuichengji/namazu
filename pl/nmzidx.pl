#
# -*- Perl -*-
# nmzidx.pl - subroutines for accessing Namazu index files (NMZ.*)
#         by furukawa@tcp-ip.or.jp
#
# $Id: nmzidx.pl,v 1.13.4.7 2006-05-30 13:34:36 opengl2772 Exp $
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

use strict;
use English;
use IO::File;
use DirHandle;

package nmzlib;

sub open_db{
    my $par = shift;
    my $ext = shift;
    my $path = $par->{'dir'} . "/NMZ.$ext";
    my $fh;
    if ($par->{'mode'} =~ /w/i){
        $fh = new IO::File "$path.$$.tmp", "w";
    }else{
        $fh = new IO::File $path, "r";
    }
    $par->{'dblist'}->{$path} = $fh, binmode $fh if defined $fh;
    return $fh;
}

sub readw{
    my $fh = shift;
    my $ret = '';
    my $c;

    while (read($fh, $c, 1)){
        $ret .= $c;
        last unless 0x80 & ord $c;
    }
    unpack('w', $ret);
}

package nmzfile;

sub new{
    my $class = shift;
    my $self = {};
    bless $self, $class;
    my $par = shift;
    my $ext = shift;
    my $fhb = &nmzlib::open_db($par, $ext);

    $self->{'dir'} = $par->{'dir'};
    $self->{'mode'} = $par->{'mode'};

    $self->{'body'} = $fhb if defined $fhb;
    $self->{'ext'} = $ext;
    $ext .= ($ext =~ /^field/)? '.i': 'i';
    my $fhi = &nmzlib::open_db($par, $ext);
    $self->{'index'} = $fhi if defined $fhi;
    $self->{'offset'} = 0;
    if (defined($self->{'index'})){
        $self->{'size'} = (-s $self->{'index'}) / length(pack('N', 0));
    }
    return $self;
}

sub close{
    my $self = shift;
    $self->{'body'}->close;
    $self->{'index'}->close if defined $self->{'index'};
}

sub seek{
    my $self = shift;
    my $offset = @_? shift: 0;
    my $whence = @_? shift: 0;

    if ($whence == 1){
        $offset += $self->{'offset'};
    }elsif ($whence == 2){
        $offset += $self->{'size'};
    }
    return $offset if $offset == $self->{'offset'};
    return -1 if ($offset < 0 || $offset > $self->{'size'});
    $self->{'offset'} = $offset;
    $self->{'index'}->seek($offset * length(pack('N', 0)), 0);

    if ($self->{'ext'} ne 'p'){
        if ($offset == $self->{'size'}){
            $self->{'body'}->seek(0, 2);
        }else{
            my $buf;
            $self->{'index'}->read($buf, length pack('N', 0));
            $self->{'body'}->seek(unpack('N', $buf), 0);
        }
    }
    return $offset;
}

sub getline{
    my $self = shift;
    return undef unless defined $self->{'body'};
    ++$self->{'offset'};
    return $self->{'body'}->getline;
}

sub getlist{
    my $self = shift;
    return undef unless defined $self->{'body'};
    return undef if $self->{'offset'} >= $self->{'size'};

    if ($self->{'offset'} == $self->{'size'}){
        return ();
    }
    ++$self->{'offset'};

    if ($self->{'ext'} eq 'p'){
        my $buf;
        $self->{'index'}->read($buf, length pack('N', 0));
        return () if $buf eq pack('N', -1);
        $self->{'body'}->seek(unpack('N', $buf), 0);
    }
    $self->{'body'}->read(my $buf, &nmzlib::readw($self->{'body'}));
    return unpack('w*', $buf);
}

sub putline{
    my $self = shift;
    if (@_){
        my $output;

        $output = shift;
        $output =~ s/\n.*$//s;
        $output .= "\n";

        $self->{'index'}->print(pack('N', $self->{'body'}->tell));
        $self->{'body'}->print($output);
        ++$self->{'size'};
        ++$self->{'offset'};
    }
}

sub putlist{
    my $self = shift;
    if (@_){
        $self->{'index'}->print(pack('N', $self->{'body'}->tell));
        my $tmp = pack('w*', @_);
        $self->{'body'}->print(pack('w', length $tmp) . $tmp);
    }elsif ($self->{'ext'} eq 'p'){
        $self->{'index'}->print(pack('N', -1));
        ++$self->{'size'};
        ++$self->{'offset'};
    }
}

package nmzfield;
sub new{
    my $class = shift;
    my $self = {};
    bless $self, $class;
    $self->open(@_) if @_;
    return $self;
}

sub open{
    my $self = shift;
    my $par = shift;
    my $ext = shift;

    $self->{$ext} = new nmzfile($par, "field." . $ext);
}

sub open_all{
    my $self = shift;
    my $par = shift;
    my $dh = new DirHandle($par->{'dir'});
    while (defined(my $ent = $dh->read)){
        if ($ent =~ /^NMZ\.field\.([^\.]+)$/){
            $self->{$1} = new nmzfile($par, "field." . $1);
        }
    }
    $dh->close;
}

sub close{
    my $self = shift;
    for my $key (keys %$self){
        $self->{$key}->close;
    }
}

sub seek{
    my $self = shift;
    $self->seek(@_);
}


package nmzflist;
sub new{
    my $class = shift;
    my $self = {};
    my $par = shift;
    bless $self, $class;

    $self->{'dir'} = $par->{'dir'};
    $self->{'mode'} = $par->{'mode'};

    $self->{'t'} = &nmzlib::open_db($par, 't');
    $self->{'r'} = &nmzlib::open_db($par, 'r') unless $par->{'mode'} =~ /s/i;

    $self->{'field'} = new nmzfield;
    $self->{'field'}->open_all($par);
    $self->{'offset'} = 0;
    if (defined $self->{'t'}) {
        $self->{'size'} = (-s $self->{'t'}) / length(pack('N', 0));
        $self->{'valid'} = $self->{'size'};
    }
    return $self;
}

sub close{
    my $self = shift;
    $self->{'t'}->close if defined $self->{'t'};
    $self->{'r'}->close if defined $self->{'r'};
    $self->{'field'}->close;
}

sub read{
    my $self = shift;
    my $list = shift;
    %$list = ();

    my $fh = $self->{'t'};
    $fh->read(my $pindex, length pack('N', 0));
    $list->{'t'} = ($pindex eq pack('N', -1))? -1: unpack('N', $pindex);

    if (defined(my $fh = $self->{'r'})){
        $list->{'r'} = $fh->getline;
        $list->{'r'} = $fh->getline while (defined($list->{'r'}) && $list->{'r'} =~ /^[\#\r\n]/);
        chomp $list->{'r'} if defined $list->{'r'};
    }

    my $field = $self->{'field'};
    for my $key (keys %$field){
        $fh = $field->{$key};
        my $line = $fh->getline;
        $line = '' unless defined $line;
        chomp $line;
        $list->{'field'}->{$key} = $line;
    }
    --$self->{'valid'} if defined($list->{'t'}) && $list->{'t'} == -1;
    ++$self->{'offset'};
    return $list->{'t'}
}

sub write{
    my $self = shift;
    my $list = shift;

    my $fh = $self->{'t'};
    $fh->print(pack('N', $list->{'t'}));

    $fh = $self->{'r'};
    $fh->print($list->{'r'} . "\n");

    my $field = $self->{'field'};
    for my $key (keys %$field){
        $field->{$key}->putline($list->{'field'}->{$key} . "\n")
    }
    ++$self->{'valid'} if $list->{'t'} != -1;
    ++$self->{'size'};
    ++$self->{'offset'};
}

sub seek{
    my $self = shift;
    my $offset = @_? shift: 0;
    my $whence = @_? shift: 0;

    $self->{'t'}->seek($offset * length pack('N', 0), $whence);

    my $field = $self->{'field'};
    for my $key (keys %$field){
        $field->{$key}->seek($offset, $whence);
    }
    if ($whence == 0){
        $self->{'offset'} = $offset;
    }elsif ($whence == 1){
        $self->{'offset'} += $offset;
    }elsif ($whence == 2){
        $self->{'offset'} = $offset + $self->{'size'};
    }
    return $self->{'offset'};
}


package nmzword;
sub new{
    my $class = shift;
    my $par = shift;
    my $self = {};
    bless $self, $class;

    $self->{'dir'} = $par->{'dir'};
    $self->{'mode'} = $par->{'mode'};

    $self->{'i'} = new nmzfile($par, 'i');
    $self->{'w'} = new nmzfile($par, 'w');
    $self->{'offset'} = 0;
    $self->{'size'} = $self->{'i'}->{'size'};
    return $self;
}

sub close{
    my $self = shift;
    $self->{'i'}->close;
    $self->{'w'}->close;
}

sub read{
    my $self = shift;
    my $word = shift;
    my $list = shift;
    %$list = ();

    return unless defined($$word = $self->{'w'}->getline);
    chomp $$word;

    my $key = 0;
    my @tmp = $self->{'i'}->getlist;
    $key += shift @tmp, $list->{$key} = shift @tmp while @tmp;
    ++$self->{'offset'};
    return $$word;
}

sub write{
    my $self = shift;
    my $word = shift;
    my $list = shift;

    if (length $word and scalar keys %$list){
        $self->{'w'}->putline($word . "\n");

        my @tmp = ();
        my $ndx = 0;
        for my $key (sort {$a <=> $b} keys %$list){
            push(@tmp, $key - $ndx);
            push(@tmp, $list->{$key});
            $ndx = $key;
        }
        $self->{'i'}->putlist(@tmp);
        ++$self->{'size'};
        ++$self->{'offset'};
    }
}

sub seek{
    my $self = shift;

    my $offset_i = $self->{'i'}->seek(@_);
    my $offset_w = $self->{'w'}->seek(@_);

    if ($offset_i == $offset_w){
        return $self->{'offset'} = $offset_i;
    }else{
        return -1;
    }
}

sub getword{
    my $self = shift;
    my $number = shift;
    $self->seek($number, 0);
    my $buf = $self->{'w'}->getline;
    chomp $buf;
    return $buf;
}

sub _search_{
    my $self = shift;
    my $keyword = shift;
    my $l = 0;
    my $r = $self->{'size'} - 1;
    my $ptr = (@_ && ref($_[0]) eq 'SCALAR')? shift: undef;
    $r = $$ptr if defined($ptr) && $$ptr >= 0;

    if (defined $self->{'cache'}->{'search'}->{$keyword}){
        $$ptr = $self->{'cache'}->{'search'}->{$keyword} if defined $ptr;
        return $self->{'cache'}->{'search'}->{$keyword};
    }

    my $x;
    while ($x = ($l + $r) >> 1, $l < $r){
        my $buf = $self->getword($x);
        if ($buf eq $keyword){
            $$ptr = $self->{'cache'}->{'search'}->{$keyword} = $x if defined $ptr;
            return $x;
        }
        if ($buf ge $keyword){
            $r = $x;
        }else{
            $l = $x + 1;
        }
    }
    $$ptr = $x if defined $ptr;
    return $self->{'cache'}->{'search'}->{$keyword} = -1;
}

sub wakati{
    my $self = shift;
    my $keyword = shift;
    my $opt = @_? shift: '';
    my $buf;

    my $r = -1;
    my $x;
    my $post = '';
    my $pat = ($opt =~ /b/)? '.': '..';
    while (1){
        $x = $self->_search_($keyword, \$r);
        last if $x >= 0 || $keyword !~ s/($pat)$//;
        $post = $1 . $post;
    }
    return ($keyword, $post);
}

sub forward{
    my $self = shift;
    my $word = shift;
    my $keyword = shift;
    my $buf;

    my $x = $self->_search_($keyword);

    $keyword = quotemeta($keyword);
    @$word = ();
    while (($buf = $self->getword($x)) =~ /^$keyword/){
        $self->{'cache'}->{'search'}->{$buf} = $x++;
        push(@$word, $buf);
    }
    return @$word;
}

sub search{
    my $self = shift;
    my $list = shift;
    my $keyword = shift;
    my $word;

    if ((my $x = $self->_search_($keyword)) >= 0){
        $self->seek($x, 0);
        return $self->read(\$word, $list);
    }else{
        return undef;
    }
}

package nmzphrase;
@nmzphrase::Seed = ();

sub new{
    my $class = shift;
    my $par = shift;
    my $self = {};
    bless $self, $class;

    $self->{'dir'} = $par->{'dir'};
    $self->{'mode'} = $par->{'mode'};

    $self->{'p'} = new nmzfile($par, 'p');
    $self->{'offset'} = 0;
    $self->{'size'} = 0x10000;
    $self->init_seed if $self->{'mode'} =~ /s/i;
    return $self;
}

sub close{
    my $self = shift;
    $self->{'p'}->close;
}

sub read{
    my $self = shift;
    my $list = shift;

    @$list = ();
    my $ndx = 0;
    my @tmp = $self->{'p'}->getlist;
    push(@$list, $ndx += shift @tmp) while @tmp;
    ++$self->{'offset'};
    return scalar @$list;
}

sub write{
    my $self = shift;
    my $list = shift;

    my $fh_p = $self->{'p'};
    my $fh_pi = $self->{'pi'};
    my @tmp = ();
    my $ndx = 0;

    for my $key (@$list){
        push(@tmp, $key - $ndx);
        $ndx = $key;
    }
    $self->{'p'}->putlist(@tmp);
    ++$self->{'offset'};
}

sub seek{
    my $self = shift;
    return $self->{'offset'} = $self->{'p'}->seek(@_);
}

sub search{
    my $self = shift;
    my $list = shift;
    my $phrase = shift;
    $phrase .= shift if @_;

    my $hash = 0;
    my $i = 0;
    while ($phrase =~ m/([\xa1-\xfea-z\d])/g){
        $hash ^= $nmzphrase::Seed[($i++) & 3][ord($1)];
    }
    $self->seek($hash & 0xffff);

    %$list = ();
    my @tmp = ();
    if ($self->read(\@tmp)){
        for my $x (@tmp){
            $list->{$x} = 1;
        }
    }
    return scalar @tmp;
}


sub init_seed{
    return if scalar @nmzphrase::Seed;
    require 'seed.pl';
    @nmzphrase::Seed = &seed::init;
}

package nmzidx;
sub new{
    my $class = shift;
    my $dir = @_? shift: '.';
    my $mode = @_? shift: 'r';

    if ($mode =~ /[RS]/){
        return undef if -f "$dir/NMZ.lock";
        if (defined(my $fh = new IO::File ">$dir/NMZ.lock2")){
            $fh->print($$);
            $fh->close;
        }
    }

    my $self = {};
    bless $self, $class;

    $self->{'dir'} = $dir;
    $self->{'mode'} = $mode;
    return $self;
}

sub close{
    my $self = shift;
    unlink ($self->{'dir'} . "/NMZ.lock2") if $self->{'mode'} =~ /[RS]/;
}

sub open_field{
    my $self = shift;

    $self->{'field'} = new nmzfield() unless $self->{'field'};
    $self->{'field'}->open($self, @_);
    return $self->{'field'};
}

sub open_flist{
    my $self = shift;
    $self->{'flist'} = new nmzflist($self);
    return $self->{'flist'};
}

sub open_word{
    my $self = shift;
    $self->{'word'} = new nmzword($self);
    return $self->{'word'};
}

sub open_phrase{
    my $self = shift;
    return $self->{'phrase'} = new nmzphrase($self);
}

sub replace_db{
    my $self = shift;
    my $bak = @_? shift : 0;
    my $lock = $self->{'dir'} . "/NMZ.lock";

    if ($self->{'mode'} =~ /W/){
        my $fh = new IO::File($lock, 'w');
        $fh->close;
    }

    for my $path (keys %{$self->{'dblist'}}){
        $self->{'dblist'}->{$path}->close;
        if ($bak){
            unlink "$path.BAK" if (-f $path) && (-f "$path.BAK");
            rename $path, "$path.BAK";
        }
        unlink $path if (-f "$path.$$.tmp") && (-f $path);
        rename "$path.$$.tmp", $path;
    }
    unlink $lock if $self->{'mode'} =~ /W/;
}

sub remove_tmpdb{
    my $self = shift;

    for my $path (keys %{$self->{'dblist'}}){
        $self->{'dblist'}->{$path}->close;
        unlink "$path.$$.tmp";
    }
}

sub write_status{
    my $self = shift;
    my $in = shift;

    my $key = undef;
    $key = $self->{'word'}->{'size'} if defined $self->{'word'};
    my $key_comma = comma($key);

    my $file = undef;
    $file = $self->{'flist'}->{'valid'} if defined $self->{'flist'};
    my $file_comma = comma($file);

    if ($self->{'mode'} =~ /w/i){
        my $fi = &nmzlib::open_db($in, 'status');
        my $fo = &nmzlib::open_db($self, 'status');
        while (defined(my $line = $fi->getline)){
            $line = "files $file\n" if $line =~ /^files / && defined $file;
            $line = "keys $key\n" if $line =~ /^keys / && defined $key;
            $fo->print($line);
        }
        $fi->close;
        $fo->close;
        my $dh = new DirHandle($in->{'dir'});
        while (defined(my $ent = $dh->read)){
	    next if $ent =~ /\.(BAK|tmp)$/;
	    if ($ent =~ /^NMZ\.(head(?:\.[-\w\.]+)?)$/){
                $fi = &nmzlib::open_db($in, $1);
                $fo = &nmzlib::open_db($self, $1);

                while (defined(my $line = $fi->getline)){
                    $line =~ s/(\<\!-- FILE --\>).*?\1/$1 $file_comma $1/ if defined $file_comma;
                    $line =~ s/(\<\!-- KEY --\>).*?\1/$1 $key_comma $1/ if defined $key_comma;
                    $fo->print($line);
                }
                $fi->close;
                $fo->close;
            }
        }
        undef $dh;
    }
}

sub log_open{
    my $self = shift;
    my $tag = shift;
    my $path = $self->{'dir'} . "/NMZ.log";
    my $fh = new IO::File ">>$path";
    $self->{'log'} = $fh;
    if (defined $fh){
        binmode $fh;
        $fh->print("$tag\n") if defined $tag;
        $self->log_putline("Date:",  localtime($English::BASETIME) . "");
    }
    return $self->{'log'};
}

sub log_putline{
    my $self = shift;
    $self->{'log'}->printf("%-20s %s\n", @_);
}

sub log_close{
    my $self = shift;
    if (defined $self->{'log'}){
        $self->log_putline("Time (sec):", (time - $English::BASETIME));
        $self->log_putline("System:", $English::OSNAME);
        $self->log_putline("Perl:", sprintf("%f", $English::PERL_VERSION));
        $self->{'log'}->print("\n");
        $self->{'log'}->close;
    }
}


# copy from util.pl
sub comma ($) {
    my ($num) = @_;

    $num = "0" if ($num eq "");
#    1 while $num =~ s/(.*\d)(\d\d\d)/$1,$2/;
    # from Mastering Regular Expressions
    $num =~ s<\G((?:^-)?\d{1,3})(?=(?:\d\d\d)+(?!\d))><$1,>g;
    $num;
}
1;
