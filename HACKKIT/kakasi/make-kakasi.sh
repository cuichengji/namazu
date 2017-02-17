#!/bin/sh

PREFIX=c:/kakasi
BLD=kakasi-2.3.4

if test ! -d $BLD ; then
  gzip -cd $BLD.tar.gz | tar xvf -
fi
cd $BLD

export ac_cv_prog_LN_S=ln

if test ! -e config.cache ; then
  CC="cl -nologo" LD="lib -nologo" CFLAGS="-Gf -W3 -MD -O2" ./configure --prefix=$PREFIX --host=i386-windows --enable-shared=no
fi

make all
make install

mkdir -p $PREFIX/doc
cp -f doc/* $PREFIX/doc
mkdir -p $PREFIX/man/ja/man1
cp -f doc/kakasi.1 $PREFIX/man/ja/man1

sed -e "s/..//g" -e "s/.//g" doc/kakasi.cat > kakasi.cat.TEMPFILE
nkf -J -s -O kakasi.cat.TEMPFILE $PREFIX/kakasi.sjis
rm -f kakasi.cat.TEMPFILE

cp -f COPYING README README-ja NEWS ONEWS $PREFIX/

cd lib
  make clean
  make all 
# if test -f kakasi.def ; then
#   nmake -f makefile.msc 2>&1 | tee -a $LOGFILE
#   mkdir -p $PREFIX/lib
#   cp -f libkakasi.lib $PREFIX/lib
#   cp -f kakasi.lib kakasi.dll $PREFIX/lib
# else
  OBJS=`ls *.obj`
  lib -nologo -OUT:libkakasi.lib $OBJS
  mkdir -p $PREFIX/lib
  cp -f libkakasi.lib $PREFIX/lib
  echo "LIBRARY \"kakasi\"" > kakasi.def
  echo "EXPORTS" >> kakasi.def
  for F in $OBJS; do
   nm $F | grep 'T _' | sed 's/.* T _/ /' >> kakasi.def
  done
  cl -nologo -Gf -W3 -O2 -MD -LD -Fekakasi.dll $OBJS -link -def:kakasi.def
  mkdir -p $PREFIX/lib
  cp -f kakasi.lib kakasi.dll $PREFIX/lib
  rm -f kakasi.def
# fi
cd ..
