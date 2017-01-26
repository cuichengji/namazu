## Process this file with automake to produce Makefile.in
AUTOMAKE_OPTIONS = 1.4 no-dependencies
SUBDIRS = en ja

cssdir = $(pkgdatadir)/doc

css_DATA   = namazu.css
EXTRA_DIST = $(css_DATA)

##Bug in automake: Can't use `if MAINTAINER_MODE'
@MAINTAINER_MODE_TRUE@include $(srcdir)/maintMakefile
