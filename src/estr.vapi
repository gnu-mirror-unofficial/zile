/* Dynamically allocated encoded strings

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

/* String with encoding */
[CCode (cname = "struct estr", cheader_filename = "estr.h", destroy_function = "", has_type_id = false)]
[Compact]
public struct Estr {}

void estr_init ();
Astr *estr_get_as (Estr *es);
unowned string estr_get_eol (Estr * es);

Estr *estr_new (Astr *a, string eol);

// /* Make estr from astr, determining EOL type from astr's contents. */
Estr *estr_new_astr (Astr *a);

size_t estr_prev_line (Estr * es, size_t o);
size_t estr_next_line (Estr * es, size_t o);
size_t estr_start_of_line (Estr * es, size_t o);
size_t estr_end_of_line (Estr * es, size_t o);
size_t estr_line_len (Estr * es, size_t o);
size_t estr_lines (Estr * es);
Estr * estr_replace_estr (Estr * es, size_t pos, Estr * src);
Estr * estr_cat (Estr * es, Estr * src);

size_t estr_len (Estr * es, string eol_type);

/* Read file contents into an estr.
 * The `as' member is NULL if the file doesn't exist, or other error. */
public Estr *estr_readf (string filename);

public static Estr *estr_empty;

public static string coding_eol_lf;
public static string coding_eol_crlf;
public static string coding_eol_cr;
