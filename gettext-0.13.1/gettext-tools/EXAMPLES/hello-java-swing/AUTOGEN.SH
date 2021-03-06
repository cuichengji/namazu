#!/bin/sh
# Example for use of GNU gettext.
# Copyright (C) 2003 Free Software Foundation, Inc.
# This file is in the public domain.
#
# Script for regenerating all autogenerated files.

test -r ../Makefile.am || . ../installpaths

cp -p ${ACLOCALDIR-../../../gettext-runtime/m4}/nls.m4 m4/nls.m4
cp -p ${ACLOCALDIR-../../../gettext-runtime/m4}/po.m4 m4/po.m4
cp -p ${GETTEXTSRCPODIR-../../../gettext-runtime/po}/remove-potcdate.sin po/remove-potcdate.sin

cp -p ${EXAMPLESCONFIGDIR-../../../gettext-tools/m4}/gcj.m4 m4/gcj.m4
cp -p ${EXAMPLESCONFIGDIR-../../../gettext-tools/m4}/javacomp.m4 m4/javacomp.m4
cp -p ${EXAMPLESCONFIGDIR-../../../gettext-tools/m4}/javaexec.m4 m4/javaexec.m4
cp -p ${EXAMPLESCONFIGDIR-../../../gettext-tools/lib}/javacomp.sh.in javacomp.sh.in
cp -p ${EXAMPLESCONFIGDIR-../../../gettext-tools/lib}/javaexec.sh.in javaexec.sh.in

aclocal -I m4

autoconf

automake -a -c

./configure
cd po
make update-po
cd ..
make distclean
