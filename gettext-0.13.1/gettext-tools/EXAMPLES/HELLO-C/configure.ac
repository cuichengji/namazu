dnl Example for use of GNU gettext.
dnl Copyright (C) 2003 Free Software Foundation, Inc.
dnl This file is in the public domain.
dnl
dnl Configuration file - processed by autoconf.

AC_INIT
AC_CONFIG_SRCDIR(hello.c)
AM_INIT_AUTOMAKE(hello-c, 0)

AC_PROG_CC
AC_CHECK_HEADERS([unistd.h])
AM_GNU_GETTEXT([external])
AM_GNU_GETTEXT_VERSION(0.12.1)

AC_CONFIG_FILES([Makefile])
AC_CONFIG_FILES([m4/Makefile])
AC_CONFIG_FILES([po/Makefile.in])
AC_OUTPUT
