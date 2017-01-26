## Process this file with automake to produce Makefile.in

AUTOMAKE_OPTIONS = 1.4 no-dependencies

ext_namazu=@NAMAZU@
ext_mknmz=@MKNMZ@

bin_SCRIPTS = tknamazu
pkgdata_DATA = tknamazu.hlp.en tknamazu.hlp.ja tknamazu.hlp.ja_JP.SJIS \
	tknamazu_icon.ppm tknamazu_logo.ppm mini-tknamazu.xpm mini-tknamazu.ico \
	tknamazurc

CLEANFILES = tknamazu

EXTRA_DIST = $(pkgdata_DATA) tknamazu.spec.in tknamazu.spec

tknamazu: tknamazu.tcl
	sed -e 's!%PKGDATADIR%!$(pkgdatadir)!g' \
		-e 's!%NAMAZU%!$(ext_namazu)!g' \
		-e 's!%MKNMZ%!$(ext_mknmz)!g' \
	tknamazu.tcl > $@
	chmod +x $@
