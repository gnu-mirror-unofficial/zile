# Top-level Makefile.am
#
# Copyright (c) 1997-2020 Free Software Foundation, Inc.
#
# This file is part of GNU Zile.
#
# GNU Zile is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3, or (at your option)
# any later version.
#
# GNU Zile is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, see <https://www.gnu.org/licenses/>.

CLOC = cloc --force-lang="C",h --autoconf

SUBDIRS = lib .

ACLOCAL_AMFLAGS = -I m4
AUTOMAKE_OPTIONS = subdir-objects

DISTCLEANFILES =
MAINTAINERCLEANFILES =

PERL_BUILDTIME =					\
	build-aux/mkbindings.pl				\
	build-aux/mkvars.pl				\
	build-aux/asan-suppressions.txt

EXTRA_DIST =						\
	FAQ						\
	build-aux/zile-help2man-wrapper			\
	$(PERL_BUILDTIME)

doc_DATA = AUTHORS FAQ NEWS

include doc/Makefile.am
include src/Makefile.am
include tests/Makefile.am

PRODUCTIONSOURCES =					\
	configure.ac					\
	Makefile.am					\
	$(PERL_BUILDTIME)				\
	doc/Makefile.am					\
	src/Makefile.am					\
	$(src_zile_SOURCE_FILES)			\
	$(VAPIS)

loc:
	cd $(srcdir) &&					\
	$(CLOC) $(PRODUCTIONSOURCES)

loc-all:
	cd $(srcdir) &&					\
	$(CLOC) $(PRODUCTIONSOURCES) $(LISP_ALL_TESTS) $(srcdir)/tests/run-lisp-tests.pl

prerelease:
	{ $(MAKE) -k maintainer-clean || { ./configure && $(MAKE) maintainer-clean; } } && \
	git checkout HEAD && \
	git pull && \
	git diff --exit-code && \
	git push && \
	./bootstrap && ./configure && \
	$(MAKE) check distcheck

## ------------- ##
## Distribution. ##
## ------------- ##

distcheck-hook: syntax-check

dorelease:
	git push origin master tag v$$(cat .prev-version)
	woger gnu

## An empty target to depend on when a rule needs to always run
## whenever it is visited.
.FORCE:
