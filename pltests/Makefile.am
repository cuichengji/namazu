## Process this file with automake to produce Makefile.in

AUTOMAKE_OPTIONS = 1.4 no-dependencies

LOG = test-log
INDEX = idx1 idx2 idx3 idx4 idx5 idx6 idx7 idx8 idx9 idx10 idx12 idx13 idx15 idx17 idx18 idx19 idx20 idx21 \
	idx101 idx102 idx111 idx112 idx121 idx122
TMPDATA = tmp-data
PROGRAM = alltests.pl pltests.pl \
        env.pl \
	mknmz-1.pl mknmz-2.pl mknmz-4.pl \
	mknmz-5.pl mknmz-6.pl mknmz-7.pl mknmz-8.pl \
	mknmz-10.pl mknmz-12.pl \
	mknmz-14.pl mknmz-15.pl mknmz-16.pl mknmz-17.pl mknmz-18.pl \
	gcnmz-1.pl idxdiff-1.pl idxdiff-3.pl \
	namazu-1.pl namazu-2.pl namazu-3.pl namazu-4.pl \
	namazu-5.pl namazu-6.pl \
	namazu-7.pl namazu-8.pl namazu-9.pl \
	namazu-10.pl namazu-11.pl namazu-12.pl \
	namazu-cgi-1.pl namazu-cgi-2.pl \
	namazu-cgi-3.pl namazu-cgi-4.pl \
	namazu-cgi-5.pl \
	namazu-cgi-7.pl namazu-cgi-8.pl \
	namazu-cgi-9.pl namazu-cgi-10.pl \
	namazu-cgi-12.pl \
	ja-namazu-cgi-3.pl \
	chasen-1.pl chasen-2.pl chasen-3.pl \
	mecab-1.pl mecab-2.pl mecab-3.pl \
	kakasi-1.pl kakasi-2.pl kakasi-3.pl

noinst_SCRIPTS = $(PROGRAM)

EXTRA_DIST = pltests.pl.in \
	alltests.pl.in \
        env.pl.in \
	mknmz-1.pl.in mknmz-2.pl.in mknmz-4.pl.in \
	mknmz-5.pl.in mknmz-6.pl.in mknmz-7.pl.in mknmz-8.pl.in \
	mknmz-10.pl.in mknmz-12.pl.in \
	mknmz-14.pl.in mknmz-15.pl.in \
	mknmz-16.pl.in mknmz-17.pl.in mknmz-18.pl.in \
	gcnmz-1.pl.in idxdiff-1.pl.in idxdiff-3.pl.in \
	namazu-1.pl.in namazu-2.pl.in namazu-3.pl.in namazu-4.pl.in \
	namazu-5.pl.in namazu-6.pl.in \
	namazu-7.pl.in namazu-8.pl.in namazu-9.pl.in \
	namazu-10.pl.in namazu-11.pl.in namazu-12.pl.in \
	namazu-cgi-1.pl.in namazu-cgi-2.pl.in \
	namazu-cgi-3.pl.in namazu-cgi-4.pl.in \
	namazu-cgi-5.pl.in \
	namazu-cgi-7.pl.in namazu-cgi-8.pl.in \
	namazu-cgi-9.pl.in namazu-cgi-10.pl.in \
	namazu-cgi-12.pl.in \
	ja-namazu-cgi-3.pl.in \
	chasen-1.pl.in chasen-2.pl.in chasen-3.pl.in \
	mecab-1.pl.in mecab-2.pl.in mecab-3.pl.in \
	kakasi-1.pl.in kakasi-2.pl.in kakasi-3.pl.in

#CLEANFILES = $(LOG) $(INDEX) $(TMPDATA) $(PROGRAM)

all: $(PROGRAM)

test: $(PROGRAM) 
	@$(PERL) alltests.pl

distclean: clean

clean:
	@-rm -rf $(LOG) $(INDEX) $(TMPDATA) $(PROGRAM)

alltests.pl: alltests.pl.in pltests.pl Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

pltests.pl: pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' \
	    -e 's!@pkgdatadir@!$(pkgdatadir)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@

env.pl: env.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

mknmz-1.pl: mknmz-1.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

mknmz-2.pl: mknmz-2.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

mknmz-3.pl: mknmz-3.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

mknmz-4.pl: mknmz-4.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

mknmz-5.pl: mknmz-5.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

mknmz-6.pl: mknmz-6.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

mknmz-7.pl: mknmz-7.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

mknmz-8.pl: mknmz-8.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

mknmz-10.pl: mknmz-10.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

mknmz-12.pl: mknmz-12.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

mknmz-14.pl: mknmz-14.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

mknmz-15.pl: mknmz-15.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

mknmz-16.pl: mknmz-16.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

mknmz-17.pl: mknmz-17.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

mknmz-18.pl: mknmz-18.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

gcnmz-1.pl: gcnmz-1.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

idxdiff-1.pl: idxdiff-1.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

idxdiff-2.pl: idxdiff-2.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

idxdiff-3.pl: idxdiff-3.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

namazu-1.pl: namazu-1.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

namazu-2.pl: namazu-2.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

namazu-3.pl: namazu-3.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

namazu-4.pl: namazu-4.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

namazu-5.pl: namazu-5.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

namazu-6.pl: namazu-6.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

namazu-7.pl: namazu-7.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

namazu-8.pl: namazu-8.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

namazu-9.pl: namazu-9.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

namazu-10.pl: namazu-10.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

namazu-11.pl: namazu-11.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

namazu-12.pl: namazu-12.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

namazu-cgi-1.pl: namazu-cgi-1.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

namazu-cgi-2.pl: namazu-cgi-2.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

namazu-cgi-3.pl: namazu-cgi-3.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

namazu-cgi-4.pl: namazu-cgi-4.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

namazu-cgi-5.pl: namazu-cgi-5.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

namazu-cgi-7.pl: namazu-cgi-7.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

namazu-cgi-8.pl: namazu-cgi-8.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

namazu-cgi-9.pl: namazu-cgi-9.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

namazu-cgi-10.pl: namazu-cgi-10.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

namazu-cgi-12.pl: namazu-cgi-12.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

ja-namazu-cgi-3.pl: ja-namazu-cgi-3.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

chasen-1.pl: chasen-1.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

chasen-2.pl: chasen-2.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

chasen-3.pl: chasen-3.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

mecab-1.pl: mecab-1.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

mecab-2.pl: mecab-2.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

mecab-3.pl: mecab-3.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

kakasi-1.pl: kakasi-1.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

kakasi-2.pl: kakasi-2.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

kakasi-3.pl: kakasi-3.pl.in pltests.pl.in Makefile
	sed -e 's!%PERL%!$(PERL)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

ETAGS_ARGS = $(PROGRAM) --lang=perl
TAGS_DEPENDENCIES = $(PROGRAM)
