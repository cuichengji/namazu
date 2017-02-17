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

export TARGET=i386-mingw32
export ac_cv_path_WISH=c:/usr/tcl/bin/wish83
export ac_cv_path_LYNX=lynx
export ac_cv_path_NETSCAPE=netscape
export ac_cv_path_CHASEN=chasen
export ac_cv_prog_LN_S=ln

if test ! -e config.cache ; then
	CFLAGS=-O2 LIBS=-lintl ./configure --prefix=$PREFIX --datadir=$PREFIX/share --host=$TARGET --enable-tknamazu 
fi
if test -e intl/libintl.h ; then
	rm -f intl/libintl.h
	ln intl/libgettext.h intl/libintl.h
fi

sed -e "s/^#! %PERL% -w/#! %PERL% /" scripts/mknmz.in > scripts/mknmz.in.TEMPFILE
mv -f scripts/mknmz.in.TEMPFILE scripts/mknmz.in
sed -e "s/^\$ADDRESS = 'webmaster@.*$/\$ADDRESS = 'webmaster@foo.bar.jp';/" pl/conf.pl > pl/conf.pl.TEMPFILE
mv -f pl/conf.pl.TEMPFILE pl/conf.pl
sed -e "s/^<link rev=made href=\"mailto:webmaster@.*$/<link rev=made href=\"mailto:webmaster@foo.bar.jp\">/" template/NMZ.head > template/NMZ.head.TEMPFILE
mv -f template/NMZ.head.TEMPFILE template/NMZ.head
sed -e "s/^<a href=\"mailto:webmaster@.*$/<a href=\"mailto:webmaster@foo.bar.jp\">/" template/NMZ.foot > template/NMZ.foot.TEMPFILE
mv -f template/NMZ.foot.TEMPFILE template/NMZ.foot
sed -e "s/^<link rev=made href=\"mailto:webmaster@.*$/<link rev=made href=\"mailto:webmaster@foo.bar.jp\">/" template/NMZ.head.ja > template/NMZ.head.ja.TEMPFILE
mv -f template/NMZ.head.ja.TEMPFILE template/NMZ.head.ja
sed -e "s/^<a href=\"mailto:webmaster@.*$/<a href=\"mailto:webmaster@foo.bar.jp\">/" template/NMZ.foot.ja > template/NMZ.foot.ja.TEMPFILE
mv -f template/NMZ.foot.ja.TEMPFILE template/NMZ.foot.ja

make OPT_ADMIN_EMAIL=webmaster@foo.bar.jp 

if test -e src/namazu.exe ; then
	strip src/namazu.exe
	strip src/namazu.cgi*
else
	echo "Error: cannot make namazu.exe" 
	exit 1
fi

# make OPT_ADMIN_EMAIL=webmaster@foo.bar.jp check 
make OPT_ADMIN_EMAIL=webmaster@foo.bar.jp install 

touch $PREFIX/var/namazu/index/dummy

cd lisp
make 
mkdir -p $PREFIX/share/site-lisp/namazu
install -c namazu.el $PREFIX/share/site-lisp/namazu/namazu.el 
GNUSNMZ=`ls gnus-nmz*.el`
install -c $GNUSNMZ $PREFIX/share/site-lisp/namazu/$GNUSNMZ 
BROWSEURL=`ls browse-url-for-emacs*.el`
install -c $BROWSEURL $PREFIX/share/site-lisp/namazu/$BROWSEURL 
cd ..

cd ..
