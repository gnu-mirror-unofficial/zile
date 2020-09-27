/* Dynamically allocated strings

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

/*
 * The astr library provides dynamically allocated null-terminated C
 * strings.
 *
 * The string type, astr, is a pointer type.
 *
 * String positions start at zero, as with ordinary C strings.
 *
 * Where not otherwise specified, the functions return the first
 * argument string, usually named as in the function prototype.
 */

/*
 * The opaque string type.
 */
[CCode (cheader_filename = "stddef.h,stdio.h,stdarg.h,astr.h", cname="struct astr", destroy_function="", has_type_id=false)]
[Compact]
public struct Astr {
	/*
	 * Allocate a new string with zero length.
	 */
	[CCode (cname="astr_new")]
	public static Astr *new_();

	/*
	 * Make a new string from a C null-terminated string.
	 */
	public static Astr *new_cstr (string s);

	/*
	 * Make a new constant string from a counted C string.
	 */
	[CCode (cname="const_astr_new_nstr")]
	public static Astr *new_nstr (char *s, size_t n);

	/*
	 * Convert as into a C null-terminated string.
	 * as[0] to as[astr_len (as) - 1] inclusive may be read.
	 */
	public unowned string cstr ();

	/*
	 * Return the length of the argument string `as'.
	 */
	public size_t len ();

	/*
	 * Return the `pos'th character of `as'.
	 */
	public char get (size_t pos);

	/*
	 * Return a new astr consisting of `size' characters from string `as'
	 * starting from position `pos'.
	 */
	public Astr *substr (size_t pos, size_t size);

	/*
	 * Assign the contents of the argument string to the string `as'.
	 */
	public Astr *cpy (Astr *src);
	public Astr *cpy_cstr (string s);

	/*
	 * Append the contents of the argument string or character to `as'.
	 */
	public Astr *cat (Astr *src);
	public Astr *cat_cstr (string s);
	public Astr *cat_nstr (string s, size_t len);
	public Astr *cat_char (int c);

// /*
//  * Overwrite `size' characters of `as', starting at `pos', with the
//  * argument string.
//  */
// astr astr_replace_nstr (astr as, size_t pos, const char *s, size_t size);

	/*
	 * Remove `size' chars from `as' at position `pos'.
	 */
	public Astr *remove (size_t pos, size_t size);

	/*
	 * Insert gap of `size' characters in `as' at position `pos'.
	 */
	public Astr *insert (size_t pos, size_t size);

	/*
	 * Move `n' chars in `as' from position `from' to `to'.
	 */
	public Astr *move (size_t to, size_t from, size_t n);

	/*
	 * Set `n' chars in `as' at position `pos' to `c'.
	 */
	public Astr *set (size_t pos, int c, size_t n);

	/*
	 * Truncate `as' to position `pos'.
	 */
	public Astr *truncate (size_t pos);

	/*
	 * Read file contents into an astr.
	 * Returns NULL if the file doesn't exist, or other error.
	 */
	public static Astr *readf (string filename);

	/*
	 * Format text into a string and return it.
	 */
	public static Astr *fmt (string fmt, ...);

	/*
	 * Recase as according to newcase.
	 */
	public Astr *recase (Case newcase);
}

/* Enumeration for casing. */
[CCode (cname = "casing", cprefix = "case_", lower_case_cprefix = "case_")]
public enum Case {
	upper = 1,
	lower,
	capitalized,
}
