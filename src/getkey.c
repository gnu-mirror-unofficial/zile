/* Miscellaneous functions

   Copyright (c) 2008 Free Software Foundation, Inc.
   Copyright (c) 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004 Sandro Sigala.

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

#include "config.h"

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "zile.h"
#include "extern.h"

#define MAX_KEY_BUF	16
static int key_buf[MAX_KEY_BUF];
static int *keyp = key_buf;
static size_t _last_key;

/* Return last key pressed */
size_t
lastkey (void)
{
  return _last_key;
}

/*
 * Get a keystroke, waiting for up to timeout 10ths of a second if
 * mode contains GETKEY_DELAYED, and translating it into a
 * keycode unless mode contains GETKEY_UNFILTERED.
 */
size_t
xgetkey (int mode, size_t timeout)
{
  if (keyp > key_buf)
    _last_key = *--keyp;
  else
    _last_key = term_xgetkey (mode, timeout);

  if (thisflag & FLAG_DEFINING_MACRO)
    add_key_to_cmd (_last_key);

  return _last_key;
}

/*
 * Wait for a keystroke indefinitely, and return the
 * corresponding keycode.
 */
size_t
getkey (void)
{
  return xgetkey (0, 0);
}

/*
 * Wait for timeout 10ths if a second or until a key is pressed.
 * The key is then available with [x]getkey.
 */
void
waitkey (size_t timeout)
{
  ungetkey (xgetkey (GETKEY_DELAYED, timeout));
}

void
ungetkey (size_t key)
{
  if (keyp < key_buf + MAX_KEY_BUF && key != KBD_NOKEY)
    *keyp++ = key;
}