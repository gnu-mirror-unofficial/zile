/* Redisplay engine

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

string make_char_printable (char c, size_t x, size_t cur_tab_width) {
	if (c == '\t')
		return "%*s".printf ((int) (cur_tab_width - x % cur_tab_width), "");
	if (c >= 0 && c <= 033)
		return "^%c".printf ('@' + c);
	else
		return "\\%o".printf (c & 0xff);
}

void draw_line (size_t line, size_t startcol, Window wp,
				size_t o, Region? r, bool highlight, size_t cur_tab_width) {
	term_move (line, 0);

	/* Draw body of line. */
	size_t x, i, line_len = buffer_line_len (wp.bp, o);
	for (x = 0, i = startcol;; i++) {
		term_attrset (highlight && r.contains (o + i) ? FONT_REVERSE : FONT_NORMAL);
		if (i >= line_len || x >= wp.ewidth)
			break;
		char c = get_buffer_char (wp.bp, o + i);
		if (c.isprint ()) {
			term_addch (c);
			x++;
        } else {
			string s = make_char_printable (c, x, cur_tab_width);
			term_addstr (s);
			x += s.length;
        }
    }

	/* Draw end of line. */
	if (x >= term_width ()) {
		term_move (line, term_width () - 1);
		term_attrset (FONT_NORMAL);
		term_addstr ("$");
    } else
		term_addstr ("%*s".printf ((int) (wp.ewidth - x), ""));
	term_attrset (FONT_NORMAL);
}

bool calculate_highlight_region (Window wp, out Region *rp) {
	rp = null;

	if ((wp != cur_wp && !get_variable_bool ("highlight-nonselected-windows"))
		|| wp.bp.mark == null
		|| !wp.bp.mark_active)
		return false;

	rp = new Region (wp.o (), wp.bp.mark.o);
	return true;
}

string make_mode_line_flags (Window wp) {
	if (wp.bp.modified && wp.bp.readonly)
		return "%*";
	else if (wp.bp.modified)
		return "**";
	else if (wp.bp.readonly)
		return "%%";
	return "--";
}

string make_screen_pos (Window wp) {
	bool tv = wp.top_visible ();
	bool bv = wp.bottom_visible ();

	if (tv && bv)
		return "All";
	else if (tv)
		return "Top";
	else if (bv)
		return "Bot";
	else
		return "%2d%%".printf((int) ((float) 100.0 * wp.o () / get_buffer_size (wp.bp)));
}

static void draw_status_line (size_t line, Window wp) {
	term_attrset (FONT_REVERSE);

	term_move (line, 0);
	for (size_t i = 0; i < wp.ewidth; ++i)
		term_addstr ("-");

	string eol_type;
	if (get_buffer_eol (cur_bp) == ImmutableEstr.eol_cr)
		eol_type = "(Mac)";
	else if (get_buffer_eol (cur_bp) == ImmutableEstr.eol_crlf)
		eol_type = "(DOS)";
	else
		eol_type = ":";

	term_move (line, 0);
	size_t n = offset_to_line (wp.bp, wp.o ());
	string a = "--%s%2s  %-15s   %s %-9s (Fundamental".printf (
		eol_type, make_mode_line_flags (wp), wp.bp.name,
		make_screen_pos (wp), "(%zu,%zu)".printf (
			n + 1, get_goalc_bp (wp.bp, wp.o ())
			)
		);

	if (wp.bp.autofill)
		a += " Fill";
	if (Flags.DEFINING_MACRO in thisflag)
		a += " Def";
	if (wp.bp.isearch)
		a += " Isearch";

	a += ")";
	term_addstr (a);

	term_attrset (FONT_NORMAL);
}

void draw_window (size_t topline, Window wp) {
	size_t i, o;
	Region? r;
	bool highlight = calculate_highlight_region (wp, out r);

	/* Find the first line to display on the first screen line. */
	for (o = buffer_start_of_line (wp.bp, wp.o ()), i = wp.topdelta;
		 i > 0 && o > 0;
		 assert ((o = buffer_prev_line (wp.bp, o)) != size_t.MAX), --i)
		;

	/* Draw the window lines. */
	size_t cur_tab_width = tab_width (wp.bp);
	for (i = topline; i < wp.eheight + topline; ++i) {
		/* Clear the line. */
		term_move (i, 0);
		term_clrtoeol ();

		/* If at the end of the buffer, don't write any text. */
		if (o == size_t.MAX)
			continue;

		draw_line (i, wp.start_column, wp, o, r, highlight, cur_tab_width);

		if (wp.start_column > 0) {
			term_move (i, 0);
			term_addstr("$");
        }

		o = buffer_next_line (wp.bp, o);
    }

	wp.all_displayed = o >= get_buffer_size (wp.bp);

	/* Draw the status line only if there is available space after the
	   buffer text space. */
	if (wp.fheight - wp.eheight > 0)
		draw_status_line (topline + wp.eheight, wp);
}

size_t col;
size_t cur_topline = 0;

public void term_redisplay () {
	/* Calculate the start column if the line at point has to be truncated. */
	Buffer bp = cur_wp.bp;
	size_t lastcol = 0, t = tab_width (bp);
	size_t o = cur_wp.o ();
	size_t lineo = o - get_buffer_line_o (bp);

	col = 0;
	o -= lineo;
	cur_wp.start_column = 0;

	size_t ew = cur_wp.ewidth;
	for (size_t lp = lineo; lp != size_t.MAX; --lp) {
		col = 0;
		for (size_t p = lp; p < lineo; ++p) {
			char c = get_buffer_char (bp, o + p);
			if (c.isprint ())
				col++;
			else
				col += make_char_printable (get_buffer_char (bp, o + p), col, t).length;
        }

		if (col >= ew - 1 || (lp / (ew / 3)) + 2 < lineo / (ew / 3)) {
			cur_wp.start_column = lp + 1;
			col = lastcol;
			break;
        }

		lastcol = col;
    }

	/* Draw the windows. */
	cur_topline = 0;
	size_t topline = 0;
	for (Window wp = head_wp; wp != null; wp = wp.next) {
		if (wp == cur_wp)
			cur_topline = topline;

		draw_window (topline, wp);

		topline += wp.fheight;
    }

	term_redraw_cursor ();
}

void term_redraw_cursor () {
	term_move (cur_topline + cur_wp.topdelta, col);
}

/*
 * Tidy and close the terminal ready to leave Zile.
 */
public void term_finish () {
	term_move (term_height () - 1, 0);
	term_clrtoeol ();
	term_attrset (FONT_NORMAL);
	term_refresh ();
	term_close ();
}
