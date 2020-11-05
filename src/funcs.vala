/* Miscellaneous Emacs functions

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
   along with this program; if not, see <https://www.gnu.org/licenses/>.  */

public delegate void BufferWriter ();

public void write_temp_buffer (string name, bool show, BufferWriter func) {
	/* Popup a window with the buffer "name". */
	Window old_wp = cur_wp;
	Buffer old_bp = cur_bp;
	Window wp = Window.find (name);
	if (show && wp != null)
		wp.set_current ();
	else {
		Buffer? bp = Buffer.find (name);
		if (show)
			popup_window ().set_current ();
		if (bp == null) {
			bp = new Buffer ();
			bp.name = name;
        }
		bp.switch_to ();
    }

	/* Remove the contents of that buffer. */
	Buffer new_bp = new Buffer ();
	new_bp.name = cur_bp.name;
	cur_bp.kill ();
	cur_bp = new_bp;
	cur_wp.bp = cur_bp;

	/* Make the buffer a temporary one. */
	cur_bp.needname = true;
	cur_bp.noundo = true;
	cur_bp.nosave = true;
	cur_bp.set_temporary ();

	/* Use the delegate. */
	func ();

	funcall ("beginning-of-buffer");
	cur_bp.readonly = true;
	cur_bp.modified = false;

	/* Restore old current window. */
	old_wp.set_current ();

	/* If we're not showing the new buffer, switch back to the old one. */
	if (!show)
		old_bp.switch_to ();
}

/***********************************************************************
                          Move through words
***********************************************************************/
bool iswordchar (char c) {
	return c.isalnum () || c == '$';
}

/***********************************************************************
               Move through balanced expressions (sexps)
***********************************************************************/
bool isopenbracketchar (char c, bool single_quote, bool double_quote) {
	return ((c == '(') || (c == '[') || (c == '{') ||
			((c == '\"') && !double_quote) ||
			((c == '\'') && !single_quote));
}

bool isclosebracketchar (char c, bool single_quote, bool double_quote) {
	return ((c == ')') || (c == ']') || (c == '}') ||
			((c == '\"') && double_quote) ||
			((c == '\'') && single_quote));
}

/***********************************************************************
                          Transpose functions
***********************************************************************/
void estr_append_region (Estr es) {
	cur_bp.mark_active = true;
	es.cat (cur_bp.get_region (Region.calculate ()));
}

bool transpose_subr (MovementNDelegate move_func) {
	/* For transpose-chars. */
	if (move_func == (MovementNDelegate) cur_bp.move_char && cur_bp.eolp ())
		move_func (-1);

	/* For transpose-lines. */
	if (move_func == (MovementNDelegate) cur_bp.move_line && cur_bp.line_o () == 0)
		move_func (1);

	/* Backward. */
	if (!move_func (-1)) {
		Minibuf.error ("Beginning of buffer");
		return false;
    }

	/* Mark the beginning of first string. */
	push_mark ();
	Marker m1 = Marker.point ();

	/* Check to make sure we can go forwards twice. */
	if (!move_func (1) || !move_func (1)) {
		if (move_func == (MovementNDelegate) cur_bp.move_line) {
			/* Add an empty line. */
			funcall ("end-of-line");
			funcall ("newline");
        } else {
			pop_mark ();
			cur_bp.goto_offset (m1.o);
			Minibuf.error ("End of buffer");

			m1.unchain ();
			return false;
        }
    }

	cur_bp.goto_offset (m1.o);

	/* Forward. */
	move_func (1);

	/* Save and delete 1st marked region. */
	Estr es1 = Estr.of_empty (cur_bp.eol);
	estr_append_region (es1);

	funcall ("delete-region");

	/* Forward. */
	move_func (1);

	/* For transpose-lines. */
	Estr es2 = null;
	Marker m2;
	if (move_func == (MovementNDelegate) cur_bp.move_line)
		m2 = Marker.point ();
	else {
		/* Mark the end of second string. */
		set_mark ();

		/* Backward. */
		move_func (-1);
		m2 = Marker.point ();

		/* Save and delete 2nd marked region. */
		es2 = Estr.of_empty (cur_bp.eol);
		estr_append_region (es2);
		funcall ("delete-region");
    }

	/* Insert the first string. */
	cur_bp.goto_offset (m2.o);
	m2.unchain ();
	cur_bp.insert_estr (es1);

	/* Insert the second string. */
	if (es2 != null) {
		cur_bp.goto_offset (m1.o);
		cur_bp.insert_estr (es2);
    }
	m1.unchain ();

	/* Restore mark. */
	pop_mark ();
	cur_bp.mark_active = false;

	/* Move forward if necessary. */
	if (move_func != (MovementNDelegate) cur_bp.move_line)
		move_func (1);

	return true;
}

bool transpose (long uniarg, MovementNDelegate move) {
	if (cur_bp.warn_if_readonly ())
		return false;

	bool ret = true;
	for (ulong uni = 0; ret && uni < (ulong) uniarg.abs (); ++uni)
		ret = transpose_subr (move);

	return ret;
}


bool mark (long uniarg, Function func) {
  funcall ("set-mark-command");
  bool ok = func (uniarg, null);
  if (ok)
    funcall ("exchange-point-and-mark");
  return ok;
}

bool move_paragraph (long uniarg, MovementDelegate forward, MovementDelegate backward,
					 Function line_extremum) {
	if (uniarg < 0) {
		uniarg = -uniarg;
		forward = backward;
    }

	while (uniarg-- > 0) {
		while (cur_bp.is_empty_line () && forward ())
			;
		while (!cur_bp.is_empty_line () && forward ())
			;
    }

	if (cur_bp.is_empty_line ())
		funcall ("beginning-of-line");
	else
		line_extremum (1, null);

	return true;
}

public enum Case {
	upper = 1,
	lower,
	capitalized,
}

string recase (string s, Case rcase) {
	switch (rcase) {
	case upper:
		return s.up ();
	case lower:
		return s.down ();
	case capitalized: {
		string ret = "";
		if (s.length > 0) {
			ret = s[0].toupper ().to_string ();
			if (s.length > 1)
				ret += s.substring (1);
		}
		return ret;
	}
	}
	/* Should never reach here. */
	assert (false);
	return s;
}

bool setcase_word (Case rcase) {
	if (!iswordchar (cur_bp.following_char ()))
		if (!cur_bp.move_word (1) || !cur_bp.move_word (-1))
			return false;

	string a = "";
	char c = 0;
	for (size_t i = cur_bp.pt - cur_bp.line_o ();
		 i < cur_bp.line_len (cur_bp.pt) &&
			 iswordchar ((c = cur_bp.get_char (cur_bp.line_o () + i)));
		 i++)
		a += ((char) c).to_string ();

	if (a.length > 0)
		cur_bp.replace_estr (a.length, ImmutableEstr.of (recase (a, rcase), a.length));

	cur_bp.modified = true;

	return true;
}

bool setcase_word_lowercase () {
	return setcase_word (Case.lower);
}

bool setcase_word_uppercase () {
	return setcase_word (Case.upper);
}

bool setcase_word_capitalize () {
	return setcase_word (Case.capitalized);
}

/*
 * Set the region case.
 */
delegate char CharTransform (char c);
bool setcase_region (CharTransform func) {
	if (cur_bp.warn_if_readonly () || cur_bp.warn_if_no_mark ())
		return false;

	Region r = Region.calculate ();
	Marker m = Marker.point ();
	cur_bp.goto_offset (r.start);
	for (size_t n = r.size (); n > 0; n--) {
		char c = func (cur_bp.following_char ());
		cur_bp.delete_char ();
		cur_bp.insert_char (c);
    }
	cur_bp.goto_offset (m.o);
	m.unchain ();

	return true;
}


public void funcs_init () {
	new LispFunc (
		"list-buffers",
		(uniarg, args) => {
			write_temp_buffer (
				"*Buffer List*",
				true,
				() => {
					/* FIXME: Underline next line properly. */
					bprintf ("CRM Buffer                Size  Mode             File\n");
					bprintf ("--- ------                ----  ----             ----\n");

					/* Print buffers. */
					assert (cur_wp != null);
					Buffer? bp = cur_wp.bp;
					assert (bp != null);
					do {
						/* Print all buffers whose names don't start with space except
						   this one (the *Buffer List*). */
						if (cur_bp != bp && bp.name[0] != ' ') {
							bprintf ("%c%c%c %-19s %6zu  %-17s",
									 cur_wp.bp == bp ? '.' : ' ',
									 bp.readonly ? '%' : ' ',
									 bp.modified ? '*' : ' ',
									 bp.name, bp.length, "Fundamental");
							if (bp.filename != null)
								bprintf ("%s", compact_path (bp.filename));
							insert_newline ();
						}
						bp = bp.next;
						if (bp == null)
							bp = head_bp;
					} while (bp != cur_wp.bp);
				});
			return true;
		},
		true,
		"""Display a list of names of existing buffers.
The list is displayed in a buffer named `*Buffer List*'.
Note that buffers with names starting with spaces are omitted.

The \"R\" column has a \"%\" if the buffer is read-only.
The \"M\" column has a \"*\" if it is modified."""
		);

	new LispFunc (
		"toggle-read-only",
		(uniarg, args) => {
			cur_bp.readonly = !cur_bp.readonly;
			return true;
		},
		true,
		"""Change whether this buffer is visiting its file read-only."""
		);

	new LispFunc (
		"auto-fill-mode",
		(uniarg, args) => {
			cur_bp.autofill = !cur_bp.autofill;
			return true;
		},
		true,
		"""Toggle Auto Fill mode.
In Auto Fill mode, inserting a space at a column beyond `fill-column'
automatically breaks the line at a previous space."""
		);

	new LispFunc (
		"set-fill-column",
		(uniarg, args) => {
			bool ok = true;
			size_t o = cur_bp.pt - cur_bp.line_o ();
			long fill_col = Flags.UNIARG_EMPTY in lastflag ? (long) o : uniarg;
			string buf = null;

			if (noarg (args)) {
				fill_col = Minibuf.read_number ("Set fill-column to (default %zu): ", o);
				if (fill_col == long.MAX)
					return false;
				else if (fill_col == long.MAX - 1)
					fill_col = (long) o;
			}

			if (args != null) {
				if (!args.is_empty)
					buf = args.poll ();
				else {
					Minibuf.error ("set-fill-column requires an explicit argument");
					ok = false;
				}
			} else {
				buf = fill_col.to_string ();
				/* Only print message when run interactively. */
				Minibuf.write ("Fill column set to %s (was %s)", buf,
							   get_variable ("fill-column"));
			}

			if (ok)
				set_variable ("fill-column", buf);
			return ok;
		},
		true,
		"""Set `fill-column' to specified argument.
Use C-u followed by a number to specify a column.
Just C-u as argument means to use the current column."""
		);

	new LispFunc (
		"set-mark",
		(uniarg, args) => {
			set_mark ();
			cur_bp.mark_active = true;
			return true;
		},
		false,
		"""Set this buffer's mark to point."""
		);

	new LispFunc (
		"set-mark-command",
		(uniarg, args) => {
			funcall ("set-mark");
			Minibuf.write ("Mark set");
			return true;
		},
		true,
		"""Set the mark where point is."""
		);

	new LispFunc (
		"exchange-point-and-mark",
		(uniarg, args) => {
			if (cur_bp.mark == null) {
				Minibuf.error ("No mark set in this buffer");
				return false;
			}

			size_t o = cur_bp.pt;
			cur_bp.goto_offset (cur_bp.mark.o);
			cur_bp.mark.o = o;
			cur_bp.mark_active = true;
			thisflag |= Flags.NEED_RESYNC;
			return true;
		},
		true,
		"""Put the mark where point is now, and point where the mark is now."""
		);

	new LispFunc (
		"mark-whole-buffer",
		(uniarg, args) => {
			funcall ("end-of-buffer");
			funcall ("set-mark-command");
			funcall ("beginning-of-buffer");
			return true;
		},
		true,
		"""Put point at beginning and mark at end of buffer."""
		);

	new LispFunc (
		"quoted-insert",
		(uniarg, args) => {
			Minibuf.write ("C-q-");
			cur_bp.insert_char ((char) getkey_unfiltered (GETKEY_DEFAULT));
			Minibuf.clear ();
			return true;
		},
		true,
		"""Read next input character and insert it.
This is useful for inserting control characters."""
		);

	new LispFunc (
		"universal-argument",
		(uniarg, args) => {
			bool ok = true;
			int i = 0, arg = 1, sgn = 1;
			string a = "";

			/* Need to process key used to invoke universal-argument. */
			pushkey (lastkey ());

			thisflag |= Flags.UNIARG_EMPTY;

			for (;;) {
				uint key = binding_completion (a);

				/* Cancelled. */
				if (key == KBD_CANCEL) {
					ok = funcall ("keyboard-quit");
					break;
				} else if (((char) (key & 0xff)).isdigit ()) {
					/* Digit pressed. */
					int digit = (int) ((key & 0xff) - '0');
					thisflag &= ~Flags.UNIARG_EMPTY;

					if ((key & KBD_META) != 0) {
						if (a.length > 0)
							a += " ";
						a += "ESC";
					}

					a += @" $digit";

					if (i == 0)
						arg = digit;
					else
						arg = arg * 10 + digit;

					i++;
				} else if (key == (KBD_CTRL | 'u')) {
					a += "C-u";
					if (i == 0)
						arg *= 4;
					else
						break;
				} else if ((key & ~KBD_META) == '-' && i == 0) {
					if (sgn > 0) {
						sgn = -sgn;
						a += " -";
						/* The default negative arg is -1, not -4. */
						arg = 1;
						thisflag &= ~Flags.UNIARG_EMPTY;
					}
				} else {
					ungetkey (key);
					break;
				}
			}

			if (ok) {
				last_uniarg = arg * sgn;
				thisflag |= Flags.SET_UNIARG;
				Minibuf.clear ();
			}

			return ok;
		},
		true,
		"""Begin a numeric argument for the following command.
Digits or minus sign following \\[universal-argument] make up the numeric argument.
\\[universal-argument] following the digits or minus sign ends the argument.
\\[universal-argument] without digits or minus sign provides 4 as argument.
Repeating \\[universal-argument] without digits or minus sign
 multiplies the argument by 4 each time."""
		);

	new LispFunc (
		"back-to-indentation",
		(uniarg, args) => {
			cur_bp.goto_offset (cur_bp.line_o ());
			while (!cur_bp.eolp () && cur_bp.following_char ().isspace ())
				cur_bp.move_char (1);
			return true;
		},
		true,
		"""Move point to the first non-whitespace character on this line."""
		);

	new LispFunc (
		"suspend-emacs",
		(uniarg, args) => {
			Posix.raise (Posix.Signal.TSTP);
			return true;
		},
		true,
		"""Stop Zile and return to superior process."""
		);

	new LispFunc (
		"keyboard-quit",
		(uniarg, args) => {
			cur_bp.mark_active = false;
			Minibuf.error ("Quit");
			return false;
		},
		true,
		"""Cancel current command."""
		);

	new LispFunc (
		"forward-word",
		(uniarg, args) => {
			return move_with_uniarg (uniarg, (MovementNDelegate) cur_bp.move_word);
		},
		true,
		"""Move point forward one word (backward if the argument is negative).
With argument, do this that many times."""
		);

	new LispFunc (
		"backward-word",
		(uniarg, args) => {
			return move_with_uniarg (-uniarg, (MovementNDelegate) cur_bp.move_word);
		},
		true,
		"""Move backward until encountering the end of a word (forward if the
argument is negative).
With argument, do this that many times."""
		);

	new LispFunc (
		"forward-sexp",
		(uniarg, args) => {
			return move_with_uniarg (uniarg, (MovementNDelegate) cur_bp.move_sexp);
		},
		true,
		"""Move forward across one balanced expression (sexp).
With argument, do it that many times.  Negative arg -N means
move backward across N balanced expressions."""
		);

	new LispFunc (
		"backward-sexp",
		(uniarg, args) => {
			return move_with_uniarg (-uniarg, (MovementNDelegate) cur_bp.move_sexp);
		},
		true,
		"""Move backward across one balanced expression (sexp).
With argument, do it that many times.  Negative arg -N means
move forward across N balanced expressions."""
		);

	new LispFunc (
		"transpose-chars",
		(uniarg, args) => {
			return transpose (uniarg, (MovementNDelegate) cur_bp.move_char);
		},
		true,
		"""Interchange characters around point, moving forward one character.
With prefix arg ARG, effect is to take character before point
and drag it forward past ARG other characters (backward if ARG negative).
If no argument and at end of line, the previous two chars are exchanged."""
		);

	new LispFunc (
		"transpose-words",
		(uniarg, args) => {
			return transpose (uniarg, (MovementNDelegate) cur_bp.move_word);
		},
		true,
		"""Interchange words around point, leaving point at end of them.
With prefix arg ARG, effect is to take word before or around point
and drag it forward past ARG other words (backward if ARG negative).
If ARG is zero, the words around or after point and around or after mark
are interchanged."""
		);

	new LispFunc (
		"transpose-sexps",
		(uniarg, args) => {
			return transpose (uniarg, (MovementNDelegate) cur_bp.move_sexp);
		},
		true,
		"""Like `transpose-words', but applies to sexps."""
		);

	new LispFunc (
		"transpose-lines",
		(uniarg, args) => {
			return transpose (uniarg, (MovementNDelegate) cur_bp.move_line);
		},
		true,
		"""Exchange current line and previous line, leaving point after both.
With argument ARG, takes previous line and moves it past ARG lines.
With argument 0, interchanges line point is in with line mark is in."""
		);

	new LispFunc (
		"mark-word",
		(uniarg, args) => {
			return mark (uniarg, LispFunc.find ("forward-word").func);
		},
		true,
		"""Set mark argument words away from point."""
		);

	new LispFunc (
		"mark-sexp",
		(uniarg, args) => {
			return mark (uniarg, LispFunc.find ("forward-sexp").func);
		},
		true,
		"""Set mark ARG sexps from point.
The place mark goes is the same place \\[forward-sexp] would
move to with the same argument."""
		);

	new LispFunc (
		"forward-line",
		(uniarg, args) => {
			bool ok = true;
			long n = 1;
			if (!noarg (args) &&
				!int_or_uniarg (args, ref n, uniarg))
				ok = false;
			if (ok) {
				funcall ("beginning-of-line");
				ok = cur_bp.move_line (n);
			}
			return ok;
		},
		true,
		"""Move N lines forward (backward if N is negative).
Precisely, if point is on line I, move to the start of line I + N."""
		);

	new LispFunc (
		"backward-paragraph",
		(uniarg, args) => {
			return move_paragraph (uniarg,
								   () => { return cur_bp.move_line (-1); },
								   () => { return cur_bp.move_line (1); },
								   LispFunc.find ("beginning-of-line").func);
		},
		true,
		"""Move backward to start of paragraph.  With argument N, do it N times."""
		);

	new LispFunc (
		"forward-paragraph",
		(uniarg, args) => {
			return move_paragraph (uniarg,
							       () => { return cur_bp.move_line (1); },
								   () => { return cur_bp.move_line (-1); },
								   LispFunc.find ("end-of-line").func);
		},
		true,
		"""Move forward to end of paragraph.  With argument N, do it N times."""
		);

	new LispFunc (
		"mark-paragraph",
		(uniarg, args) => {
			if (last_command () == LispFunc.find ("mark-paragraph")) {
				funcall ("exchange-point-and-mark");
				funcall ("forward-paragraph", uniarg);
				funcall ("exchange-point-and-mark");
			} else {
				funcall ("forward-paragraph", uniarg);
				funcall ("set-mark-command");
				funcall ("backward-paragraph", uniarg);
			}
			return true;
		},
		true,
		"""Put point at beginning of this paragraph, mark at end.
The paragraph marked is the one that contains point or follows point."""
		);

	new LispFunc (
		"fill-paragraph",
		(uniarg, args) => {
			bool ok = true;
			Marker m = Marker.point ();

			funcall ("forward-paragraph");
			if (cur_bp.is_empty_line ())
				cur_bp.move_line (-1);
			Marker m_end = Marker.point ();

			funcall ("backward-paragraph");
			if (cur_bp.is_empty_line ())
				/* Move to next line if between two paragraphs. */
				cur_bp.move_line (1);

			while (cur_bp.end_of_line (cur_bp.pt) < m_end.o) {
				funcall ("end-of-line");
				cur_bp.delete_char ();
				funcall ("just-one-space");
			}
			m_end.unchain ();

			funcall ("end-of-line");
			int ret = 0;
			while ((ret = fill_break_line ()) == 1)
				;
			if (ret == -1)
				ok = false;

			cur_bp.goto_offset (m.o);
			m.unchain ();

			return ok;
		},
		true,
		"""Fill paragraph at or after point."""
		);

	new LispFunc (
		"downcase-word",
		(uniarg, args) => {
			bool ok = true;
			long arg = 1;
			if (!noarg (args) &&
				!int_or_uniarg (args, ref arg, uniarg))
				ok = false;
			if (ok)
				ok = execute_with_uniarg (arg, setcase_word_lowercase, null);
			return ok;
		},
		true,
		"""Convert following word (or ARG words) to lower case, moving over."""
		);

	new LispFunc (
		"upcase-word",
		(uniarg, args) => {
			bool ok = true;
			long arg = 1;
			if (!noarg (args) &&
				!int_or_uniarg (args, ref arg, uniarg))
				ok = false;
			if (ok)
				ok = execute_with_uniarg (arg, setcase_word_uppercase, null);
			return ok;
		},
		true,
		"""Convert following word (or ARG words) to upper case, moving over."""
		);

	new LispFunc (
		"capitalize-word",
		(uniarg, args) => {
			bool ok = true;
			long arg = 1;
			if (!noarg (args) &&
				!int_or_uniarg (args, ref arg, uniarg))
				ok = false;
			if (ok)
				ok = execute_with_uniarg (arg, setcase_word_capitalize, null);
			return ok;
		},
		true,
		"""Capitalize the following word (or ARG words), moving over.
This gives the word(s) a first character in upper case
and the rest lower case."""
		);

	new LispFunc (
		"upcase-region",
		(uniarg, args) => {
			return setcase_region ((c) => { return c.toupper (); });
		},
		true,
		"""Convert the region to upper case."""
		);

	new LispFunc (
		"downcase-region",
		(uniarg, args) => {
			return setcase_region ((c) => { return c.tolower (); });
		},
		true,
		"""Convert the region to lower case."""
		);

	new LispFunc (
		"delete-region",
		(uniarg, args) => {
			bool ok = true;
			if (cur_bp.warn_if_no_mark () || !Region.calculate ().delete ())
				ok = false;
			else
				cur_bp.mark_active = false;
			return ok;
		},
		true,
		"""Delete the text between point and mark."""
		);

	new LispFunc (
		"delete-blank-lines",
		(uniarg, args) => {
			Marker m = Marker.point ();
			Region r = new Region (cur_bp.line_o (), cur_bp.line_o ());

			/* Find following blank lines.  */
			if (funcall ("forward-line") && cur_bp.is_blank_line ()) {
				r.start = cur_bp.pt;
				do
					r.end = cur_bp.next_line (cur_bp.pt);
				while (funcall ("forward-line") && cur_bp.is_blank_line ());
				r.end = size_t.min (r.end, cur_bp.length);
			}
			cur_bp.goto_offset (m.o);

			/* If this line is blank, find any preceding blank lines.  */
			bool singleblank = true;
			if (cur_bp.is_blank_line ()) {
				r.end = size_t.max (r.end, cur_bp.next_line (cur_bp.pt));
				do
					r.start = cur_bp.line_o ();
				while (funcall ("forward-line", -1) && cur_bp.is_blank_line ());
				cur_bp.goto_offset (m.o);
				if (r.start != cur_bp.line_o () ||
					r.end > cur_bp.next_line (cur_bp.pt))
					singleblank = false;
				r.end = size_t.min (r.end, cur_bp.length);
			}

			/* If we are deleting to EOB, need to fudge extra line. */
			bool at_eob = r.end == cur_bp.length && r.start > 0;
			if (at_eob)
				r.start = r.start - cur_bp.eol.length;

			/* Delete any blank lines found. */
			if (r.start < r.end)
				r.delete ();

			/* If we found more than one blank line, leave one. */
			if (!singleblank) {
				if (!at_eob)
					intercalate_newline ();
				else
					insert_newline ();
			}

			m.unchain ();
			cur_bp.mark_active = false;

			return true;
		},
		true,
		"""On blank line, delete all surrounding blank lines, leaving just one.
On isolated blank line, delete that one.
On nonblank line, delete any immediately following blank lines."""
		);
}
