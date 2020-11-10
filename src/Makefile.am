# Source Makefile.am
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

doc_DATA += src/dotzile.sample

AM_VALAFLAGS = --debug --no-color --vapidir=$(srcdir)/src
AM_CFLAGS = --include config.h $(WARN_CFLAGS) $(GLIB_CFLAGS)
AM_CPPFLAGS = -I$(builddir)/src -I$(srcdir)/src -I$(builddir)/lib -I$(srcdir)/lib -DPATH_DOCDIR="\"$(docdir)\""
LDADD = $(builddir)/lib/libgnu.a $(LIB_EACCESS) $(LIBINTL) $(CURSES_LIB) $(GLIB_LIBS)

VAPIS =	src/config.vapi					\
	src/memrmem.vapi				\
	src/getopt_long_fix.h

BUILT_VAPIS = src/estr.vapi

BUILT_SOURCES =						\
	src/tbl_bindings.vala				\
	src/tbl_opts.vala				\
	src/tbl_vars.vala				\
	src/estr.h					\
	src/dummy.vala

src/dummy.vala: $(VAPIS) $(BUILT_VAPIS)
	touch $@

bin_PROGRAMS = src/zile

noinst_LIBRARIES = src/libestr.a
src_libestr_a_SOURCES = src/estr.vala
src_libestr_a_VALAFLAGS = $(AM_VALAFLAGS) --pkg posix --pkg gnu --pkg memrmem --library estr --header src/estr.h --vapi=src/estr.vapi
src_libestr_a_LIBADD = src/memrmem.o

# The following rule is copied from that generated for src/estr.c, with an
# extra mv to put the output in the right place, because passing --output to
# valac causes it to write estr.c in a subdirectory. (It would prefer a
# recursive build system!)
$(srcdir)/src/estr.vapi: $(srcdir)/src_libestr_a_vala.stamp
	@if test -f $@; then :; else rm -f $(srcdir)/src_libestr_a_vala.stamp; fi
	@if test -f $@; then :; else \
	  $(MAKE) $(AM_MAKEFLAGS) $(srcdir)/src_libestr_a_vala.stamp; \
	fi

src_zile_VALAFLAGS = $(AM_VALAFLAGS) -D _REGEX_LARGE_OFFSETS --pkg config --pkg gee-0.8 --pkg gio-2.0 --pkg posix --pkg curses --pkg gnu --pkg estr --pkg memrmem
src_zile_LDADD = $(LDADD) $(LIBOBJS) src/libestr.a

src_zile_SOURCE_FILES =					\
	src/memrmem.h					\
	src/memrmem.c					\
	src/basic.vala					\
	src/bind.vala					\
	src/buffer.vala					\
	src/completion.vala				\
	src/eval.vala					\
	src/file.vala					\
	src/funcs.vala					\
	src/help.vala					\
	src/killring.vala				\
	src/getkey.vala					\
	src/history.vala				\
	src/keycode.vala				\
	src/line.vala					\
	src/lisp.vala					\
	src/macro.vala					\
	src/main.vala					\
	src/marker.vala					\
	src/minibuf.vala				\
	src/redisplay.vala				\
	src/region.vala					\
	src/registers.vala				\
	src/search.vala					\
	src/shell.vala					\
	src/term_curses.vala				\
	src/term_minibuf.vala				\
	src/term_redisplay.vala				\
	src/undo.vala					\
	src/variables.vala				\
	src/window.vala

src_zile_SOURCES =					\
	$(src_zile_SOURCE_FILES)			\
	$(BUILT_SOURCES)

src/tbl_bindings.vala: src/tbl_bindings.pl build-aux/mkbindings.pl build-aux/Zile.pm
	PACKAGE_NAME="$(PACKAGE_NAME)" $(PERL) -I$(srcdir)/build-aux $(srcdir)/build-aux/mkbindings.pl $(srcdir)/src/tbl_bindings.pl

src/dotzile.sample: src/tbl_vars.vala build-aux/mkvars.pl build-aux/Zile.pm
	PACKAGE="$(PACKAGE)" $(PERL) -I$(srcdir)/build-aux $(srcdir)/build-aux/mkvars.pl $(srcdir)/src/tbl_vars.vala

DISTCLEANFILES +=					\
	$(BUILT_SOURCES)

check_PROGRAMS = src/estr-test

TESTS = $(check_PROGRAMS)

src_estr_test_SOURCES = src/estr-test.vala
src_estr_test_VALAFLAGS = $(AM_VALAFLAGS) --pkg posix --pkg estr
src_estr_test_LDADD = src/libestr.a $(LDADD)

EXTRA_DIST +=						\
	src/dotzile.sample				\
	src/tbl_bindings.pl				\
	src/estr-test.vala				\
	src/estr.h					\
	$(VAPIS)					\
	$(BUILT_VAPIS)
