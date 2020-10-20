/* Curses terminal

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

using Gee;

using Curses;

static Gee.List<uint> key_buf;

static uint backspace_code = 0177;

public uint term_buf_len () {
	return key_buf.size;
}

public void term_move (size_t y, size_t x) {
	move ((int) y, (int) x);
}

public void term_clrtoeol () {
	clrtoeol ();
}

public void term_refresh () {
	refresh ();
}

public void term_clear () {
	clear ();
}

public void term_addch (char c) {
	addch (c);
}

public void term_addstr (string s) {
	addstr (s);
}

public void term_attrset (size_t attr) {
	int attrs = 0;
	if ((attr & FONT_REVERSE) != 0)
		attrs |= Attribute.REVERSE;
	if ((attr & FONT_UNDERLINE) != 0)
		attrs |= Attribute.UNDERLINE;
	attrset (attrs);
}

public void term_beep () {
	beep ();
}

public size_t term_width () {
	return (size_t) COLS;
}

public size_t term_height () {
	return (size_t) LINES;
}

public void term_init () {
	initscr ();
	noecho ();
	nonl ();
	raw ();
	stdscr.meta (true);
	stdscr.intrflush (false);
	stdscr.keypad (true);
	key_buf = new ArrayList<uint> ();
	unowned string? kbs = tigetstr ("kbs");
	if (kbs != null && kbs.length == 1)
		backspace_code = kbs[0];
}

public void term_close () {
	/* Finish with ncurses. */
	endwin ();
}

static uint codetokey (uint c) {
	switch (c) {
    case '\0':			/* C-@ */
		return KBD_CTRL | '@';
    case 01:
    case 02:
    case 03:
    case 04:
    case 05:
    case 06:
    case 07:
    case 010:
    case 012:
    case 013:
    case 014:
    case 016:
    case 017:
    case 020:
    case 021:
    case 022:
    case 023:
    case 024:
    case 025:
    case 026:
    case 027:
    case 030:
    case 031:
    case 032:			/* C-a ... C-z */
		return KBD_CTRL | ('a' + c - 1);
    case 011:
		return KBD_TAB;
    case 015:
		return KBD_RET;
    case 037:
		return KBD_CTRL | '_';
    case Key.SUSPEND:	/* C-z */
		return KBD_CTRL | 'z';
    case 033:			/* META */
		return KBD_META;
    case Key.PPAGE:		/* PGUP */
		return KBD_PGUP;
    case Key.NPAGE:		/* PGDN */
		return KBD_PGDN;
    case Key.HOME:
		return KBD_HOME;
    case Key.END:
		return KBD_END;
    case Key.DC:		/* DEL */
		return KBD_DEL;
    case Key.BACKSPACE:		/* Backspace or Ctrl-H */
		return codetokey (backspace_code);
    case 0177:			/* BS */
		return KBD_BS;
    case Key.IC:		/* INSERT */
		return KBD_INS;
    case Key.LEFT:
		return KBD_LEFT;
    case Key.RIGHT:
		return KBD_RIGHT;
    case Key.UP:
		return KBD_UP;
    case Key.DOWN:
		return KBD_DOWN;
    default:
		if (c == Key.F (1))
			return KBD_F1;
		else if (c == Key.F (2))
			return KBD_F2;
		else if (c == Key.F (3))
			return KBD_F3;
		else if (c == Key.F (4))
			return KBD_F4;
		else if (c == Key.F (5))
			return KBD_F5;
		else if (c == Key.F (6))
			return KBD_F6;
		else if (c == Key.F (7))
			return KBD_F7;
		else if (c == Key.F (8))
			return KBD_F8;
		else if (c == Key.F (9))
			return KBD_F9;
		else if (c == Key.F (10))
			return KBD_F10;
		else if (c == Key.F (11))
			return KBD_F11;
		else if (c == Key.F (12))
			return KBD_F12;
		else if (c > 0xff)
			return KBD_NOKEY;	/* ERR (no key) or undefined behaviour. */
		return c;
    }
}

static Gee.List<uint> keytocodes (uint key) {
	var codevec = new ArrayList<uint> ();

	if (key == KBD_NOKEY)
		return codevec;

	if ((key & KBD_META) != 0)		/* META */
		codevec.add (033);
	key &= ~KBD_META;

	switch (key) {
    case KBD_CTRL | '@':			/* C-@ */
		codevec.add ('\0');
		break;
    case KBD_CTRL | 'a':
    case KBD_CTRL | 'b':
    case KBD_CTRL | 'c':
    case KBD_CTRL | 'd':
    case KBD_CTRL | 'e':
    case KBD_CTRL | 'f':
    case KBD_CTRL | 'g':
    case KBD_CTRL | 'h':
    case KBD_CTRL | 'j':
    case KBD_CTRL | 'k':
    case KBD_CTRL | 'l':
    case KBD_CTRL | 'n':
    case KBD_CTRL | 'o':
    case KBD_CTRL | 'p':
    case KBD_CTRL | 'q':
    case KBD_CTRL | 'r':
    case KBD_CTRL | 's':
    case KBD_CTRL | 't':
    case KBD_CTRL | 'u':
    case KBD_CTRL | 'v':
    case KBD_CTRL | 'w':
    case KBD_CTRL | 'x':
    case KBD_CTRL | 'y':
    case KBD_CTRL | 'z':	/* C-a ... C-z */
		codevec.add ((key & ~KBD_CTRL) + 1 - 'a');
		break;
    case KBD_TAB:
		codevec.add (011);
		break;
    case KBD_RET:
		codevec.add (015);
		break;
    case KBD_CTRL | '_':
		codevec.add (037);
		break;
    case KBD_PGUP:		/* PGUP */
		codevec.add (Key.PPAGE);
		break;
    case KBD_PGDN:		/* PGDN */
		codevec.add (Key.NPAGE);
		break;
    case KBD_HOME:
		codevec.add (Key.HOME);
		break;
    case KBD_END:
		codevec.add (Key.END);
		break;
    case KBD_DEL:		/* DEL */
		codevec.add (Key.DC);
		break;
    case KBD_BS:		/* BS */
		codevec.add (0177);
		break;
    case KBD_INS:		/* INSERT */
		codevec.add (Key.IC);
		break;
    case KBD_LEFT:
		codevec.add (Key.LEFT);
		break;
    case KBD_RIGHT:
		codevec.add (Key.RIGHT);
		break;
    case KBD_UP:
		codevec.add (Key.UP);
		break;
    case KBD_DOWN:
		codevec.add (Key.DOWN);
		break;
    case KBD_F1:
		codevec.add (Key.F (1));
		break;
    case KBD_F2:
		codevec.add (Key.F (2));
		break;
    case KBD_F3:
		codevec.add (Key.F (3));
		break;
    case KBD_F4:
		codevec.add (Key.F (4));
		break;
    case KBD_F5:
		codevec.add (Key.F (5));
		break;
    case KBD_F6:
		codevec.add (Key.F (6));
		break;
    case KBD_F7:
		codevec.add (Key.F (7));
		break;
    case KBD_F8:
		codevec.add (Key.F (8));
		break;
    case KBD_F9:
		codevec.add (Key.F (9));
		break;
    case KBD_F10:
		codevec.add (Key.F (10));
		break;
    case KBD_F11:
		codevec.add (Key.F (11));
		break;
    case KBD_F12:
		codevec.add (Key.F (12));
		break;
    default:
		if ((key & 0xff) == key)
			codevec.add (key);
		break;
    }

	return codevec;
}

static uint get_char (int delay) {
	uint c = 0;

	uint size = term_buf_len ();
	if (size > 0) {
		c = key_buf[(int) size - 1];
		key_buf.remove_at ((int) size - 1);
    } else {
		timeout (delay);

		do {
			c = getch ();

			if (c == Key.RESIZE)
				resize_windows ();
		} while (c == Key.RESIZE);
    }

	return c;
}

public uint term_getkey (int delay) {
	uint key = codetokey (get_char (delay));
	while (key == KBD_META)
		key = codetokey (get_char (GETKEY_DEFAULT)) | KBD_META;
	return key;
}

public uint term_getkey_unfiltered (int delay) {
	stdscr.keypad (false);
	uint key = get_char (delay);
	stdscr.keypad (true);
	return key;
}

public void term_ungetkey (uint key) {
	Gee.List<uint> codes = keytocodes (key);
	for (int i = codes.size; i > 0; i--)
		key_buf.add (codes[i - 1]);
}
