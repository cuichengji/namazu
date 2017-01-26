# Process this file with automake to produce Makefile.in

man_MANS = namazu.1 mknmz.1 \
	adnmz.1 bnamazu.1 gcnmz.1 kwnmz.1 lnnmz.1 mailutime.1 \
	nmz-config.1 nmzcat.1 nmzgrep.1 nmzmerge.1 rfnmz.1 \
	tknamazu.1 vfnmz.1

man_aux = namazu.x mknmz.x

EXTRA_DIST = help2man $(man_MANS) $(man_aux)

MAINTAINERCLEANFILES = $(man_MANS)
HELP2MAN = $(PERL) -w -- $(srcdir)/help2man

namazu.1:
	@progname=`basename $@ .1`; \
	executable=$(top_builddir)/src/$$progname; \
	includes=$(srcdir)/$$progname.x; \
	if test -f $$executable; then \
	 rm -f t-$$progname.1; \
	 $(HELP2MAN) --include=$$includes --no-info \
	 $$executable > t-$$progname.1 || exit 1; \
	 mv t-$$progname.1 $$progname.1; \
	else \
	 echo "WARNING: The man page $@ cannot be updated yet."; \
	fi

mknmz.1:
	@progname=`basename $@ .1`; \
	executable=$(top_builddir)/scripts/$$progname; \
	includes=$(srcdir)/$$progname.x; \
	pkgdatadir=$(top_srcdir); \
	top_builddir=$(top_builddir); \
	export pkgdatadir;export top_builddir; \
	if test -f $$executable; then \
	 rm -f t-$$progname.1; \
	 $(HELP2MAN) --include=$$includes --no-info \
	 $$executable > t-$$progname.1 || exit 1; \
	 mv t-$$progname.1 $$progname.1; \
	else \
	 echo "WARNING: The man page $@ cannot be updated yet."; \
	fi
