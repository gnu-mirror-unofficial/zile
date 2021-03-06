/* Key encoding and decoding functions

   Copyright (c) 1997-2021 Free Software Foundation, Inc.

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
public const Keystroke KBD_NOKEY = uint.MAX;

/* Key modifiers. */
public const Keystroke KBD_CTRL = 01000;
public const Keystroke KBD_META = 02000;

/* Common non-alphanumeric keys. */
public const Keystroke KBD_CANCEL = (KBD_CTRL | 'g');
public const Keystroke KBD_TAB = 00402;
public const Keystroke KBD_RET = 00403;
public const Keystroke KBD_PGUP = 00404;
public const Keystroke KBD_PGDN = 00405;
public const Keystroke KBD_HOME = 00406;
public const Keystroke KBD_END = 00407;
public const Keystroke KBD_DEL = 00410;
public const Keystroke KBD_BS = 00411;
public const Keystroke KBD_INS = 00412;
public const Keystroke KBD_LEFT = 00413;
public const Keystroke KBD_RIGHT = 00414;
public const Keystroke KBD_UP = 00415;
public const Keystroke KBD_DOWN = 00416;
public const Keystroke KBD_F1 = 00420;
public const Keystroke KBD_F2 = 00421;
public const Keystroke KBD_F3 = 00422;
public const Keystroke KBD_F4 = 00423;
public const Keystroke KBD_F5 = 00424;
public const Keystroke KBD_F6 = 00425;
public const Keystroke KBD_F7 = 00426;
public const Keystroke KBD_F8 = 00427;
public const Keystroke KBD_F9 = 00430;
public const Keystroke KBD_F10 = 00431;
public const Keystroke KBD_F11 = 00432;
public const Keystroke KBD_F12 = 00433;

struct KeyInfo {
	Keystroke code;
	string name;
	string desc;
}

const KeyInfo[] keyinfo = {
	{ KBD_BS, "\\BACKSPACE", "<backspace>" },
	{ KBD_CTRL, "\\C-", "C-" },
	{ KBD_DEL, "\\DELETE", "<delete>" },
	{ KBD_DOWN, "\\DOWN", "<down>" },
	/* FIXME: Kludge to make keystrings work in both Emacs and Zile. */
	{ 033, "\\e", null },
	{ KBD_END, "\\END", "<end>" },
	{ KBD_F1, "\\F1", "<f1>" },
	{ KBD_F10, "\\F10", "<f10>" },
	{ KBD_F11, "\\F11", "<f11>" },
	{ KBD_F12, "\\F12", "<f12>" },
	{ KBD_F2, "\\F2", "<f2>" },
	{ KBD_F3, "\\F3", "<f3>" },
	{ KBD_F4, "\\F4", "<f4>" },
	{ KBD_F5, "\\F5", "<f5>" },
	{ KBD_F6, "\\F6", "<f6>" },
	{ KBD_F7, "\\F7", "<f7>" },
	{ KBD_F8, "\\F8", "<f8>" },
	{ KBD_F9, "\\F9", "<f9>" },
	{ KBD_HOME, "\\HOME", "<home>" },
	{ KBD_INS, "\\INSERT", "<insert>" },
	{ KBD_LEFT, "\\LEFT", "<left>" },
	{ KBD_META, "\\M-", "M-" },
	{ KBD_PGDN, "\\NEXT", "<next>" },
	{ KBD_PGDN, "\\PAGEDOWN", "<pagedown>" },
	{ KBD_PGUP, "\\PAGEUP", "<pageup>" },
	{ KBD_PGUP, "\\PRIOR", "<prior>" },
	{ KBD_RET, "\\RET", "<RET>" },
	/* FIXME: Kludge to make keystrings work in both Emacs and Zile. */
	{ KBD_RET, "\\r", null },
	{ KBD_RIGHT, "\\RIGHT", "<right>" },
	{ ' ', "\\SPC", "SPC" },
	{ KBD_TAB, "\\TAB", "<TAB>" },
	{ KBD_TAB, "\\t", null },
	{ KBD_UP, "\\UP", "<up>" },
	{ '\\', "\\\\", "\\" },
};

/*
 * Convert a key code to its string.
 */
string? keytostr (Keystroke key) {
	for (uint i = 0; i < keyinfo.length; i++)
		if (keyinfo[i].code == key)
			return keyinfo[i].name;
	if (key <= 0xff && ((char) key).isgraph ())
		return ((char) key).to_string ();
	return null;
}

/*
 * Convert a key code to its description.
 */
string keytodesc (Keystroke key) {
	for (uint i = 0; i < keyinfo.length; i++)
		if (keyinfo[i].code == key)
			return keyinfo[i].desc;
	if (key <= 0xff && ((char) key).isgraph ())
		return ((char) key).to_string ();
	return "<%zx>".printf (key);
}

/*
 * Convert a key chord into its ASCII representation
 */
delegate string? KeyStringifier (Keystroke key);
string? chordtostr (Keystroke key, KeyStringifier func) {
	string chord_string = "";

	if ((key & KBD_CTRL) != 0)
		chord_string += func (KBD_CTRL);
	if ((key & KBD_META) != 0)
		chord_string += func (KBD_META);
	key &= ~(KBD_CTRL | KBD_META);

	string? key_string = func (key);
	if (key_string != null)
		return chord_string + key_string;
	return null;
}

/*
 * Convert a key chord into its text description
 */
string chordtodesc (Keystroke key) {
	return chordtostr (key, keytodesc);
}

/*
 * Convert a key string to its key code.
 */
Keystroke strtokey (string buf, out Keystroke len) {
	if (buf[0] == '\\') {
		for (Keystroke i = 0; i < keyinfo.length; i++)
			if (buf.has_prefix (keyinfo[i].name)) {
				len = keyinfo[i].name.length;
				return keyinfo[i].code;
			}
		len = 0;
		return KBD_NOKEY;
    } else {
		len = 1;
		return (Keystroke) buf[0];
    }
}

/*
 * Convert a key chord string to its key code.
 */
Keystroke strtochord (string buf, out Keystroke len) {
	Keystroke key = 0, k = 0;

	len = 0;
	do {
		Keystroke l;

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
Gee.List<Keystroke>? keystrtovec (string key)
{
	var keys = new ArrayList<Keystroke> ();
	for (Keystroke i = 0, len = 0; i < key.length; i += len) {
		Keystroke code = strtochord (key.substring (i), out len);
		if (code == KBD_NOKEY)
			return null;
		keys.add (code);
	}

	return keys;
}

/*
 * Convert a key code sequence into a string.
 */
string keyvectostr (Gee.List<Keystroke> keys) {
	string key_string = "";
	foreach (Keystroke keycode in keys)
		key_string += chordtostr (keycode, keytostr);
	return key_string;
}

/*
 * Convert a key code sequence into a descriptive string.
 */
string keyvectodesc (Gee.List<Keystroke> keys) {
	var key_strings = new string[0];
	foreach (Keystroke keycode in keys)
		key_strings += chordtodesc (keycode);
	return string.joinv (" ", key_strings);
}
