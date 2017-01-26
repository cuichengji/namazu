# Process this file with automake to produce Makefile.in
#
# $Id: Makefile.am,v 1.36.4.11 2007-05-09 14:37:52 opengl2772 Exp $
#

AUTOMAKE_OPTIONS = 1.4 no-dependencies

EXTRA_DIST = alloca.c memcmp.c memmove.c memset.c strcasecmp.c strncasecmp.c \
	     strcspn.c strerror.c vsnprintf.c system.h support.h \
	     nmzversion.c.in

CLEAN_FILES = nmzversion.c nmz.dll nmz.def nmz.lib nmz.exp

dll_libadd = @LTLIBINTL@

DLL_OBJ_FILES = alias.o codeconv.o field.o hlist.o i18n.o \
		idxname.o l10n-ja.o libnamazu.o nmzversion.o \
		parser.o query.o re.o regex.o replace.o \
		score.o search.o seed.o \
		list.o \
		util.o var.o wakati.o

localedir   = $(prefix)/$(DATADIRNAME)/locale
confdir     = $(sysconfdir)/$(PACKAGE)
indexdir    = $(localstatedir)/$(PACKAGE)/index

DEFS = -DLOCALEDIR=\"$(localedir)\" \
       -DOPT_CONFDIR=\"$(confdir)\" \
       -DOPT_INDEXDIR=\"$(indexdir)\" \
       -DHAVE_SUPPORT_H -DNO_ALLOCA \
       @DEFS@
INCLUDES = -I$(srcdir) -I.. -I$(srcdir)/../lib -I$(srcdir)/../src \
	-I$(top_builddir)/intl -I$(srcdir)/../nmz

pkginclude_HEADERS = codeconv.h field.h hlist.h i18n.h idxname.h \
	libnamazu.h l10n-ja.h parser.h query.h re.h regex.h \
	search.h score.h util.h var.h wakati.h list.h
lib_LTLIBRARIES = libnmz.la

libnmz_la_SOURCES = alias.c alias.h codeconv.c codeconv.h \
	field.c field.h hlist.c hlist.h i18n.c i18n.h \
	idxname.c idxname.h libnamazu.c libnamazu.h l10n-ja.c l10n-ja.h \
	parser.c parser.h query.c query.h re.c re.h replace.c replace.h \
	regex.c regex.h search.c search.h seed.c seed.h util.c util.h \
	var.c var.h wakati.c wakati.h score.c score.h \
	list.c list.h \
	nmzversion.c

libnmz_la_DEPENDENCIES = @NMZ_LIBOBJS@
libnmz_la_LIBADD = @LTLIBINTL@
libnmz_la_LDFLAGS = -version-info $(LTVERSION)

nmzversion.c: nmzversion.c.in
	rm -f nmzversion.c
	sed -e 's!%VERSION%!@VERSION@!g'  nmzversion.c.in > nmzversion.c.tmp
	mv nmzversion.c.tmp nmzversion.c

clean-generic:
	-rm -f $(CLEAN_FILES)

# Win32: nmz.dll (for MinGw)
dll: nmz.dll nmz.def

nmz.dll: $(DLL_OBJ_FILES)
	$(CC) -shared -Wl,--output-def,nmz.def,--out-implib,libnmz.a \
	-o nmz.dll $(DLL_OBJ_FILES) $(dll_libadd) $(LIBS)
	strip nmz.dll

nmz.def: $(DLL_OBJ_FILES)
	$(CC) -shared -Wl,--output-def,nmz.def,--out-implib,libnmz.a \
	-o nmz.dll $(DLL_OBJ_FILES) $(dll_libadd) $(LIBS)
	strip nmz.dll

# Win32: MSVC import libirary (need lib.exe)
implib: nmz.dll nmz.def
	lib /machine:i386 /def:nmz.def

##Bug in automake: Can't use `if MAINTAINER_MODE'
@MAINTAINER_MODE_TRUE@include $(srcdir)/maintMakefile
