## Process this file with automake to produce Makefile.in

AUTOMAKE_OPTIONS = 1.4 no-dependencies

if BUILD_TKNAMAZU
BUILT_TKNAMAZU = tknamazu
DIST_TKNAMAZU =
else
BUILT_TKNAMAZU =
DIST_TKNAMAZU = tknamazu
endif

SUBDIRS = m4 conf doc etc filter po lib nmz pl src lisp scripts man \
	  tests pltests template contrib $(BUILT_TKNAMAZU)

DIST_SUBDIRS = m4 conf doc etc filter po lib nmz pl src lisp scripts man \
	  tests pltests template contrib $(BUILT_TKNAMAZU)


bin_SCRIPTS = nmz-config

etcdir     = $(pkgdatadir)/etc
etc_DATA   = AUTHORS ChangeLog ChangeLog.1 CREDITS COPYING INSTALL \
	     INSTALL-ja README README-es README-ja NEWS THANKS TODO \
	     HACKING HACKING-ja

EXTRA_DIST = $(etc_DATA) maintMakefile namazu.spec namazu.spec.in \
	     config.rpath mkinstalldirs


#EXTRA_DIRS = $(DIST_TKNAMAZU) File-MMagic
EXTRA_DIRS = $(DIST_TKNAMAZU)

install-data-local:
	$(mkinstalldirs) $(DESTDIR)$(localstatedir)/$(PACKAGE)/index

dist-hook:
	for subdir in $(EXTRA_DIRS); do \
	    cp -rp $$subdir $(distdir)/$$subdir; \
	    rm -f $(distdir)/$$subdir/*~; \
	    rm -f $(distdir)/$$subdir/*.{bak,orig}; \
	    rm -f $(distdir)/$$subdir/.cvsignore; \
	    rm -f $(distdir)/$$subdir/autogen.sh; \
	    rm -rf $(distdir)/$$subdir/autom4te.cache; \
	    rm -rf $(distdir)/$$subdir/CVS; \
	    rm -rf $(distdir)/$$subdir/*/CVS; \
	done

##Bug in automake: Can't use `if MAINTAINER_MODE'
@MAINTAINER_MODE_TRUE@include $(srcdir)/maintMakefile

ACLOCAL_AMFLAGS = -I m4
