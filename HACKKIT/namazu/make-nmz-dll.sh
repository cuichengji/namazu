#!/bin/sh

PREFIX=/namazu
BLD=namazu-2.0.12

if test ! -d $BLD ; then
	gzip -cd $BLD.tar.gz | tar xvf -
	cd $BLD
	if test -f ../$BLD-win32.patch ; then
		patch -p1 < ../$BLD-win32.patch
	fi
else
	cd $BLD
fi

export ac_cv_type_off_t=no
export ac_cv_header_dlfcn_h=no
export ac_cv_header_unistd_h=no
export ac_cv_header_nl_types_h=no
export ac_cv_header_sys_param_h=no

echo > nmz/vsnprintf.c

if test -z "`type cl 2>&1 | grep 'not found'`" ; then
	rm -f config.cache
	CC="cl" CFLAGS="-nologo -Gf -W3 -O1 -MD -DNO_ALLOCA -DMSVC" LD="lib -nologo" \
	./configure --prefix=$PREFIX --host=i386-windows --enable-shared=no --disable-nls
	cd lib
		make clean 
		make all 
		OBJS=`echo *.obj`
		lib -nologo -OUT:libnmzut.lib $OBJS
	cd ..

	cd nmz
		make clean 
		make all 
		OBJS=`echo *.obj`
		lib -nologo -OUT:libnmz.lib $OBJS
		mkdir -p $PREFIX/lib
		cp -f libnmz.lib $PREFIX/lib
		echo "LIBRARY \"nmz\"" > nmz.def
		echo "EXPORTS" >> nmz.def
		for F in $OBJS; do
			nm $F | grep 'T _' | sed 's/.* T _/ /' >> nmz.def
		done
		cp -f ../lib/libnmzut.lib .
		cl -nologo -Gf -W3 -O1 -MD -LD -Fenmz.dll $OBJS libnmzut.lib -link -def:nmz.def
		mkdir -p $PREFIX/lib
		cp -f libnmzut.lib nmz.lib nmz.dll $PREFIX/lib
		cp -f nmz.def ../
	cd ..
fi
