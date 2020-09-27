/* Main types and definitions

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

/*--------------------------------------------------------------------------
 * Main editor structures.
 *--------------------------------------------------------------------------*/

/* Completion flags */
public const int CFLAG_POPPEDUP = 0000001;	/* Completion window has been popped up. */
public const int CFLAG_CLOSE	= 0000002;	/* The completion window should be closed. */
public const int CFLAG_FILENAME = 0000004;	/* This is a filename completion. */

/*--------------------------------------------------------------------------
 * Keyboard handling.
 *--------------------------------------------------------------------------*/

/* Standard pauses in ds */
public const int GETKEY_DEFAULT = -1;
public const int GETKEY_DELAYED = 2000;

/* Special value returned for invalid key codes, or when no key is pressed. */
public const int KBD_NOKEY = int.MAX;

/* Key modifiers. */
public const int KBD_CTRL = 01000;
public const int KBD_META = 02000;

/* Common non-alphanumeric keys. */
public const int KBD_CANCEL = (KBD_CTRL | 'g');
public const int KBD_TAB = 00402;
public const int KBD_RET = 00403;
public const int KBD_PGUP = 00404;
public const int KBD_PGDN = 00405;
public const int KBD_HOME = 00406;
public const int KBD_END = 00407;
public const int KBD_DEL = 00410;
public const int KBD_BS = 00411;
public const int KBD_INS = 00412;
public const int KBD_LEFT = 00413;
public const int KBD_RIGHT = 00414;
public const int KBD_UP = 00415;
public const int KBD_DOWN = 00416;
public const int KBD_F1 = 00420;
public const int KBD_F2 = 00421;
public const int KBD_F3 = 00422;
public const int KBD_F4 = 00423;
public const int KBD_F5 = 00424;
public const int KBD_F6 = 00425;
public const int KBD_F7 = 00426;
public const int KBD_F8 = 00427;
public const int KBD_F9 = 00430;
public const int KBD_F10 = 00431;
public const int KBD_F11 = 00432;
public const int KBD_F12 = 00433;

/*--------------------------------------------------------------------------
 * Miscellaneous stuff.
 *--------------------------------------------------------------------------*/

/* Zile font codes */
public const int FONT_NORMAL = 0000;
public const int FONT_REVERSE = 0001;
public const int FONT_UNDERLINE = 0002;

/* Custom exit code */
public const int EXIT_CRASH = 2;
