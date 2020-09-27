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
   along with GNU Zile; see the file COPYING.  If not, write to the
   Free Software Foundation, Fifth Floor, 51 Franklin Street, Boston,
   MA 02111-1301, USA.  */

using Lisp;

Estr *kill_ring_text;

void maybe_destroy_kill_ring () {
	if (last_command () != F_kill_region)
		kill_ring_text = null;
}

void kill_ring_push (Estr *es) {
	if (kill_ring_text == null)
		kill_ring_text = estr_new_astr (Astr.new_ ());
	estr_cat (kill_ring_text, es);
}

bool copy_or_kill_region (bool kill, Region r) {
	kill_ring_push (get_buffer_region (cur_bp, r));

	if (kill) {
		if (cur_bp.readonly)
			Minibuf.error ("Read only text copied to kill ring");
		else
			assert (r.delete ());
    }

	set_this_command ((void *) F_kill_region);
	deactivate_mark ();

	return true;
}

bool kill_line (bool whole_line) {
	bool ok = true;
	bool only_blanks_to_end_of_line = false;
	size_t cur_line_len = buffer_line_len (cur_bp, cur_bp.pt);

	if (!whole_line) {
		size_t i;
		for (i = cur_bp.pt - get_buffer_line_o (cur_bp); i < cur_line_len; i++) {
			char c = get_buffer_char (cur_bp, get_buffer_line_o (cur_bp) + i);
			if (!(c == ' ' || c == '\t'))
				break;
        }

		only_blanks_to_end_of_line = i == cur_line_len;
    }

	if (eobp ()) {
		Minibuf.error ("End of buffer");
		return false;
    }

	if (!eolp ())
		ok = copy_or_kill_region (true, new Region (cur_bp.pt, get_buffer_line_o (cur_bp) + cur_line_len));

	if (ok && (whole_line || only_blanks_to_end_of_line) && !eobp ()) {
		if (!funcall (F_delete_char))
			return false;

		kill_ring_push (estr_new_astr (Astr.new_cstr ("\n")));
		set_this_command ((void *) F_kill_region);
    }

	return ok;
}

bool kill_whole_line () {
	return kill_line (true);
}

bool kill_line_backward () {
	return previous_line () && kill_whole_line ();
}

/*
DEFUN_ARGS ("kill-line", kill_line, INT_OR_UNIARG (arg))
*+
Kill the rest of the current line; if no nonblanks there, kill thru newline.
With prefix argument ARG, kill that many lines from point.
Negative arguments kill lines backward.
With zero argument, kills the text before point on the current line.

If `kill-whole-line' is non-nil, then this command kills the whole line
including its terminating newline, when used at the beginning of a line
with no argument.
+*/
public bool F_kill_line (long uniarg, Lexp *arglist) {
	maybe_destroy_kill_ring ();

	bool ok = true;
	if (noarg (arglist))
		ok = kill_line (bolp () && get_variable_bool ("kill-whole-line"));
	else {
		long arg = 1;
		if (!int_or_uniarg_init (ref arglist, ref arg, uniarg))
			ok = false;
		else {
			if (arg <= 0)
				ok = bolp () || copy_or_kill_region (true, new Region (get_buffer_line_o (cur_bp), cur_bp.pt));
			if (arg != 0 && ok)
				ok = execute_with_uniarg (arg, kill_whole_line, kill_line_backward);
		}
	}

	deactivate_mark ();
	return ok;
}

bool copy_or_kill_the_region (bool kill) {
	bool ok = false;

	if (!warn_if_no_mark ()) {
		Region r = Region.calculate ();
		maybe_destroy_kill_ring ();
		ok = copy_or_kill_region (kill, r);
    }

	return ok;
}

/*
DEFUN ("kill-region", kill_region)
*+
Kill (\"cut\") text between point and mark.
This deletes the text from the buffer and saves it in the kill ring.
The command \\[yank] can retrieve it from there.

Any command that calls this function is a \"kill command\".
If the previous command was also a kill command,
the text killed this time appends to the text killed last time
to make one entry in the kill ring.

If the buffer is read-only, Zile will beep and refrain from deleting
the text, but put the text in the kill ring anyway.  This means that
you can use the killing commands to copy text from a read-only buffer.
+*/
public bool F_kill_region (long uniarg, Lexp *arglist) {
	return copy_or_kill_the_region (true);
}

/*
DEFUN ("copy-region-as-kill", copy_region_as_kill)
*+
Save the region as if killed, but don't kill it.
+*/
public bool F_copy_region_as_kill (long uniarg, Lexp *arglist) {
	return copy_or_kill_the_region (false);
}

bool kill_text (long uniarg, Function mark_func) {
	maybe_destroy_kill_ring ();

	if (warn_if_readonly_buffer ())
		return false;

	push_mark ();
	mark_func (uniarg, null);
	funcall (F_kill_region);
	pop_mark ();

	set_this_command ((void *) F_kill_region);
	Minibuf.write ("%s", "");		/* Erase "Set mark" message.  */
	return true;
}

/*
DEFUN_ARGS ("kill-word", kill_word, INT_OR_UNIARG (arg))
*+
Kill characters forward until encountering the end of a word.
With argument ARG, do this that many times.
+*/
public bool F_kill_word (long uniarg, Lexp *arglist) {
	bool ok = true;
	long arg = 1;
	if (!noarg (arglist) &&
		!int_or_uniarg_init (ref arglist, ref arg, uniarg))
		ok = false;
	if (ok)
		ok = kill_text (arg, F_mark_word);
	return ok;
}

/*
DEFUN_ARGS ("backward-kill-word", backward_kill_word, INT_OR_UNIARG (arg))
*+
Kill characters backward until encountering the end of a word.
With argument ARG, do this that many times.
+*/
public bool F_backward_kill_word (long uniarg, Lexp *arglist) {
	bool ok = true;
	long arg = 1;
	if (!noarg (arglist) &&
		!int_or_uniarg_init (ref arglist, ref arg, uniarg))
		ok = false;
	if (ok)
		ok = kill_text (-arg, F_mark_word);
	return ok;
}

/*
DEFUN ("kill-sexp", kill_sexp)
*+
Kill the sexp (balanced expression) following the cursor.
With ARG, kill that many sexps after the cursor.
Negative arg -N means kill N sexps before the cursor.
+*/
public bool F_kill_sexp (long uniarg, Lexp *arglist) {
	return kill_text (uniarg, F_mark_sexp);
}

/*
DEFUN ("yank", yank)
*+
Reinsert (\"paste\") the last stretch of killed text.
More precisely, reinsert the stretch of killed text most recently
killed OR yanked.  Put point at end, and set mark at beginning.
+*/
public bool F_yank (long uniarg, Lexp *arglist) {
	if (kill_ring_text == null) {
		Minibuf.error ("Kill ring is empty");
		return false;
    }

	if (warn_if_readonly_buffer ())
		return false;

	funcall (F_set_mark_command);
	insert_estr (kill_ring_text);
	deactivate_mark ();
	return true;
}
