#!/bin/bash

TGT=NKF
BLD=nkf192

if test ! -f src/$BLD.shar ; then
	cd src
	wget ftp://ftp.ie.u-ryukyu.ac.jp/pub/software/kono/nkf192.shar
	cd ..
fi

if test ! -d $BLD ; then
	mkdir $BLD
	cd $BLD
	mkdir NKF
	sh ../src/$BLD.shar
	patch < ../$BLD-win32.patch
	cd ..
fi
cd $BLD

make_program() {
	PERLPATH=$1
	DIR=$2

	cd NKF

	$PERLPATH/perl Makefile.PL $3

	sed -e 's#&&#\
		#' Makefile > Makefile.TEMPFILE
	mv -f Makefile.TEMPFILE Makefile

	nmake 
	nmake test
	nmake install
	tar --mode=644 -cvf $TGT.tar blib/*
	gzip --best $TGT.tar
	mv -f $TGT.tar.gz ../$DIR/x86
	nmake ppd
	sed -e 's#<ABSTRACT></ABSTRACT>#<ABSTRACT>NKF library module for perl</ABSTRACT>#' -e 's#<AUTHOR></AUTHOR>#<AUTHOR>Shinji Kono (kono@ie.u-ryukyu.ac.jp)</AUTHOR>#' -e 's#<CODEBASE HREF="" />#<CODEBASE HREF="x86/NKF.tar.gz" />#' $TGT.ppd > $TGT.ppd.TEMPFILE
	mv -f $TGT.ppd.TEMPFILE $TGT.ppd
	mv -f $TGT.ppd ../$DIR
	nmake clean

	cd ..
}

. ../build-package.sh
