/* Basic movement functions

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

/*
 * Get the goal column.  Take care of expanding tabulations.
 */
public size_t get_goalc_bp (Buffer bp, size_t o) {
	size_t col = 0, t = tab_width (bp);
	size_t start = buffer_start_of_line (bp, o), end = o - start;

	for (size_t i = 0; i < end; i++, col++)
		if (get_buffer_char (bp, start + i) == '\t')
			col |= t - 1;

	return col;
}

public size_t get_goalc () {
	return get_goalc_bp (cur_bp, cur_bp.pt);
}

public bool previous_line () {
	return move_line (-1);
}

public bool next_line () {
	return move_line (1);
}

bool scroll_down () {
	if (!cur_wp.top_visible ())
		return move_line (-(long) cur_wp.eheight);

	Minibuf.error ("Beginning of buffer");
	return false;
}

bool scroll_up () {
	if (!cur_wp.bottom_visible ())
		return move_line ((long) cur_wp.eheight);

	Minibuf.error ("End of buffer");
	return false;
}


public void basic_init () {
	new LispFunc (
		"beginning-of-line",
		(uniarg, arglist) => {
			goto_offset (get_buffer_line_o (cur_bp));
			cur_bp.goalc = 0;
			return true;
		},
		true,
		"""Move point to beginning of current line."""
		);

	new LispFunc (
		"end-of-line",
		(uniarg, arglist) => {
			goto_offset (get_buffer_line_o (cur_bp) + buffer_line_len (cur_bp, cur_bp.pt));
			cur_bp.goalc = size_t.MAX;
			return true;
		},
		true,
		"""Move point to end of current line."""
		);

	new LispFunc (
		"previous-line",
		(uniarg, arglist) => {
			return move_line (-uniarg);
		},
		true,
		"""Move cursor vertically up one line.
If there is no character in the target line exactly over the current column,
the cursor is positioned after the character in that line which spans this
column, or at the end of the line if it is not long enough."""
		);

	new LispFunc (
		"next-line",
		(uniarg, arglist) => {
			return move_line (uniarg);
		},
		true,
		"""Move cursor vertically down one line.
If there is no character in the target line exactly under the current column,
the cursor is positioned after the character in that line which spans this
column, or at the end of the line if it is not long enough."""
		);

	new LispFunc (
		"goto-char",
		(uniarg, arglist) => {
			bool ok = true;
			long n = 1;
			if (noarg (arglist))
				n = Minibuf.read_number ("Goto char: ");
			else if (!int_or_uniarg_init (ref arglist, ref n, uniarg))
				ok = false;

			if (ok == false || n >= long.MAX - 1)
				return false;

			goto_offset (size_t.min (get_buffer_size (cur_bp), (size_t) long.max (n, 1) - 1));
			return ok;
		},
		true,
		"""Set point to POSITION, a number.
Beginning of buffer is position 1."""
		);

	new LispFunc (
		"goto-line",
		(uniarg, arglist) => {
			bool ok = true;
			long n = 1;
			if (noarg (arglist))
				n = Minibuf.read_number ("Goto line: ");
			else if (!int_or_uniarg_init (ref arglist, ref n, uniarg))
				ok = false;

			if (!ok || n >= long.MAX - 1)
				return false;

			move_line ((long.max (n, 1) - 1) - (long) offset_to_line (cur_bp, cur_bp.pt));
			funcall ("beginning-of-line");
			return ok;
		},
		true,
		"""Go to LINE, counting from line 1 at beginning of buffer."""
		);

	new LispFunc (
		"beginning-of-buffer",
		(uniarg, arglist) => {
			goto_offset (0);
			return true;
		},
		true,
		"""Move point to the beginning of the buffer; leave mark at previous position."""
		);

	new LispFunc (
		"end-of-buffer",
		(uniarg, arglist) => {
			goto_offset (get_buffer_size (cur_bp));
			return true;
		},
		true,
		"""Move point to the end of the buffer; leave mark at previous position."""
		);

	new LispFunc (
		"backward-char",
		(uniarg, arglist) => {
			bool ok = move_char (-uniarg);
			if (!ok)
				Minibuf.error ("Beginning of buffer");
			return ok;
		},
		true,
		"""Move point left N characters (right if N is negative).
On attempt to pass beginning or end of buffer, stop and signal error."""
		);

	new LispFunc (
		"forward-char",
		(uniarg, arglist) => {
			bool ok = move_char (uniarg);
			if (!ok)
				Minibuf.error ("End of buffer");
			return ok;
		},
		true,
		"""Move point right N characters (left if N is negative).
On reaching end of buffer, stop and signal error."""
		);

	new LispFunc (
		"scroll-down",
		(uniarg, arglist) => {
			return execute_with_uniarg (uniarg, scroll_down, scroll_up);
		},
		true,
		"""Scroll text of current window downward near full screen."""
		);

	new LispFunc (
		"scroll-up",
		(uniarg, arglist) => {
			return execute_with_uniarg (uniarg, scroll_up, scroll_down);
		},
		true,
		"""Scroll text of current window upward near full screen."""
		);
}
