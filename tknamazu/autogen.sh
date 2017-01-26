#!/bin/sh

[ -f configure.in ] || {
  echo "autogen.sh: run this command only at the top of a TkNamazu source tree."
  exit 1
}

DIE=0

(autoconf --version) < /dev/null > /dev/null 2>&1 || {
  echo
  echo "You must have autoconf installed to compile TkNamazu."
  echo "Get ftp://ftp.gnu.org/pub/gnu/autoconf/autoconf-2.13.tar.gz"
  echo "(or a newer version if it is available)"
  DIE=1
  NO_AUTOCONF=yes
}

(automake --version) < /dev/null > /dev/null 2>&1 || {
  echo
  echo "You must have automake installed to compile TkNamazu."
  echo "Get ftp://ftp.gnu.org/pub/gnu/automake/automake-1.4.tar.gz"
  echo "(or a newer version if it is available)"
  DIE=1
  NO_AUTOMAKE=yes
}

# if no automake, don't bother testing for aclocal
test -n "$NO_AUTOMAKE" || (aclocal --version) < /dev/null > /dev/null 2>&1 || {
  echo
  echo "**Error**: Missing \`aclocal'.  The version of \`automake'"
  echo "installed doesn't appear recent enough."
  echo "Get ftp://ftp.gnu.org/pub/gnu/automake/automake-1.4.tar.gz"
  echo "(or a newer version if it is available)"
  DIE=1
}

# if no autoconf, don't bother testing for autoheader
test -n "$NO_AUTOCONF" || (autoheader --version) < /dev/null > /dev/null 2>&1 || {
  echo
  echo "**Error**: Missing \`autoheader'.  The version of \`autoheader'"
  echo "installed doesn't appear recent enough."
  echo "Get ftp://ftp.gnu.org/pub/gnu/autoconf/autoconf-2.13.tar.gz"
  echo "(or a newer version if it is available)"
  DIE=1
}

if test "$DIE" -eq 1; then
        exit 1
fi

echo "Generating configure script and Makefiles for TkNamazu."

echo "Running aclocal ..."
aclocal -I .
echo "Running automake ..."
automake
echo "Running autoconf ..."
autoconf

[ -f ../configure ] || {
  echo "Configuring TkNamazu."
  conf_flags="" #--enable-maintainer-mode
  echo Running $./configure $conf_flags "$@" ...
  ./configure $conf_flags "$@"
  echo "Now type 'make' to compile TkNamazu."
}
