htmldir = $(pkgdatadir)/doc/ja

html_DATA  = manual.html nmz.html tips.html tutorial.html
EXTRA_DIST = $(html_DATA)

# htmlint <http://openlab.ring.gr.jp/k16/htmllint/htmllint.html>
lint: $(html_DATA)
	@for target in $?; do \
		perl -le "print STDERR '$$target'"; \
		htmllint -d ct,nae -nobanner -noscore -noaccessibility \
		-noreligious $$target; \
	done
	@echo "linted:" `date` > $@

