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
# along with GNU Zile; see the file COPYING.  If not, write to the
# Free Software Foundation, Fifth Floor, 51 Franklin Street, Boston,
# MA 02111-1301, USA.

doc_DATA += src/dotzile.sample

AM_VALAFLAGS = $(VALA_REGEX_LARGE_OFFSETS) --no-color --pkg config --pkg gio-2.0 --pkg posix --pkg curses --pkg gnu --pkg astr --pkg estr --vapidir=$(srcdir)/src
AM_CFLAGS = --include config.h $(WARN_CFLAGS) $(LIBGC_CFLAGS) $(GLIB_CFLAGS)
AM_CPPFLAGS = -I$(builddir)/src -I$(srcdir)/src $(ISYSTEM)$(builddir)/lib $(ISYSTEM)$(srcdir)/lib -DPATH_DOCDIR="\"$(docdir)\""
LDADD = $(builddir)/lib/libgnu.a $(LIB_ACL) $(LIB_EACCESS) $(LIBINTL) $(CURSES_LIB) $(LIBGC_LIBS) $(GLIB_LIBS)

VAPIS = src/gnu.vapi					\
	src/getopt_long_fix.h				\
	src/astr.vapi					\
	src/estr.vapi

BUILT_SOURCES =						\
	src/tbl_bindings.vala				\
	src/tbl_opts.vala				\
	src/tbl_vars.vala				\
	src/dummy.vala

src/dummy.vala: $(VAPIS)
	touch $@

bin_PROGRAMS = src/zile

src_zile_LDADD = $(LDADD) $(LIBOBJS)

src_zile_SOURCE_FILES =					\
	src/memrmem.h					\
	src/memrmem.c					\
	src/astr.c					\
	src/astr.h					\
	src/estr.c					\
	src/estr.h					\
	src/basic.vala					\
	src/bind.vala					\
	src/buffer.vala					\
	src/completion.vala				\
	src/constants.vala				\
	src/editfns.vala				\
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
	src/lists.vala					\
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

check-syntax:
	$(COMPILE) -o /dev/null -S $(CHK_SOURCES)

check_PROGRAMS = src/astr

TESTS = $(check_PROGRAMS)

src_astr_CPPFLAGS = -DTEST -DSRCPATH="\"$(top_srcdir)/src\"" $(AM_CPPFLAGS)
src_astr_LDADD = $(LDADD) src/memrmem.o

EXTRA_DIST +=						\
	src/dotzile.sample				\
	src/tbl_bindings.pl				\
	$(VAPIS)
