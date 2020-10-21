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

void insert_expanded_tab () {
	size_t t = cur_bp.tab_width ();
	bprintf ("%*s", (int) (t - cur_bp.goalc % t), "");
}

bool insert_tab () {
	if (cur_bp.warn_if_readonly ())
		return false;

	if (get_variable_bool ("indent-tabs-mode"))
		cur_bp.insert_char ('\t');
	else
		insert_expanded_tab ();

	return true;
}

/*
 * Insert a newline at the current position without moving the cursor.
 */
bool intercalate_newline ()
{
	return insert_newline () && cur_bp.move_char (-1);
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
	long? n = parse_number (cur_bp.get_variable ("fill-column"));
	if (n == null || n < 0) {
		Minibuf.error ("Wrong type argument: number-or-markerp, nil");
		return -1;
    }
	size_t fillcol = (size_t) n;

	int break_made = 0;

	/* Only break if we're beyond fill-column. */
	if (cur_bp.goalc > fillcol) {
		size_t break_col = 0;

		/* Save point. */
		Marker m = Marker.point ();

		/* Move cursor back to fill column */
		size_t old_col = cur_bp.pt - cur_bp.line_o ();
		while (cur_bp.goalc > fillcol + 1)
			cur_bp.move_char (-1);

		/* Find break point moving left from fill-column. */
		for (size_t i = cur_bp.pt - cur_bp.line_o (); i > 0; i--) {
			if (cur_bp.get_char (cur_bp.line_o () + i - 1).isspace ()) {
				break_col = i;
				break;
            }
        }

		/* If no break point moving left from fill-column, find first
		   possible moving right. */
		if (break_col == 0)
			for (size_t i = cur_bp.pt + 1;
				 i < cur_bp.end_of_line (cur_bp.line_o ());
				 i++)
				if (cur_bp.get_char (i - 1).isspace ()) {
					break_col = i - cur_bp.line_o ();
					break;
				}

		if (break_col >= 1) {
			/* Break line. */
			cur_bp.goto_offset (cur_bp.line_o () + break_col);
			funcall ("delete-horizontal-space");
			insert_newline ();
			cur_bp.goto_offset (m.o);
			break_made = 1;
        } else
			/* Undo fiddling with point. */
			cur_bp.goto_offset (cur_bp.line_o () + old_col);

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

void bprintf (string fmt, ...) {
	string s = fmt.vprintf (va_list());
	cur_bp.insert_estr (ImmutableEstr.of (s, s.length));
}

/***********************************************************************
                         Indentation command
***********************************************************************/
/*
 * Go to cur_bp.goalc in the previous non-blank line.
 */
void previous_nonblank_goalc () {
	size_t cur_goalc = cur_bp.goalc;

	/* Find previous non-blank line. */
	while (funcall ("forward-line", -1) && cur_bp.is_blank_line ());

	/* Go to `cur_goalc' in that non-blank line. */
	while (!cur_bp.eolp () && cur_bp.goalc < cur_goalc)
		cur_bp.move_char (1);
}

bool insert_newline () {
	return cur_bp.insert_estr (ImmutableEstr.of ("\n", "\n".length));
}

size_t previous_line_indent () {
	size_t cur_indent;
	Marker m = Marker.point ();

	funcall ("previous-line");
	funcall ("beginning-of-line");

	/* Find first non-blank char. */
	while (!cur_bp.eolp () && (cur_bp.following_char ().isspace ()))
		cur_bp.move_char (1);

	cur_indent = cur_bp.goalc;

	/* Restore point. */
	cur_bp.goto_offset (m.o);
	m.unchain ();

	return cur_indent;
}


public void line_init () {
	new LispFunc (
		"tab-to-tab-stop",
		(uniarg, args) => {
			return execute_with_uniarg (uniarg, insert_tab, null);
		},
		true,
		"""Insert a tabulation at the current point position into the current
buffer."""
		);

	new LispFunc (
		"newline",
		(uniarg, args) => {
			return execute_with_uniarg (uniarg, newline, null);
		},
		true,
		"""Insert a newline at the current point position into
the current buffer."""
		);

	new LispFunc (
		"open-line",
		(uniarg, args) => {
			return execute_with_uniarg (uniarg, intercalate_newline, null);
		},
		true,
		"""Insert a newline and leave point before it."""
		);

	new LispFunc (
		"insert",
		(uniarg, args) => {
			string? arg = args.poll ();
			if (arg != null)
				bprintf ("%s", arg);
			return false;
		},
		false,
		"""Insert the argument at point."""
		);

	new LispFunc (
		"delete-char",
		(uniarg, args) => {
			long n = 1;
			int_or_uniarg (args, ref n, uniarg);
			return execute_with_uniarg (n, cur_bp.delete_char, cur_bp.backward_delete_char);
		},
		true,
		"""Delete the following N characters (previous if N is negative)."""
		);

	new LispFunc (
		"backward-delete-char",
		(uniarg, args) => {
			long n = 1;
			int_or_uniarg (args, ref n, uniarg);
			return execute_with_uniarg (n, cur_bp.backward_delete_char, cur_bp.delete_char);
		},
		true,
		"""Delete the previous N characters (following if N is negative)."""
		);

	new LispFunc (
		"delete-horizontal-space",
		(uniarg, args) => {
			while (!cur_bp.eolp () && cur_bp.following_char ().isspace ())
				cur_bp.delete_char ();

			while (!cur_bp.bolp () && cur_bp.preceding_char ().isspace ())
				cur_bp.backward_delete_char ();

			return true;
		},
		true,
		"""Delete all spaces and tabs around point."""
		);

	new LispFunc (
		"just-one-space",
		(uniarg, args) => {
			funcall ("delete-horizontal-space");
			cur_bp.insert_char (' ');
			return true;
		},
		true,
		"""Delete all spaces and tabs around point, leaving one space."""
		);

	new LispFunc (
		"indent-relative",
		(uniarg, args) => {
			size_t target_goalc = 0, cur_goalc = cur_bp.goalc;
			size_t t = cur_bp.tab_width ();

			bool ok = false;

			if (cur_bp.warn_if_readonly ())
				return false;

			cur_bp.mark_active = false;

			/* If we're on the first line, set target to 0. */
			if (cur_bp.line_o () != 0) {
				/* Find goalc in previous non-blank line. */
				Marker m = Marker.point ();

				previous_nonblank_goalc ();

				/* Now find the next blank char. */
				if (!(cur_bp.preceding_char () == '\t' && cur_bp.goalc > cur_goalc))
					while (!cur_bp.eolp () && (!cur_bp.following_char ().isspace ()))
						cur_bp.move_char (1);

				/* Find next non-blank char. */
				while (!cur_bp.eolp () && cur_bp.following_char ().isspace ())
					cur_bp.move_char (1);

				/* Target column. */
				if (!cur_bp.eolp ())
					target_goalc = cur_bp.goalc;

				cur_bp.goto_offset (m.o);
				m.unchain ();
			}

			/* Insert indentation.  */
			if (target_goalc > 0) {
				/* If not at EOL on target line, insert spaces & tabs up to
				   target_goalc; if already at EOL on target line, insert a tab. */
				if (cur_bp.goalc < target_goalc) {
					do {
						if (cur_bp.goalc % t == 0 && cur_bp.goalc + t <= target_goalc)
							ok = insert_tab ();
						else
							ok = cur_bp.insert_char (' ');
					} while (ok && cur_bp.goalc < target_goalc);
				} else
					ok = insert_tab ();
			} else
				ok = insert_tab ();
			return ok;
		},
		true,
		"""Space out to under next indent point in previous nonblank line.
An indent point is a non-whitespace character following whitespace.
The following line shows the indentation points in this line.
    ^         ^    ^     ^   ^           ^      ^  ^    ^
If the previous nonblank line has no indent points beyond the
column point starts at, `tab-to-tab-stop' is done instead, unless
this command is invoked with a numeric argument, in which case it
does nothing."""
		);

	new LispFunc (
		"indent-for-tab-command",
		(uniarg, args) => {
			if (get_variable_bool ("tab-always-indent"))
				return insert_tab ();
			else if (cur_bp.goalc < previous_line_indent ())
				return funcall ("indent-relative");
			return true;
		},
		true,
		"""Indent line or insert a tab.
Depending on `tab-always-indent', either insert a tab or indent.
If initial point was within line's indentation, position after
the indentation.  Else stay at same point in text."""
		);

	new LispFunc (
		"newline-and-indent",
		(uniarg, args) => {
			bool ok = false;

			if (cur_bp.warn_if_readonly ())
				return false;

			cur_bp.mark_active = false;

			if (insert_newline ()) {
				Marker m = Marker.point ();

				/* Check where last non-blank goalc is. */
				previous_nonblank_goalc ();
				size_t pos = cur_bp.goalc;
				bool indent = pos > 0 || (!cur_bp.eolp () && cur_bp.following_char ().isspace ());
				cur_bp.goto_offset (m.o);
				m.unchain ();
				/* Only indent if we're in column > 0 or we're in column 0 and
				   there is a space character there in the last non-blank line. */
				if (indent)
					funcall ("indent-for-tab-command");
				ok = true;
			}
			return ok;
		},
		true,
		"""Insert a newline, then indent.
Indentation is done using the `indent-for-tab-command' function."""
		);
}
