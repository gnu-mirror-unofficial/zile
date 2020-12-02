# Tests Makefile.am
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

ZILE_CMD = $(builddir)/src/zile$(EXEEXT)

TEST_EXTENSIONS = .el
EL_LOG_COMPILER = $(PERL) $(srcdir)/tests/run-lisp-test.pl

TESTS += $(LISP_TESTS) $(LISP_TESTS_ZILE_ONLY)

TERM ?= vt100

LISP_TESTS =						\
	%D%/backward-char.el				\
	%D%/backward-delete-char.el			\
	%D%/backward-kill-word.el			\
	%D%/backward-paragraph.el			\
	%D%/backward-sexp.el				\
	%D%/backward-word.el				\
	%D%/beginning-of-buffer.el			\
	%D%/beginning-of-line.el			\
	%D%/capitalize-word.el				\
	%D%/copy-region-as-kill.el			\
	%D%/copy-to-register.el				\
	%D%/delete-blank-lines.el			\
	%D%/delete-char.el				\
	%D%/delete-horizontal-space.el			\
	%D%/delete-region.el				\
	%D%/describe-bindings.el			\
	%D%/describe-function.el			\
	%D%/describe-key.el				\
	%D%/describe-variable.el			\
	%D%/downcase-region.el				\
	%D%/downcase-word.el				\
	%D%/end-of-buffer.el				\
	%D%/end-of-line.el				\
	%D%/exchange-point-and-mark.el			\
	%D%/fill-paragraph.el				\
	%D%/find-file.el				\
	%D%/find-file-read-only.el			\
	%D%/forward-char.el				\
	%D%/forward-line.el				\
	%D%/forward-paragraph.el			\
	%D%/forward-sexp.el				\
	%D%/forward-word.el				\
	%D%/goto-char.el				\
	%D%/goto-line.el				\
	%D%/indent-for-tab-command.el			\
	%D%/indent-relative.el				\
	%D%/insert-buffer.el				\
	%D%/insert-char.el				\
	%D%/insert-file.el				\
	%D%/just-one-space.el				\
	%D%/kill-buffer.el				\
	%D%/kill-line.el				\
	%D%/kill-region.el				\
	%D%/kill-sexp.el				\
	%D%/kill-word.el				\
	%D%/list-registers.el				\
	%D%/mark-paragraph.el				\
	%D%/mark-sexp.el				\
	%D%/mark-whole-buffer.el			\
	%D%/mark-word.el				\
	%D%/newline-and-indent.el			\
	%D%/newline.el					\
	%D%/next-line.el				\
	%D%/open-line.el				\
	%D%/previous-line.el				\
	%D%/quit.el					\
	%D%/search-backward.el				\
	%D%/search-backward-regexp.el			\
	%D%/search-forward.el				\
	%D%/search-forward-regexp.el			\
	%D%/set-fill-column.el				\
	%D%/setq_nonexistent_variable.el		\
	%D%/set-variable.el				\
	%D%/shell-command.el				\
	%D%/shell-command-on-region.el			\
	%D%/switch-to-buffer.el				\
	%D%/tab-to-tab-stop.el				\
	%D%/toggle-read-only.el				\
	%D%/transpose-chars.el				\
	%D%/transpose-lines.el				\
	%D%/transpose-sexps.el				\
	%D%/transpose-words.el				\
	%D%/upcase-region.el				\
	%D%/upcase-word.el				\
	%D%/yank.el					\
	%D%/interactive/backward-paragraph.el		\
	%D%/interactive/backward-sexp.el		\
	%D%/interactive/beginning-of-buffer.el		\
	%D%/interactive/beginning-of-line.el		\
	%D%/interactive/capitalize-word.el		\
	%D%/interactive/cd.el				\
	%D%/interactive/copy-region-as-kill.el		\
	%D%/interactive/copy-to-register.el		\
	%D%/interactive/delete-blank-lines.el		\
	%D%/interactive/delete-char.el			\
	%D%/interactive/delete-horizontal-space.el	\
	%D%/interactive/delete-region.el		\
	%D%/interactive/describe-bindings.el		\
	%D%/interactive/describe-function.el		\
	%D%/interactive/describe-key.el			\
	%D%/interactive/describe-variable.el		\
	%D%/interactive/downcase-word.el		\
	%D%/interactive/end-of-buffer.el		\
	%D%/interactive/exchange-point-and-mark.el	\
	%D%/interactive/execute-extended-command.el	\
	%D%/interactive/find-file.el			\
	%D%/interactive/find-file-read-only.el		\
	%D%/interactive/forward-char.el			\
	%D%/interactive/forward-paragraph.el		\
	%D%/interactive/forward-sexp.el			\
	%D%/interactive/forward-word.el			\
	%D%/interactive/global-set-key.el		\
	%D%/interactive/goto-line.el			\
	%D%/interactive/indent-for-tab-command.el	\
	%D%/interactive/insert-file.el			\
	%D%/interactive/isearch-backward.el		\
	%D%/interactive/isearch-backward-regexp.el	\
	%D%/interactive/isearch-forward.el		\
	%D%/interactive/isearch-forward-regexp.el	\
	%D%/interactive/just-one-space.el		\
	%D%/interactive/kill-buffer.el			\
	%D%/interactive/kill-line.el			\
	%D%/interactive/kill-region.el			\
	%D%/interactive/kill-sexp.el			\
	%D%/interactive/kill-word.el			\
	%D%/interactive/list-registers.el		\
	%D%/interactive/mark-paragraph.el		\
	%D%/interactive/mark-sexp.el			\
	%D%/interactive/mark-whole-buffer.el		\
	%D%/interactive/mark-word.el			\
	%D%/interactive/newline-and-indent.el		\
	%D%/interactive/newline.el			\
	%D%/interactive/open-line.el			\
	%D%/interactive/prefix-argument.el		\
	%D%/interactive/query-replace.el		\
	%D%/interactive/quoted-insert.el		\
	%D%/interactive/resume_search.el		\
	%D%/interactive/save-some-buffers.el		\
	%D%/interactive/search-backward.el		\
	%D%/interactive/search-backward-regexp.el	\
	%D%/interactive/search-forward.el		\
	%D%/interactive/search-forward-regexp.el	\
	%D%/interactive/set-fill-column.el		\
	%D%/interactive/set-variable.el			\
	%D%/interactive/shell-command.el		\
	%D%/interactive/shell-command-on-region.el	\
	%D%/interactive/switch-to-buffer.el		\
	%D%/interactive/tab-to-tab-stop.el		\
	%D%/interactive/transpose-chars.el		\
	%D%/interactive/transpose-lines.el		\
	%D%/interactive/transpose-sexps.el		\
	%D%/interactive/transpose-words.el		\
	%D%/interactive/universal-argument.el		\
	%D%/interactive/upcase-word.el			\
	%D%/interactive/yank.el

LISP_TESTS_ZILE_ONLY =							\
	%D%/regression/34080_buffer-name-suffix.el			\
	%D%/regression/34086_call-last-kbd-macro.el			\
	%D%/regression/34087_undo_macro.el				\
	%D%/regression/34193_interactive_insert.el			\
	%D%/regression/35053_eob_upcase-word.el				\
	%D%/regression/35560_find-file_completion.el			\
	%D%/regression/35562_search-backward.el				\
	%D%/regression/35567_minibuffer_ding_non_printable.el		\
	%D%/regression/goto-char_large.el				\
	%D%/zile-only/backward-delete-char_twice_in_empty_file.el	\
	%D%/zile-only/backward-word.el					\
	%D%/zile-only/end-of-line.el					\
	%D%/zile-only/fill-paragraph_2.el				\
	%D%/zile-only/fill-paragraph.el					\
	%D%/zile-only/goal-column.el					\
	%D%/zile-only/list-buffers.el					\
	%D%/zile-only/undo.el						\
	%D%/zile-only/interactive/call-last-kbd-macro.el		\
	%D%/zile-only/interactive/downcase-region.el			\
	%D%/zile-only/interactive/fill-paragraph_2.el			\
	%D%/zile-only/interactive/goal-column.el			\
	%D%/zile-only/interactive/keyboard-quit.el			\
	%D%/zile-only/interactive/list-buffers.el			\
	%D%/zile-only/interactive/negative_prefix-argument.el		\
	%D%/zile-only/interactive/next-line.el				\
	%D%/zile-only/interactive/previous-line.el			\
	%D%/zile-only/interactive/undo.el				\
	%D%/zile-only/interactive/upcase-region.el

LISP_TESTS_ZILE_ONLY_FIXED_SCREEN =			\
	%D%/zile-only/fixed-screen/scroll-down.el	\
	%D%/zile-only/fixed-screen/scroll-up.el

LISP_TESTS_OUTPUTS =					\
	$(srcdir)/tests/*.output			\
	$(srcdir)/tests/interactive/*.output		\
	$(srcdir)/tests/regression/*.output		\
	$(srcdir)/tests/zile-only/*.output		\
	$(srcdir)/tests/zile-only/interactive/*.output	\
	$(srcdir)/tests/zile-only/fixed-screen/*.output

LISP_ALL_TESTS =					\
	$(LISP_TESTS)					\
	$(LISP_TESTS_ZILE_ONLY)				\
	$(LISP_TESTS_ZILE_ONLY_FIXED_SCREEN)

LISP_TESTS_ENVIRONMENT =				\
	export LSAN_OPTIONS=suppressions=$(srcdir)/build-aux/asan-suppressions.txt; \
	export abs_srcdir=$(abs_srcdir);		\
	export srcdir=$(srcdir);			\
	export TERM=$(TERM);

AM_TESTS_ENVIRONMENT =					\
	$(LISP_TESTS_ENVIRONMENT)			\
	export EDITOR_NAME="Zile";			\
	export EDITOR_CMD="$(ZILE_CMD)";
EMACS_TESTS_ENVIRONMENT =				\
	$(LISP_TESTS_ENVIRONMENT)			\
	export EDITOR_NAME="Emacs";			\
	export EDITOR_CMD="$(EMACSPROG) --batch --quick"

EXTRA_DIST +=						\
	$(LISP_ALL_TESTS)				\
	$(LISP_TESTS_OUTPUTS)				\
	tests/test.input				\
	tests/run-lisp-test.pl

# The tests pass with Emacs 24.x, and fail with 25.1 or later.
check-emacs:
	echo $(LISP_TESTS) | $(EMACS_TESTS_ENVIRONMENT) xargs $(EL_LOG_COMPILER)

check-local:
	$(AM_TESTS_ENVIRONMENT) echo $(LISP_TESTS_ZILE_ONLY_FIXED_SCREEN) | COLUMNS=80 LINES=24 xargs $(RUNLISPTESTS)
	$(AM_TESTS_ENVIRONMENT) $(builddir)/src/zile$(EXEEXT) --unknown-flag --load $(srcdir)/tests/quit.el
