## Process this file with automake to produce Makefile.in

## This is a part of Namazu.
## Copyright (C) 1997-1999, Satoru Takabayashi. All rights reserved.

## Original of this file was made by Mr. Fumiyasu SATO. Thanks.
## Modified by Satoru Takabayashi
## 'automake'ization by Hajime BABA <baba@kusastro.kyoto-u.ac.jp>
## Thanks to [Ryuji Abe <raeva@t3.rim.or.jp>] for many contribution

AUTOMAKE_OPTIONS = 1.4 no-dependencies

bin_SCRIPTS    = bnamazu gcnmz kwnmz mailutime mknmz nmzgrep rfnmz vfnmz lnnmz adnmz nmzmerge nmzegrep nmzcat
noinst_SCRIPTS = gtnmz

EXTRA_DIST = gcnmz.in kwnmz.in mknmz.in nmzmerge.in adnmz.in lnnmz.in gtnmz.in bnamazu.in mailutime.in nmzgrep.in rfnmz.in vfnmz.in nmzegrep.in nmzcat.in
CLEANFILES  = gcnmz mknmz kwnmz nmzmerge adnmz lnnmz gtnmz bnamazu mailutime nmzgrep rfnmz vfnmz nmzegrep nmzcat

confdir     = $(sysconfdir)/$(PACKAGE)

gcnmz: gcnmz.in Makefile
	rm -f gcnmz
	sed -e 's!%PERL%!$(PERL)!g' \
	    -e 's!@pkgdatadir@!$(pkgdatadir)!g' $(srcdir)/gcnmz.in > gcnmz.tmp
	mv gcnmz.tmp gcnmz
	chmod +x gcnmz

kwnmz: kwnmz.in Makefile
	rm -f kwnmz
	sed -e 's!%PERL%!$(PERL)!g' \
	    -e 's!@pkgdatadir@!$(pkgdatadir)!g' $(srcdir)/kwnmz.in > kwnmz.tmp
	mv kwnmz.tmp kwnmz
	chmod +x kwnmz

nmzmerge: nmzmerge.in Makefile
	rm -f nmzmerge
	sed -e 's!%PERL%!$(PERL)!g' \
	    -e 's!@pkgdatadir@!$(pkgdatadir)!g' $(srcdir)/nmzmerge.in > nmzmerge.tmp
	mv nmzmerge.tmp nmzmerge
	chmod +x nmzmerge

mknmz: mknmz.in Makefile
	rm -f mknmz
	sed -e 's!%PERL%!$(PERL)!g' \
	    -e 's!%ADDITIONAL_INC%!$(ADDITIONAL_INC)!g' \
	    -e 's!@pkgdatadir@!$(pkgdatadir)!g' \
	    -e 's!@CONFDIR@!$(confdir)!g' $(srcdir)/mknmz.in >mknmz.tmp 
	mv mknmz.tmp mknmz
	chmod +x mknmz

adnmz: adnmz.in Makefile
	rm -f adnmz
	sed -e 's!%PERL%!$(PERL)!g' \
	    -e 's!@pkgdatadir@!$(pkgdatadir)!g' $(srcdir)/adnmz.in > adnmz.tmp
	mv adnmz.tmp adnmz
	chmod +x adnmz

lnnmz: lnnmz.in Makefile
	rm -f lnnmz
	sed -e 's!%PERL%!$(PERL)!g' \
	    -e 's!@pkgdatadir@!$(pkgdatadir)!g' $(srcdir)/lnnmz.in > lnnmz.tmp
	mv lnnmz.tmp lnnmz
	chmod +x lnnmz

##

bnamazu: bnamazu.in Makefile
	rm -f $@
	sed -e 's!%PERL%!$(PERL)!g' \
	    -e 's!@pkgdatadir@!$(pkgdatadir)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

gtnmz: gtnmz.in Makefile
	rm -f $@
	sed -e 's!%PERL%!$(PERL)!g' \
	    -e 's!@pkgdatadir@!$(pkgdatadir)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

mailutime: mailutime.in Makefile
	rm -f $@
	sed -e 's!%PERL%!$(PERL)!g' \
	    -e 's!@pkgdatadir@!$(pkgdatadir)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

nmzgrep: nmzgrep.in Makefile
	rm -f $@
	sed -e 's!%PERL%!$(PERL)!g' \
	    -e 's!@pkgdatadir@!$(pkgdatadir)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

rfnmz: rfnmz.in Makefile
	rm -f $@
	sed -e 's!%PERL%!$(PERL)!g' \
	    -e 's!@pkgdatadir@!$(pkgdatadir)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

vfnmz: vfnmz.in Makefile
	rm -f $@
	sed -e 's!%PERL%!$(PERL)!g' \
	    -e 's!@pkgdatadir@!$(pkgdatadir)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

nmzegrep: nmzegrep.in Makefile
	rm -f $@
	sed -e 's!%PERL%!$(PERL)!g' \
	    -e 's!@pkgdatadir@!$(pkgdatadir)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@

nmzcat: nmzcat.in Makefile
	rm -f $@
	sed -e 's!%PERL%!$(PERL)!g' \
	    -e 's!@pkgdatadir@!$(pkgdatadir)!g' $(srcdir)/$@.in > $@.tmp
	mv $@.tmp $@
	chmod +x $@


ETAGS_ARGS = $(SCRIPTS) --lang=perl
TAGS_DEPENDENCIES = $(SCRIPTS)
