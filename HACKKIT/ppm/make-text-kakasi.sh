#!/bin/bash

TGT=Text-Kakasi
BLD=$TGT-1.05

if test ! -f src/$BLD.tar.gz ; then
	cd src
	wget http://www.daionet.gr.jp/~knok/kakasi/Text-Kakasi-1.05.tar.gz
	cd ..
fi

if test ! -d $BLD ; then
	tar xvzf src/$BLD.tar.gz
	cd $BLD
	patch < ../$BLD-win32.patch
else
	cd $BLD
fi

make_program() {
	PERLPATH=$1
	DIR=$2

	if test -f Makefile ; then
		nmake clean
		rm -f Makefile.old
	fi

	$PERLPATH/perl Makefile.PL $3 
	if test $DIR = ../500 ; then
		sed -e 's#OTHERLDFLAGS =#OTHERLDFLAGS = kernel32.lib#' Makefile > Makefile.TEMPFILE
		mv -f Makefile.TEMPFILE Makefile
	fi
	sed -e 's#&&#\
		#' Makefile > Makefile.TEMPFILE
	mv -f Makefile.TEMPFILE Makefile

	nmake 
	nmake test
	nmake install
	tar --mode=644 -cvf $TGT.tar blib/*
	gzip --best $TGT.tar
	mv -f $TGT.tar.gz $DIR/x86
	nmake ppd
	sed -e 's#<CODEBASE HREF="" />#<CODEBASE HREF="x86/Text-Kakasi.tar.gz" />#' $TGT.ppd > $TGT.ppd.TEMPFILE
	mv -f $TGT.ppd.TEMPFILE $TGT.ppd
	mv -f $TGT.ppd $DIR
}

. ../build-package.sh

