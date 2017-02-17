#!/bin/bash

TGT=File-MMagic
BLD=$TGT-1.30

if test ! -f src/$BLD.tar.gz ; then
	cd src
	wget http://www.cpan.org/authors/id/K/KN/KNOK/File-MMagic-1.30.tar.gz
	cd ..
fi

if test ! -d $BLD ; then
	tar xvzf src/$BLD.tar.gz
fi
cd $BLD

make_program() {
	PERLPATH=$1
	DIR=$2

	$PERLPATH/perl Makefile.PL $3

	dmake
	nm test
	nm install
	tar --mode=644 -cvf $TGT.tar blib/*
	gzip --best $TGT.tar
	mv -f $TGT.tar.gz $DIR/x86
	nm ppd
	sed -e 's#<ABSTRACT></ABSTRACT>#<ABSTRACT>Guess file type from contents</ABSTRACT>#' -e 's#<AUTHOR></AUTHOR>#<AUTHOR>NOKUBI Takatsugu (knok@daionet.gr.jp)</AUTHOR>#' -e 's#<CODEBASE HREF="" />#<CODEBASE HREF="x86/File-MMagic.tar.gz" />#' $TGT.ppd > $TGT.ppd.TEMPFILE
	mv -f $TGT.ppd.TEMPFILE $TGT.ppd
	mv -f $TGT.ppd $DIR
	nm clean
}

. ../build-package.sh

