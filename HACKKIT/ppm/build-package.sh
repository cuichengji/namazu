#!/bin/sh

if test ! -f ../build-package.sh ; then
	echo "Error: Don't excute this shell file."
	exit 1
fi

check_dir() {
	if test ! -d $1 ; then
		mkdir $1
	fi
}

check_dir "../ppm"
check_dir "../ppm/500"
check_dir "../ppm/500/x86"
check_dir "../ppm/600"
check_dir "../ppm/600/x86"

#
# 実行する環境によって、以下の行を書き換えて下さい。
#
make_program d:/usr/strawberry/perl/bin ../ppm/600 POLLUTE=1
#make_program d:/usr/perl5xx/bin ../ppm/500 CAPI=TRUE
