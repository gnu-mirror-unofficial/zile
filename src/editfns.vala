/* Useful editing functions

   Copyright (c) 2004-2020 Free Software Foundation, Inc.

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

public bool is_empty_line () {
	return buffer_line_len (cur_bp, cur_bp.pt) == 0;
}

public bool is_blank_line () {
	for (size_t i = 0; i < buffer_line_len (cur_bp, cur_bp.pt); i++)
    {
		char c = get_buffer_char (cur_bp, get_buffer_line_o (cur_bp) + i);
		if (c != ' ' && c != '\t')
			return false;
    }
	return true;
}

/* Returns the character following point in the current buffer. */
public char following_char () {
	if (eobp ())
		return 0;
	else if (eolp ())
		return '\n';
	else
		return get_buffer_char (cur_bp, cur_bp.pt);
}

/* Return the character preceding point in the current buffer. */
public char preceding_char () {
	if (bobp ())
		return 0;
	else if (bolp ())
		return '\n';
	else
		return get_buffer_char (cur_bp, cur_bp.pt - 1);
}

/* Return true if point is at the beginning of the buffer. */
public bool bobp () {
	return cur_bp.pt == 0;
}

/* Return true if point is at the end of the buffer. */
public bool eobp () {
	return cur_bp.pt == get_buffer_size (cur_bp);
}

/* Return true if point is at the beginning of a line. */
public bool bolp () {
	return cur_bp.pt == get_buffer_line_o (cur_bp);
}

/* Return true if point is at the end of a line. */
public bool eolp () {
	return cur_bp.pt - get_buffer_line_o (cur_bp) ==
    buffer_line_len (cur_bp, cur_bp.pt);
}

/* Signal an error, and abort any ongoing macro definition. */
public void ding () {
	if (Flags.DEFINING_MACRO in thisflag)
		cancel_kbd_macro ();

	if (get_variable_bool ("ring-bell"))
		term_beep ();
}
