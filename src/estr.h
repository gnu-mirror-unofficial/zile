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

#include <stddef.h>

/* String with encoding */
typedef struct estr *estr;
typedef struct estr const *const_estr;

extern estr estr_empty;

extern const char *coding_eol_lf;
extern const char *coding_eol_crlf;
extern const char *coding_eol_cr;

void estr_init (void);
_GL_ATTRIBUTE_PURE const char *estr_get_eol (const_estr es);

estr estr_new (const char *eol);
const_estr const_estr_new_nstr (const char *s, size_t len, const char *eol);
estr estr_set_eol (estr es);
void const_estr_delete (const_estr es);
void estr_delete (estr es);

_GL_ATTRIBUTE_PURE size_t estr_prev_line (const_estr es, size_t o);
_GL_ATTRIBUTE_PURE size_t estr_next_line (const_estr es, size_t o);
_GL_ATTRIBUTE_PURE size_t estr_start_of_line (const_estr es, size_t o);
_GL_ATTRIBUTE_PURE size_t estr_end_of_line (const_estr es, size_t o);
_GL_ATTRIBUTE_PURE size_t estr_line_len (const_estr es, size_t o);
estr estr_replace_estr (estr es, size_t pos, const_estr src);
estr estr_cat (estr es, const_estr src);
size_t estr_len (const_estr es, const char *eol_type);

/*
 * Return a pointer to the string buffer of `es'.
 * Offsets 0 to estr_cstr_len (es) - 1 inclusive may be read.
 */
char *estr_cstr (estr es);

/*
 * Return the number of chars of string data in `es'.
 */
size_t estr_cstr_len (estr es);

/*
 * Return the `pos'th char of `es'.
 */
char estr_get (estr es, size_t pos);

/*
 * Remove `size' chars from `es' at position `pos'.
 */
estr estr_remove (estr es, size_t pos, size_t size);

/*
 * Insert gap of `size' chars in `es' at position `pos'.
 */
estr estr_insert (estr es, size_t pos, size_t size);

/*
 * Move `n' chars in `es' from position `from' to `to'.
 */
estr estr_move (estr es, size_t to, size_t from, size_t n);

/*
 * Set `n' chars in `es' at position `pos' to `c'.
 */
estr estr_set (estr es, size_t pos, int c, size_t n);

/* Read file contents into an estr.
 * The `as' member is NULL if the file doesn't exist, or other error. */
estr estr_readf (const char *filename);
