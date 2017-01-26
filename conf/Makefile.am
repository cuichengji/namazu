AUTOMAKE_OPTIONS = 1.4 no-dependencies

confdir = $(sysconfdir)/$(PACKAGE)
conf_DATA  = namazurc-sample mknmzrc-sample namazurc-sample.win32 mknmzrc-sample.win32
EXTRA_DIST = namazurc-sample namazurc-sample.win32
CLEANFILES = mknmzrc-sample mknmzrc-sample.win32

mknmzrc-sample: ../pl/conf.pl
	perl -pe 's/^/\x23 / unless /^(\x23|package|$$)/' ../pl/conf.pl | perl -pe 's/^#\[WIN\].*$$//s' > $@

mknmzrc-sample.win32: ../pl/conf.pl
	perl -pe 's/^/\x23 / unless /^(\x23|package|$$)/' ../pl/conf.pl | perl -pe 's/^#\[WIN\]\s+//' > $@
