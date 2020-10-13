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

#include <config.h>

#include <stddef.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <string.h>
#include <assert.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include "xalloc.h"
#include "size_max.h"
#include "minmax.h"

#include "estr.h"
#include "memrmem.h"


/*
 * The estr type provides dynamically allocated null-terminated C
 * strings with line ending encoding.
 *
 * The string type, estr, is a pointer type.
 *
 * String positions start at zero, as with ordinary C strings.
 *
 * Where not otherwise specified, the functions return the first
 * argument string, usually named as in the function prototype.
 */

#define ALLOCATION_CHUNK_SIZE	16

/*
 * The implementation of estr.
 */
struct estr
{
  char *text;		/* The string buffer. */
  size_t len;		/* The length of the string. */
  size_t maxlen;	/* The buffer size. */
  const char *eol;      /* EOL type. */
};


/* Formats of end-of-line. */
const char *coding_eol_lf = "\n";
const char *coding_eol_crlf = "\r\n";
const char *coding_eol_cr = "\r";

estr estr_empty;

/*
 * Allocate a new string with zero length.
 */
estr
estr_new (const char *eol)
{
  estr es = XZALLOC (struct estr);
  es->maxlen = ALLOCATION_CHUNK_SIZE;
  es->len = 0;
  es->text = (char *) xzalloc (es->maxlen + 1);
  es->eol = eol;
  return es;
}

/*
 * Make a new constant string from a counted C string.
 */
const_estr
const_estr_new_nstr (const char *s, size_t len, const char *eol)
{
  estr es = XZALLOC (struct estr);
  es->len = len;
  es->text = (char *) s;
  es->eol = eol;
  return es;
}

/*
 * Change the length of an estr, possibly reallocating it if it needs to
 * grow, or has shrunk considerably.
 */
static void
estr_set_len (estr es, size_t len)
{
  if (len > es->maxlen || len < es->maxlen / 2)
    {
      es->maxlen = len + ALLOCATION_CHUNK_SIZE;
      es->text = xrealloc (es->text, es->maxlen + 1);
    }
  es->len = len;
  es->text[es->len] = '\0';
}

/* Maximum number of EOLs to check before deciding type. */
#define MAX_EOL_CHECK_COUNT 3
estr
estr_set_eol (estr es)
{
  bool first_eol = true;
  size_t total_eols = 0;
  for (size_t i = 0; i < es->len && total_eols < MAX_EOL_CHECK_COUNT; i++)
    {
      char c = estr_get (es, i);
      if (c == '\n' || c == '\r')
        {
          const char *this_eol_type;
          total_eols++;
          if (c == '\n')
            this_eol_type = coding_eol_lf;
          else if (i == es->len - 1 || estr_get (es, i + 1) != '\n')
            this_eol_type = coding_eol_cr;
          else
            {
              this_eol_type = coding_eol_crlf;
              i++;
            }

          if (first_eol)
            { /* This is the first end-of-line. */
              es->eol = this_eol_type;
              first_eol = false;
            }
          else if (es->eol != this_eol_type)
            { /* This EOL is different from the last; arbitrarily choose LF. */
              es->eol = coding_eol_lf;
              break;
            }
        }
    }
  return es;
}

void
estr_init (void)
{
  estr_empty = estr_new (coding_eol_lf);
}

/*
 * Append the contents of the argument string or character to `es',
 * without line ending translation.
 */
static estr
estr_cat_literal (estr es, const char *s, size_t csize)
{
  assert (es != NULL);
  assert (es != NULL);
  size_t oldlen = es->len;
  estr_set_len (es, es->len + csize);
  memmove (es->text + oldlen, s, csize);
  return es;
}

void
const_estr_delete (const_estr es)
{
  free (es);
}

void
estr_delete (estr es)
{
  assert (es != NULL);
  free (es->text);
  es->text = NULL;
  const_estr_delete (es);
}

const char *
estr_get_eol (const_estr es)
{
  return es->eol;
}

size_t
estr_prev_line (const_estr es, size_t o)
{
  size_t so = estr_start_of_line (es, o);
  return (so == 0) ? SIZE_MAX : estr_start_of_line (es, so - strlen (es->eol));
}

size_t
estr_next_line (const_estr es, size_t o)
{
  size_t eo = estr_end_of_line (es, o);
  return (eo == es->len) ? SIZE_MAX : eo + strlen (es->eol);
}

size_t
estr_start_of_line (const_estr es, size_t o)
{
  size_t eol_len = strlen (es->eol);
  const char *prev = memrmem (es->text, o, es->eol, eol_len);
  return prev ? prev - es->text + eol_len : 0;
}

size_t
estr_end_of_line (const_estr es, size_t o)
{
  const char *next = memmem (es->text + o, es->len - o,
                             es->eol, strlen (es->eol));
  return next ? (size_t) (next - es->text) : es->len;
}

static size_t
estr_lines (const_estr es)
{
  size_t es_eol_len = strlen (es->eol);
  const char *s = es->text, *next;
  size_t lines = 0;
  for (size_t len = es->len;
       (next = memmem (s, len, es->eol, es_eol_len)) != NULL;
       lines++, len -= (size_t) (next - s) + es_eol_len, s = next + es_eol_len)
    ;
  return lines;
}

/*
 * Overwrite `size' characters of `es', starting at `pos', with the
 * argument string.
 */
estr
estr_replace_estr (estr es, size_t pos, const_estr src)
{
  const char *s = src->text;
  size_t src_eol_len = strlen (src->eol), es_eol_len = strlen (es->eol);
  for (size_t len = src->len; len > 0;)
    {
      const char *next = memmem (s, len, src->eol, src_eol_len);
      size_t line_len = next ? (size_t) (next - s) : len;
      memmove (es->text + pos, s, line_len);
      pos += line_len;
      len -= line_len;
      s = next;
      if (len > 0)
        {
          memmove (es->text + pos, es->eol, es_eol_len);
          s += src_eol_len;
          len -= src_eol_len;
          pos += es_eol_len;
        }
    }
  return es;
}

estr
estr_cat (estr es, const_estr src)
{
  size_t oldlen = es->len;
  estr_insert (es, oldlen, estr_len (src, es->eol));
  return estr_replace_estr (es, oldlen, src);
}

/*
 * Convert `es' into a C null-terminated string, of
 * length estr_cstr_len (es).
 */
char *
estr_cstr (estr es)
{
  return es->text;
}

size_t
estr_cstr_len (estr es)
{
  return es->len;
}

/*
 * Return the `pos'th character of `es'.
 */
char
estr_get (estr es, size_t pos)
{
  assert (pos <= es->len);
  return (es->text)[pos];
}

/*
 * Remove `size' chars from `es' at position `pos'.
 */
estr
estr_remove (estr es, size_t pos, size_t size)
{
  assert (es != NULL);
  assert (es != NULL);
  assert (pos <= es->len);
  assert (size <= es->len - pos);
  memmove (es->text + pos, es->text + pos + size, es->len - (pos + size));
  estr_set_len (es, es->len - size);
  return es;
}

/*
 * Insert gap of `size' characters in `es' at position `pos'.
 */
estr
estr_insert (estr es, size_t pos, size_t size)
{
  assert (es != NULL);
  assert (pos <= es->len);
  assert (pos + size >= MAX (pos, size));    /* Check for overflow. */
  estr_set_len (es, es->len + size);
  memmove (es->text + pos + size, es->text + pos, es->len - (pos + size));
  memset (es->text + pos, '\0', size);
  return es;
}

estr
estr_move (estr es, size_t to, size_t from, size_t n)
{
  assert (es != NULL);
  assert (to <= es->len);
  assert (from <= es->len);
  assert (n <= es->len - MAX (from, to));
  memmove (es->text + to, es->text + from, n);
  return es;
}

estr
estr_set (estr es, size_t pos, int c, size_t n)
{
  assert (es != NULL);
  assert (pos <= es->len);
  assert (n <= es->len - pos);
  memset (es->text + pos, c, n);
  return es;
}

estr
estr_readf (const char *filename)
{
  estr es = NULL;
  struct stat st;
  if (stat (filename, &st) == 0)
    {
      size_t size = st.st_size;
      int fd = open (filename, O_RDONLY);
      if (fd >= 0)
        {
          char buf[BUFSIZ];
          es = estr_new (coding_eol_lf);
          while ((size = read (fd, buf, BUFSIZ)) > 0)
            estr_cat_literal (es, buf, size);
          close (fd);
        }
    }
  if (es == NULL)
    return NULL;
  return estr_set_eol (es);
}

/*
 * Return the length of the argument string `es'.
 */
size_t
estr_len (const_estr es, const char *eol_type)
{
  return es->len + estr_lines (es) * (strlen (eol_type) - strlen (estr_get_eol (es)));
}


#ifdef TEST

#include <stdio.h>

static void
assert_eq (estr as, const char *s)
{
  if (strcmp (estr_cstr (as), s))
    {
      printf ("test failed: \"%s\" != \"%s\"\n", estr_cstr (as), s);
      exit (EXIT_FAILURE);
    }
}

static void
cat_cstr (estr es, const char *s)
{
  const_estr tmp = const_estr_new_nstr (s, strlen (s), coding_eol_lf);
  es = estr_cat (es, tmp);
  const_estr_delete (tmp);
}

int
main (int argc, char **argv)
{
  estr es1, es2;

  es1 = estr_new (coding_eol_lf);
  cat_cstr (es1, "hello world!");
  assert_eq (es1, "hello world!");

  estr_delete (es1);
  es1 = estr_new (coding_eol_lf);
  cat_cstr (es1, "1234567");
  es2 = estr_new (coding_eol_lf);
  cat_cstr (es2, "foo");
  estr_replace_estr (es1, 1, es2);
  assert_eq (es1, "1foo567");

  estr_delete (es1);
  estr_delete (es2);
  printf ("estr test successful.\n");

  return EXIT_SUCCESS;
}

#endif /* TEST */
