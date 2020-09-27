/* Zile variables

   Copyright (c) 1997-2020 Free Software Foundation, Inc.

   This file is part of GNU Zile.

   GNU Zile is free software; you can redistribute it and/or modify it
   under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3, or (at your option)
   any later version.

   GNU Zile is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with GNU Zile; see the file COPYING.  If not, write to the
   Free Software Foundation, Fifth Floor, 51 Franklin Street, Boston,
   MA 02111-1301, USA.  */

/*
 * name, default_value, local_when_set, docstring
 */

public void init_variables () {
	main_vars = new_varlist ();
	init_builtin_var ("inhibit-splash-screen", "nil", false, "Non-nil inhibits the startup screen.\nIt also inhibits display of the initial message in the `*scratch*' buffer.");
	init_builtin_var ("standard-indent", "4", false, "Default number of columns for margin-changing functions to indent.");
	init_builtin_var ("tab-width", "8", true, "Distance between tab stops (for display of tab characters), in columns.");
	init_builtin_var ("tab-always-indent", "t", false, "Controls the operation of the TAB key.\nIf t, hitting TAB always just indents the current line.\nIf nil, hitting TAB indents the current line if point is at the\nleft margin or in the line's indentation, otherwise it inserts a\n\"real\" TAB character.");
	init_builtin_var ("indent-tabs-mode", "t", true, "If non-nil, insert-tab inserts \"real\" tabs; otherwise, it always inserts\nspaces.");
	init_builtin_var ("fill-column", "70", true, "Column beyond which automatic line-wrapping should happen.\nAutomatically becomes buffer-local when set in any fashion.");
	init_builtin_var ("auto-fill-mode", "nil", false, "If non-nil, Auto Fill Mode is automatically enabled.");
	init_builtin_var ("kill-whole-line", "nil", false, "If non-nil, `kill-line' with no arg at beg of line kills the whole line.");
	init_builtin_var ("case-fold-search", "t", true, "Non-nil means searches ignore case.");
	init_builtin_var ("case-replace", "t", false, "Non-nil means `query-replace' should preserve case in replacements.");
	init_builtin_var ("ring-bell", "t", false, "Non-nil means ring the terminal bell on any error.");
	init_builtin_var ("highlight-nonselected-windows", "nil", false, "If non-nil, highlight region even in nonselected windows.");
	init_builtin_var ("make-backup-files", "t", false, "Non-nil means make a backup of a file the first time it is saved.\nThis is done by appending `~' to the file name.");
	init_builtin_var ("backup-directory", "nil", false, "The directory for backup files, which must exist.\nIf this variable is nil, the backup is made in the original file's\ndirectory.\nThis value is used only when `make-backup-files' is t.");
}
