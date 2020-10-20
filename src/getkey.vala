/* Getting and ungetting key strokes

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

/* Standard pauses in ds */
public const int GETKEY_DEFAULT = -1;
public const int GETKEY_DELAYED = 2000;

/* Maximum time to avoid screen updates when catching up with buffered
   input, in milliseconds. */
const int MAX_RESYNC_MS = 500;

uint _last_key;

/* Return last key pressed */
uint lastkey () {
	return _last_key;
}

/*
 * Get a keystroke, waiting for up to delay ms, and translate it into
 * a keycode.
 */
uint getkeystroke (int delay) {
	_last_key = term_getkey (delay);

	if (_last_key != KBD_NOKEY && Flags.DEFINING_MACRO in thisflag)
		add_key_to_cmd (_last_key);

	return _last_key;
}

/*
 * Return the next keystroke, refreshing the screen only when the input
 * buffer is empty, or MAX_RESYNC_MS have elapsed since the last
 * screen refresh.
 */
int64 next_refresh = 0;
const int64 refresh_wait = MAX_RESYNC_MS * 1000;
int64 now;

uint getkey (int delay) {
	uint keycode = getkeystroke (0);

	now = get_monotonic_time ();

	if (keycode == KBD_NOKEY || now >= next_refresh) {
		term_redisplay ();
		term_refresh ();
		next_refresh = now + refresh_wait;
    }

	if (keycode == KBD_NOKEY)
		keycode = getkeystroke (delay);

	return keycode;
}

uint getkey_unfiltered (int mode) {
	uint key = term_getkey_unfiltered (mode);

	_last_key = key;
	if (Flags.DEFINING_MACRO in thisflag)
		add_key_to_cmd (key);

	return key;
}

/*
 * Wait for GETKEY_DELAYED ms or until a key is pressed.  The key is
 * then available with [x]getkey.
 */
void waitkey () {
	ungetkey (getkey (GETKEY_DELAYED));
}

/*
 * Push a key into the input buffer.
 */
void pushkey (uint key) {
	term_ungetkey (key);
}

/*
 * Unget a key as if it had not been fetched.
 */
void ungetkey (uint key) {
	pushkey (key);

	if (Flags.DEFINING_MACRO in thisflag)
		remove_key_from_cmd ();
}
