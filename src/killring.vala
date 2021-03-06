/* Kill ring facility functions

   Copyright (c) 2001-2020 Free Software Foundation, Inc.

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

Estr kill_ring_text;

void maybe_destroy_kill_ring () {
	if (last_command () != LispFunc.find ("kill-region"))
		kill_ring_text = null;
}

void kill_ring_push (ImmutableEstr es) {
	if (kill_ring_text == null)
		kill_ring_text = Estr.of_empty (es.eol);
	kill_ring_text.cat (es);
}

bool copy_or_kill_region (bool kill, Region r) {
	kill_ring_push (cur_bp.get_region (r));

	if (kill) {
		if (cur_bp.readonly)
			Minibuf.error ("Read only text copied to kill ring");
		else
			assert (r.delete ());
    }

	set_this_command (LispFunc.find ("kill-region"));
	cur_bp.mark_active = false;

	return true;
}

bool kill_line (bool whole_line) {
	bool ok = true;
	bool only_blanks_to_end_of_line = false;
	size_t cur_line_len = cur_bp.line_len (cur_bp.pt);

	if (!whole_line) {
		size_t i;
		for (i = cur_bp.pt - cur_bp.line_o (); i < cur_line_len; i++) {
			char c = cur_bp.get_char (cur_bp.line_o () + i);
			if (!(c == ' ' || c == '\t'))
				break;
        }

		only_blanks_to_end_of_line = i == cur_line_len;
    }

	if (cur_bp.eobp ()) {
		Minibuf.error ("End of buffer");
		return false;
    }

	if (!cur_bp.eolp ())
		ok = copy_or_kill_region (true, new Region (cur_bp.pt, cur_bp.line_o () + cur_line_len));

	if (ok && (whole_line || only_blanks_to_end_of_line) && !cur_bp.eobp ()) {
		if (!funcall ("delete-char"))
			return false;

		kill_ring_push (ImmutableEstr.of ("\n", "\n".length));
		set_this_command (LispFunc.find ("kill-region"));
    }

	return ok;
}

bool kill_whole_line () {
	return kill_line (true);
}

bool kill_line_backward () {
	return cur_bp.move_line (-1) && kill_whole_line ();
}

bool copy_or_kill_the_region (bool kill) {
	bool ok = false;

	if (!cur_bp.warn_if_no_mark ()) {
		Region r = Region.calculate ();
		maybe_destroy_kill_ring ();
		ok = copy_or_kill_region (kill, r);
    }

	return ok;
}

bool kill_text (long uniarg, Function mark_func) {
	maybe_destroy_kill_ring ();

	if (cur_bp.warn_if_readonly ())
		return false;

	push_mark ();
	mark_func (uniarg, null);
	funcall ("kill-region");
	pop_mark ();

	set_this_command (LispFunc.find ("kill-region"));
	Minibuf.write ("%s", "");		/* Erase "Set mark" message.  */
	return true;
}


public void killring_init () {
	new LispFunc (
		"kill-line",
		(uniarg, args) => {
			maybe_destroy_kill_ring ();

			bool ok = true;
			if (noarg (args))
				ok = kill_line (cur_bp.bolp () && get_variable_bool ("kill-whole-line"));
			else {
				long arg = 1;
				if (!int_or_uniarg (args, ref arg, uniarg))
					ok = false;
				else {
					if (arg <= 0)
						ok = cur_bp.bolp () || copy_or_kill_region (true, new Region (cur_bp.line_o (), cur_bp.pt));
					if (arg != 0 && ok)
						ok = execute_with_uniarg (arg, kill_whole_line, kill_line_backward);
				}
			}

			cur_bp.mark_active = false;
			return ok;
		},
		true,
		"""Kill the rest of the current line; if no nonblanks there, kill thru newline.
With prefix argument ARG, kill that many lines from point.
Negative arguments kill lines backward.
With zero argument, kills the text before point on the current line.

If `kill-whole-line' is non-nil, then this command kills the whole line
including its terminating newline, when used at the beginning of a line
with no argument."""
		);

	new LispFunc (
		"kill-region",
		(uniarg, args) => {
			return copy_or_kill_the_region (true);
		},
		true,
		"""Kill (\"cut\") text between point and mark.
This deletes the text from the buffer and saves it in the kill ring.
The command \\[yank] can retrieve it from there.

Any command that calls this function is a \"kill command\".
If the previous command was also a kill command,
the text killed this time appends to the text killed last time
to make one entry in the kill ring.

If the buffer is read-only, Zile will beep and refrain from deleting
the text, but put the text in the kill ring anyway.  This means that
you can use the killing commands to copy text from a read-only buffer."""
		);

	new LispFunc (
		"copy-region-as-kill",
		(uniarg, args) => {
			return copy_or_kill_the_region (false);
		},
		true,
		"""Save the region as if killed, but don't kill it."""
		);

	new LispFunc (
		"kill-word",
		(uniarg, args) => {
			bool ok = true;
			long arg = 1;
			if (!noarg (args) &&
				!int_or_uniarg (args, ref arg, uniarg))
				ok = false;
			if (ok)
				ok = kill_text (arg, LispFunc.find ("mark-word").func);
			return ok;
		},
		true,
		"""Kill characters forward until encountering the end of a word.
With argument ARG, do this that many times."""
		);

	new LispFunc (
		"backward-kill-word",
		(uniarg, args) => {
			bool ok = true;
			long arg = 1;
			if (!noarg (args) &&
				!int_or_uniarg (args, ref arg, uniarg))
				ok = false;
			if (ok)
				ok = kill_text (-arg, LispFunc.find ("mark-word").func);
			return ok;
		},
		true,
		"""Kill characters backward until encountering the end of a word.
With argument ARG, do this that many times."""
		);

	new LispFunc (
		"kill-sexp",
		(uniarg, args) => {
			return kill_text (uniarg, LispFunc.find ("mark-sexp").func);
		},
		true,
		"""Kill the sexp (balanced expression) following the cursor.
With ARG, kill that many sexps after the cursor.
Negative arg -N means kill N sexps before the cursor."""
		);

	new LispFunc (
		"yank",
		(uniarg, args) => {
			if (kill_ring_text == null) {
				Minibuf.error ("Kill ring is empty");
				return false;
			}

			if (cur_bp.warn_if_readonly ())
				return false;

			funcall ("set-mark-command");
			cur_bp.insert_estr (kill_ring_text);
			cur_bp.mark_active = false;
			return true;
		},
		true,
		"""Reinsert (\"paste\") the last stretch of killed text.
More precisely, reinsert the stretch of killed text most recently
killed OR yanked.  Put point at end, and set mark at beginning."""
		);
}
