/* Tests for the estr module.

   Copyright (c) 2011-2020 Free Software Foundation, Inc.

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

using Posix;

void assert_eq (Estr es, string s) {
	if ((string) es.text != s) {
		print ("test failed: \"%s\" != \"%s\"\n", (string) es.text, s);
		Process.exit (EXIT_FAILURE);
    }
}

void cat_cstr (Estr es, string s) {
	es.cat (ImmutableEstr.of (s, s.length));
}

int main () {
	Estr es1, es2;

	es1 = Estr.of_empty ();
	cat_cstr (es1, "hello world!");
	assert_eq (es1, "hello world!");

	es1 = Estr.of_empty ();
	cat_cstr (es1, "1234567");
	es2 = Estr.of_empty ();
	cat_cstr (es2, "foo");
	es1.replace (1, es2);
	assert_eq (es1, "1foo567");

	print ("estr test successful.\n");

	return EXIT_SUCCESS;
}
