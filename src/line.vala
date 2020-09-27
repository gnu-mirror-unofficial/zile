/* Line-oriented editing functions

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

using Lisp;

void insert_expanded_tab () {
	size_t t = tab_width (cur_bp);
	bprintf ("%*s", (int) (t - get_goalc () % t), "");
}

bool insert_tab () {
	if (warn_if_readonly_buffer ())
		return false;

	if (get_variable_bool ("indent-tabs-mode"))
		insert_char ('\t');
	else
		insert_expanded_tab ();

	return true;
}

/*
DEFUN ("tab-to-tab-stop", tab_to_tab_stop)
*+
Insert a tabulation at the current point position into the current
buffer.
+*/
public bool F_tab_to_tab_stop (long uniarg, Lexp *arglist) {
	return execute_with_uniarg (uniarg, insert_tab, null);
}

/*
 * Insert a newline at the current position without moving the cursor.
 */
bool intercalate_newline ()
{
	return insert_newline () && move_char (-1);
}

/*
 * If point is greater than fill-column, then split the line at the
 * right-most space character at or before fill-column, if there is
 * one, or at the left-most at or after fill-column, if not. If the
 * line contains no spaces, no break is made.
 *
 * Return flag indicating whether break was made.
 */
int fill_break_line () {
	long n;
	if (!lisp_to_number (get_variable_bp (cur_bp, "fill-column"), out n) || n < 0) {
		Minibuf.error ("Wrong type argument: number-or-markerp, nil");
		return -1;
    }
	size_t fillcol = (size_t) n;

	int break_made = 0;

	/* Only break if we're beyond fill-column. */
	if (get_goalc () > fillcol) {
		size_t break_col = 0;

		/* Save point. */
		Marker m = Marker.point ();

		/* Move cursor back to fill column */
		size_t old_col = cur_bp.pt - get_buffer_line_o (cur_bp);
		while (get_goalc () > fillcol + 1)
			move_char (-1);

		/* Find break point moving left from fill-column. */
		for (size_t i = cur_bp.pt - get_buffer_line_o (cur_bp); i > 0; i--) {
			if (get_buffer_char (cur_bp, get_buffer_line_o (cur_bp) + i - 1).isspace ()) {
				break_col = i;
				break;
            }
        }

		/* If no break point moving left from fill-column, find first
		   possible moving right. */
		if (break_col == 0)
			for (size_t i = cur_bp.pt + 1;
				 i < buffer_end_of_line (cur_bp, get_buffer_line_o (cur_bp));
				 i++)
				if (get_buffer_char (cur_bp, i - 1).isspace ()) {
					break_col = i - get_buffer_line_o (cur_bp);
					break;
				}

		if (break_col >= 1) {
			/* Break line. */
			goto_offset (get_buffer_line_o (cur_bp) + break_col);
			funcall (F_delete_horizontal_space);
			insert_newline ();
			goto_offset (m.o);
			break_made = 1;
        } else
			/* Undo fiddling with point. */
			goto_offset (get_buffer_line_o (cur_bp) + old_col);

		m.unchain ();
    }

	return break_made;
}

bool newline () {
	bool ret = true;
	if (cur_bp.autofill)
		ret = fill_break_line () != -1;
	return ret ? insert_newline () : false;
}

/*
DEFUN ("newline", newline)
*+
Insert a newline at the current point position into
the current buffer.
+*/
public bool F_newline (long uniarg, Lexp *arglist) {
	return execute_with_uniarg (uniarg, newline, null);
}

/*
DEFUN ("open-line", open_line)
*+
Insert a newline and leave point before it.
+*/
public bool F_open_line (long uniarg, Lexp *arglist) {
	return execute_with_uniarg (uniarg, intercalate_newline, null);
}

bool insert_newline () {
	return insert_estr (estr_new_astr (Astr.new_cstr ("\n")));
}

/*
DEFUN_NONINTERACTIVE_ARGS ("insert", insert, STR_ARG (arg))
*+
Insert the argument at point.
+*/
public bool F_insert (long uniarg, Lexp *arglist) {
	string? arg = str_init (ref arglist);
	if (arg != null)
		bprintf ("%s", arg);
	return false;
}

void bprintf (string fmt, ...) {
	insert_estr (estr_new (Astr.new_cstr (fmt.vprintf (va_list())), coding_eol_lf));
}

bool backward_delete_char () {
	deactivate_mark ();

	if (!move_char (-1)) {
		Minibuf.error ("Beginning of buffer");
		return false;
    }

	delete_char ();
	return true;
}

/*
DEFUN_ARGS ("delete-char", delete_char, INT_OR_UNIARG (n))
*+
Delete the following N characters (previous if N is negative).
+*/
public bool F_delete_char (long uniarg, Lexp *arglist) {
	long n = 1;
	int_or_uniarg_init (ref arglist, ref n, uniarg);
	return execute_with_uniarg (n, delete_char, backward_delete_char);
}

/*
DEFUN_ARGS ("backward-delete-char", backward_delete_char, INT_OR_UNIARG (n))
*+
Delete the previous N characters (following if N is negative).
+*/
public bool F_backward_delete_char (long uniarg, Lexp *arglist) {
	long n = 1;
	int_or_uniarg_init (ref arglist, ref n, uniarg);
	return execute_with_uniarg (n, backward_delete_char, delete_char);
}

/*
DEFUN ("delete-horizontal-space", delete_horizontal_space)
*+
Delete all spaces and tabs around point.
+*/
public bool F_delete_horizontal_space (long uniarg, Lexp *arglist) {
	while (!eolp () && following_char ().isspace ())
		delete_char ();

	while (!bolp () && preceding_char ().isspace ())
		backward_delete_char ();

	return true;
}

/*
DEFUN ("just-one-space", just_one_space)
*+
Delete all spaces and tabs around point, leaving one space.
+*/
public bool F_just_one_space (long uniarg, Lexp *arglist) {
	funcall (F_delete_horizontal_space);
	insert_char (' ');
	return true;
}

/***********************************************************************
                         Indentation command
***********************************************************************/
/*
 * Go to cur_goalc () in the previous non-blank line.
 */
void previous_nonblank_goalc () {
	size_t cur_goalc = get_goalc ();

	/* Find previous non-blank line. */
	while (funcall_arg (F_forward_line, -1) && is_blank_line ());

	/* Go to `cur_goalc' in that non-blank line. */
	while (!eolp () && get_goalc () < cur_goalc)
		move_char (1);
}

/*
DEFUN ("indent-relative", indent_relative)
*+
Space out to under next indent point in previous nonblank line.
An indent point is a non-whitespace character following whitespace.
The following line shows the indentation points in this line.
    ^         ^    ^     ^   ^           ^      ^  ^    ^
If the previous nonblank line has no indent points beyond the
column point starts at, `tab-to-tab-stop' is done instead, unless
this command is invoked with a numeric argument, in which case it
does nothing.
+*/
public bool F_indent_relative (long uniarg, Lexp *arglist) {
	size_t target_goalc = 0, cur_goalc = get_goalc ();
	size_t t = tab_width (cur_bp);

	bool ok = false;

	if (warn_if_readonly_buffer ())
		return false;

	deactivate_mark ();

	/* If we're on the first line, set target to 0. */
	if (get_buffer_line_o (cur_bp) == 0)
		target_goalc = 0;
	else {
		/* Find goalc in previous non-blank line. */
		Marker m = Marker.point ();

		previous_nonblank_goalc ();

		/* Now find the next blank char. */
		if (!(preceding_char () == '\t' && get_goalc () > cur_goalc))
			while (!eolp () && (!following_char ().isspace ()))
				move_char (1);

		/* Find next non-blank char. */
		while (!eolp () && (following_char ().isspace ()))
			move_char (1);

		/* Target column. */
		if (!eolp ())
			target_goalc = get_goalc ();

		goto_offset (m.o);
		m.unchain ();
    }

	/* Insert indentation.  */
	if (target_goalc > 0) {
		/* If not at EOL on target line, insert spaces & tabs up to
		   target_goalc; if already at EOL on target line, insert a tab. */
		cur_goalc = get_goalc ();
		if (cur_goalc < target_goalc) {
			do {
				if (cur_goalc % t == 0 && cur_goalc + t <= target_goalc)
					ok = insert_tab ();
				else
					ok = insert_char (' ');
            } while (ok && (cur_goalc = get_goalc ()) < target_goalc);
        } else
			ok = insert_tab ();
    } else
		ok = insert_tab ();
	return ok;
}

size_t previous_line_indent () {
	size_t cur_indent;
	Marker m = Marker.point ();

	funcall (F_previous_line);
	funcall (F_beginning_of_line);

	/* Find first non-blank char. */
	while (!eolp () && (following_char ().isspace ()))
		move_char (1);

	cur_indent = get_goalc ();

	/* Restore point. */
	goto_offset (m.o);
	m.unchain ();

	return cur_indent;
}

/*
DEFUN ("indent-for-tab-command", indent_for_tab_command)
*+
Indent line or insert a tab.
Depending on `tab-always-indent', either insert a tab or indent.
If initial point was within line's indentation, position after
the indentation.  Else stay at same point in text.
+*/
public bool F_indent_for_tab_command (long uniarg, Lexp *arglist) {
	if (get_variable_bool ("tab-always-indent"))
		return insert_tab ();
	else if (get_goalc () < previous_line_indent ())
		return funcall (F_indent_relative);
	return true;
}

/*
DEFUN ("newline-and-indent", newline_and_indent)
*+
Insert a newline, then indent.
Indentation is done using the `indent-for-tab-command' function.
+*/
public bool F_newline_and_indent (long uniarg, Lexp *arglist) {
	bool ok = false;

	if (warn_if_readonly_buffer ())
		return false;

	deactivate_mark ();

	if (insert_newline ()) {
		Marker m = Marker.point ();

		/* Check where last non-blank goalc is. */
		previous_nonblank_goalc ();
		size_t pos = get_goalc ();
		bool indent = pos > 0 || (!eolp () && following_char ().isspace ());
		goto_offset (m.o);
		m.unchain ();
		/* Only indent if we're in column > 0 or we're in column 0 and
		   there is a space character there in the last non-blank line. */
		if (indent)
			funcall (F_indent_for_tab_command);
		ok = true;
    }
	return ok;
}
