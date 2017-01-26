## Process this file with automake to produce Makefile.in

AUTOMAKE_OPTIONS = 1.4 no-dependencies

localedir  = $(prefix)/$(DATADIRNAME)/locale
perllibdir = $(pkgdatadir)/pl

perllib_DATA = \
	codeconv.pl \
	conf.pl \
	gettext.pl \
	gfilter.pl \
	htmlsplit.pl \
	nmzidx.pl \
	seed.pl \
	usage.pl \
	util.pl \
	var.pl \
	wakati.pl \
	time.pl \
	document.pl \
	filter.pl \
	ext.pl \
	extzip.pl \
	extutf8.pl

# Slightly different from perllib_DATA because of *.in files.
EXTRA_DIST = $\
	codeconv.pl \
	conf.pl \
	gettext.pl.in \
	gfilter.pl \
	htmlsplit.pl \
	nmzidx.pl \
	seed.pl \
	usage.pl \
	util.pl \
	var.pl \
	wakati.pl \
	time.pl \
	document.pl \
	filter.pl.in \
	ext.pl \
	extzip.pl \
	extutf8.pl

CLEANFILES = gettext.pl filter.pl

gettext.pl: gettext.pl.in Makefile
	rm -f gettext.pl
	sed -e 's!@LOCALEDIR@!$(localedir)!g' \
	$(srcdir)/gettext.pl.in > gettext.pl

filter.pl: filter.pl.in Makefile
	rm -f filter.pl
	sed -e 's!@pkgdatadir@!$(pkgdatadir)!g' \
	$(srcdir)/filter.pl.in > filter.pl.tmp
	mv filter.pl.tmp filter.pl

ETAGS_ARGS = $(perllib_DATA) --lang=perl
TAGS_DEPENDENCIES = $(perllib_DATA)
