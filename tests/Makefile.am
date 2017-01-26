## Process this file with automake to produce Makefile.in
AUTOMAKE_OPTIONS = 1.4 no-dependencies
SUBDIRS = data

TESTS_ENVIRONMENT = top_srcdir=$(top_srcdir) top_builddir=$(top_builddir) \
		    pkgdatadir=$(top_srcdir) MKNMZNORC= NAMAZUNORC=ALL

TESTS =	mknmz-1 mknmz-2 mknmz-3 mknmz-4 mknmz-5 \
	mknmz-6 mknmz-7 mknmz-8 mknmz-9 mknmz-10 \
	mknmz-11 mknmz-12 mknmz-13 mknmz-14 mknmz-15 \
	mknmz-16 mknmz-17 mknmz-18 mknmz-19 \
	gcnmz-1 \
	idxdiff-1 idxdiff-2 idxdiff-3 \
	namazu-1 namazu-2 namazu-3 namazu-4 namazu-5 \
	namazu-6 namazu-7 namazu-8 namazu-9 namazu-10 \
	namazu-11 namazu-12 namazu-13 \
	namazu-cgi-1 namazu-cgi-2 namazu-cgi-3 namazu-cgi-4 \
	namazu-cgi-5 namazu-cgi-6 namazu-cgi-7 namazu-cgi-8 \
	namazu-cgi-9 namazu-cgi-10 namazu-cgi-11 \
	ja-mknmz-1 ja-namazu-cgi-1 \
	ja-namazu-cgi-3 ja-namazu-1

distclean: clean-local

clean-local:
	rm -rf test-log tmp-data tmp.* idx[0-9]* ja-idx[0-9]*

EXTRA_DIST = $(TESTS) select-data commonfuncs
