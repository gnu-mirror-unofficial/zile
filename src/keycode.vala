/* Key encoding and decoding functions

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

using Gee;

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

/*
 * Convert a key chord into its ASCII representation
 */
string chordtodesc (size_t key) {
	string a = "";

	if ((key & KBD_CTRL) != 0)
		a += "C-";
	if ((key & KBD_META) != 0)
		a += "M-";
	key &= ~(KBD_CTRL | KBD_META);

	switch (key) {
    case KBD_PGUP:
		a += "<prior>";
		break;
    case KBD_PGDN:
		a += "<next>";
		break;
    case KBD_HOME:
		a += "<home>";
		break;
    case KBD_END:
		a += "<end>";
		break;
    case KBD_DEL:
		a += "<delete>";
		break;
    case KBD_BS:
		a += "<backspace>";
		break;
    case KBD_INS:
		a += "<insert>";
		break;
    case KBD_LEFT:
		a += "<left>";
		break;
    case KBD_RIGHT:
		a += "<right>";
		break;
    case KBD_UP:
		a += "<up>";
		break;
    case KBD_DOWN:
		a += "<down>";
		break;
    case KBD_RET:
		a += "<RET>";
		break;
    case KBD_TAB:
		a += "<TAB>";
		break;
    case KBD_F1:
		a += "<f1>";
		break;
    case KBD_F2:
		a += "<f2>";
		break;
    case KBD_F3:
		a += "<f3>";
		break;
    case KBD_F4:
		a += "<f4>";
		break;
    case KBD_F5:
		a += "<f5>";
		break;
    case KBD_F6:
		a += "<f6>";
		break;
    case KBD_F7:
		a += "<f7>";
		break;
    case KBD_F8:
		a += "<f8>";
		break;
    case KBD_F9:
		a += "<f9>";
		break;
    case KBD_F10:
		a += "<f10>";
		break;
    case KBD_F11:
		a += "<f11>";
		break;
    case KBD_F12:
		a += "<f12>";
		break;
    case ' ':
		a += "SPC";
		break;
    default:
		if (key <= 0xff && ((char) key).isgraph ())
			a += ((char) key).to_string ();
		else
			a += "<%zx>".printf (key);
		break;
    }

	return a;
}

/*
 * Array of key names
 */
const string[] keyname = {
  "\\BACKSPACE",
  "\\C-",
  "\\DELETE",
  "\\DOWN",
  "\\e", /* FIXME: Kludge to make keystrings work in both Emacs and Zile. */
  "\\END",
  "\\F1",
  "\\F10",
  "\\F11",
  "\\F12",
  "\\F2",
  "\\F3",
  "\\F4",
  "\\F5",
  "\\F6",
  "\\F7",
  "\\F8",
  "\\F9",
  "\\HOME",
  "\\INSERT",
  "\\LEFT",
  "\\M-",
  "\\NEXT",
  "\\PAGEDOWN",
  "\\PAGEUP",
  "\\PRIOR",
  "\\r", /* FIXME: Kludge to make keystrings work in both Emacs and Zile. */
  "\\RET",
  "\\RIGHT",
  "\\SPC",
  "\\t",
  "\\TAB",
  "\\UP",
  "\\\\",
};

/*
 * Array of key codes in the same order as keyname above
 */
const int[] keycode = {
  KBD_BS,
  KBD_CTRL,
  KBD_DEL,
  KBD_DOWN,
  033,
  KBD_END,
  KBD_F1,
  KBD_F10,
  KBD_F11,
  KBD_F12,
  KBD_F2,
  KBD_F3,
  KBD_F4,
  KBD_F5,
  KBD_F6,
  KBD_F7,
  KBD_F8,
  KBD_F9,
  KBD_HOME,
  KBD_INS,
  KBD_LEFT,
  KBD_META,
  KBD_PGDN,
  KBD_PGDN,
  KBD_PGUP,
  KBD_PGUP,
  KBD_RET,
  KBD_RET,
  KBD_RIGHT,
  ' ',
  KBD_TAB,
  KBD_TAB,
  KBD_UP,
  '\\',
};

/*
 * Convert a key string to its key code.
 */
uint strtokey (string buf, out uint len) {
	if (buf[0] == '\\') {
		for (uint i = 0; i < keyname.length; i++)
			if (buf.has_prefix (keyname[i])) {
				len = keyname[i].length;
				return keycode[i];
			}
		len = 0;
		return KBD_NOKEY;
    } else {
		len = 1;
		return (uint) buf[0];
    }
}

/*
 * Convert a key chord string to its key code.
 */
uint strtochord (string buf, out uint len) {
	uint key = 0, k = 0;

	len = 0;
	do {
		uint l;

		k = strtokey (buf.substring (len), out l);
		if (k == KBD_NOKEY) {
			len = 0;
			return KBD_NOKEY;
        }
		len += l;
		key |= k;
    } while (k == KBD_CTRL || k == KBD_META);

	return key;
}

/*
 * Convert a key sequence string into a key code sequence, or null if
 * it can't be converted.
 */
Gee.List<uint>? keystrtovec (string key)
{
	var keys = new ArrayList<uint> ();
	for (uint i = 0, len = 0; i < key.length; i += len) {
		uint code = strtochord (key.substring (i), out len);
		if (code == KBD_NOKEY)
			return null;
		keys.add (code);
	}

	return keys;
}

/*
 * Convert a key code sequence into a descriptive string.
 */
string keyvectodesc (Gee.List<uint> keys) {
	var key_strings = new string[0];
	foreach (uint keycode in keys)
		key_strings += chordtodesc ((size_t) keycode);
	return string.joinv (" ", key_strings);
}
