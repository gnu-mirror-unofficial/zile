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
DEFUN ("beginning-of-line", beginning_of_line)
*+
Move point to beginning of current line.
+*/
public bool F_beginning_of_line (long uniarg, Lexp *arglist) {
	goto_offset (get_buffer_line_o (cur_bp));
	cur_bp.goalc = 0;
	return true;
}

/*
DEFUN ("end-of-line", end_of_line)
*+
Move point to end of current line.
+*/
public bool F_end_of_line (long uniarg, Lexp *arglist) {
	goto_offset (get_buffer_line_o (cur_bp) + buffer_line_len (cur_bp, cur_bp.pt));
	cur_bp.goalc = size_t.MAX;
	return true;
}

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

/*
DEFUN ("previous-line", previous_line)
*+
Move cursor vertically up one line.
If there is no character in the target line exactly over the current column,
the cursor is positioned after the character in that line which spans this
column, or at the end of the line if it is not long enough.
+*/
public bool F_previous_line (long uniarg, Lexp *arglist) {
	return move_line (-uniarg);
}

/*
DEFUN ("next-line", next_line)
*+
Move cursor vertically down one line.
If there is no character in the target line exactly under the current column,
the cursor is positioned after the character in that line which spans this
column, or at the end of the line if it is not long enough.
+*/
public bool F_next_line (long uniarg, Lexp *arglist) {
	return move_line (uniarg);
}

/*
DEFUN_ARGS ("goto-char", goto_char, INT_OR_UNIARG (n))
*+
Set point to POSITION, a number.
Beginning of buffer is position 1.
+*/
public bool F_goto_char (long uniarg, Lexp *arglist) {
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
}

/*
DEFUN_ARGS ("goto-line", goto_line, INT_OR_UNIARG (n))
*+
Go to LINE, counting from line 1 at beginning of buffer.
+*/
public bool F_goto_line (long uniarg, Lexp *arglist) {
	bool ok = true;
	long n = 1;
	if (noarg (arglist))
		n = Minibuf.read_number ("Goto line: ");
	else if (!int_or_uniarg_init (ref arglist, ref n, uniarg))
		ok = false;

	if (!ok || n >= long.MAX - 1)
		return false;

	move_line ((long.max (n, 1) - 1) - (long) offset_to_line (cur_bp, cur_bp.pt));
	funcall (F_beginning_of_line);
	return ok;
}

/*
DEFUN ("beginning-of-buffer", beginning_of_buffer)
*+
Move point to the beginning of the buffer; leave mark at previous position.
+*/
public bool F_beginning_of_buffer (long uniarg, Lexp *arglist) {
	goto_offset (0);
	return true;
}

/*
DEFUN ("end-of-buffer", end_of_buffer)
*+
Move point to the end of the buffer; leave mark at previous position.
+*/
public bool F_end_of_buffer (long uniarg, Lexp *arglist) {
	goto_offset (get_buffer_size (cur_bp));
	return true;
}

/*
DEFUN ("backward-char", backward_char)
*+
Move point left N characters (right if N is negative).
On attempt to pass beginning or end of buffer, stop and signal error.
+*/
public bool F_backward_char (long uniarg, Lexp *arglist) {
	bool ok = move_char (-uniarg);
	if (!ok)
		Minibuf.error ("Beginning of buffer");
	return ok;
}

/*
DEFUN ("forward-char", forward_char)
*+
Move point right N characters (left if N is negative).
On reaching end of buffer, stop and signal error.
+*/
public bool F_forward_char (long uniarg, Lexp *arglist) {
	bool ok = move_char (uniarg);
	if (!ok)
		Minibuf.error ("End of buffer");
	return ok;
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

/*
DEFUN ("scroll-down", scroll_down)
*+
Scroll text of current window downward near full screen.
+*/
public bool F_scroll_down (long uniarg, Lexp *arglist) {
	return execute_with_uniarg (uniarg, scroll_down, scroll_up);
}

/*
DEFUN ("scroll-up", scroll_up)
*+
Scroll text of current window upward near full screen.
+*/
public bool F_scroll_up (long uniarg, Lexp *arglist) {
	return execute_with_uniarg (uniarg, scroll_up, scroll_down);
}
