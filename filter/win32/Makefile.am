## Process this file with automake to produce Makefile.in

AUTOMAKE_OPTIONS = 1.4 no-dependencies

filterdir = $(pkgdatadir)/filter/win32

filter_DATA = olemsword.pl \
	     oleexcel.pl \
	     olepowerpoint.pl \
	     ichitaro456.pl \
	     oletaro.pl \
	     olertf.pl \
	     olevisio.pl \
             xdoc2txt.pl

EXTRA_DIST = $(filter_DATA)

ETAGS_ARGS = $(filter_DATA) --lang=perl
TAGS_DEPENDENCIES = $(filter_DATA)
