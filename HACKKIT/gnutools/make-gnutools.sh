#!/bin/bash

export ac_cv_prog_LN_S=ln
export ac_cv_path_LD=ld

function make_program () {
	PROG=$1
	if test -d $PROG ; then
		return 1
	fi
	tar zxf src/$PROG.tar.gz
	cd $PROG
	patch -p1 < ../$PROG-win32.patch
	CFLAGS=-O2 ./configure --host=i386-mingw32 --prefix=/usr/mingw
	make
	make install
	cd ..
	hash -r
}

make_program m4-1.4
make_program automake-1.4
make_program autoconf-2.13
make_program libtool-1.3.5
make_program gettext-0.10.35
