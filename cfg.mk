# Configuration for maintainer-makefile
#
# Copyright (c) 2011 Free Software Foundation, Inc.
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

GNULIB_SRCDIR ?= $(srcdir)/gnulib
gnulib_dir = $(GNULIB_SRCDIR)

# Set format of NEWS
old_NEWS_hash := ea89296935098b3fddd6cb1c708231f9

# Don't check test outputs or diff patches
VC_LIST_ALWAYS_EXCLUDE_REGEX = \.(output|diff)$$

# Don't send release announcements to Translation Project
translation_project_ =

local-checks-to-skip = \
	sc_bindtextdomain \
	sc_error_message_period \
	sc_error_message_uppercase \
	sc_unmarked_diagnostics

# Rationale:
#
# sc_{bindtextdomain,unmarked_diagnostics}: Zile isn't internationalised
# sc_error_message_{period,uppercase}: Emacs does these
