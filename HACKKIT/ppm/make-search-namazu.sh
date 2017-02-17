#!/bin/bash

TGT=Search-Namazu
BLD=Search-Namazu-0.92

PREFIX=/namazu
SYSLIBS=`echo -L$LIB | sed -e "s/\;$//" -e "s/\;/ -L/g"`

if test ! -f src/$BLD.tar.gz ; then
	cd src
	wget http://www.namazu.org/~knok/Search-Namazu-0.92.tar.gz
	cd ..
fi

if test ! -d $BLD ; then
	tar zxvf src/$BLD.tar.gz
fi
cd $BLD

make_program() {
	PERLPATH=$1
	DIR=$2

	$PERLPATH/perl Makefile.PL INC="-I$PREFIX/include" LIBS="-L$PREFIX/lib -llibnmz -llibnmzut $SYSLIBS" $3 

	sed -e 's#&&#\
		#' Makefile > Makefile.TEMPFILE
	mv -f Makefile.TEMPFILE Makefile

	nmake 
	nmake install
	tar --mode=644 -cvf $TGT.tar blib/*
	gzip --best $TGT.tar
	mv -f $TGT.tar.gz $DIR/x86
	nmake ppd
	sed -e 's#<ABSTRACT></ABSTRACT>#<ABSTRACT>Namazu library module for perl</ABSTRACT>#' -e 's#<AUTHOR></AUTHOR>#<AUTHOR>NOKUBI Takatsugu (knok@daionet.gr.jp)</AUTHOR>#' -e 's#<CODEBASE HREF="" />#<CODEBASE HREF="x86/Search-Namazu.tar.gz" />#' $TGT.ppd > $TGT.ppd.TEMPFILE
	mv -f $TGT.ppd.TEMPFILE $DIR/$TGT.ppd
	nmake clean
}

. ../build-package.sh

