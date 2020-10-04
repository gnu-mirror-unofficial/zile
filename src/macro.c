/* Macro facility functions

   Copyright (c) 1997-2011 Free Software Foundation, Inc.

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

#include <assert.h>
#include "gl_array_list.h"

#include "main.h"
#include "extern.h"


typedef gl_list_t Macro;	/* List of keystrokes. */

static Macro cur_mp = NULL, cmd_mp = NULL;

static Macro
macro_new (void)
{
  return gl_list_create_empty (GL_ARRAY_LIST, NULL, NULL, NULL, true);
}

static void
add_macro_key (Macro mp, size_t key)
{
  gl_list_add_last (mp, (void *) key);
}

void
add_cmd_to_macro (void)
{
  assert (cmd_mp);
  for (size_t i = 0; i < gl_list_size (cmd_mp); i++)
    add_macro_key (cur_mp, (size_t) gl_list_get_at (cmd_mp, i));
  cmd_mp = NULL;
}

void
add_key_to_cmd (size_t key)
{
  if (cmd_mp == NULL)
    cmd_mp = macro_new ();

  add_macro_key (cmd_mp, key);
}

void
remove_key_from_cmd (void)
{
  assert (cmd_mp);
  gl_list_remove_at (cmd_mp, gl_list_size (cmd_mp) - 1);
}

void
cancel_kbd_macro (void)
{
  cmd_mp = cur_mp = NULL;
  thisflag &= ~FLAG_DEFINING_MACRO;
}

DEFUN ("start-kbd-macro", start_kbd_macro)
/*+
Record subsequent keyboard input, defining a keyboard macro.
The commands are recorded even as they are executed.
Use \\[end-kbd-macro] to finish recording and make the macro available.
+*/
{
  if (thisflag & FLAG_DEFINING_MACRO)
    {
      minibuf_error ("Already defining a keyboard macro");
      return leNIL;
    }

  if (cur_mp)
    cancel_kbd_macro ();

  minibuf_write ("Defining keyboard macro...");

  thisflag |= FLAG_DEFINING_MACRO;
  cur_mp = macro_new ();
}
END_DEFUN

DEFUN ("end-kbd-macro", end_kbd_macro)
/*+
Finish defining a keyboard macro.
The definition was started by \\[start-kbd-macro].
The macro is now available for use via \\[call-last-kbd-macro].
+*/
{
  if (!(thisflag & FLAG_DEFINING_MACRO))
    {
      minibuf_error ("Not defining a keyboard macro");
      return leNIL;
    }

  thisflag &= ~FLAG_DEFINING_MACRO;
}
END_DEFUN

static void
process_keys (gl_list_t keys)
{
  size_t len = gl_list_size (keys);
  size_t cur = term_buf_len ();
  for (size_t i = 0; i < len; i++)
    pushkey ((size_t) gl_list_get_at (keys, len - i - 1));

  while (term_buf_len () > cur)
    get_and_run_command ();
}

static gl_list_t macro_keys;

static bool
call_macro (void)
{
  process_keys (macro_keys);
  return true;
}

DEFUN ("call-last-kbd-macro", call_last_kbd_macro)
/*+
Call the last keyboard macro that you defined with \\[start-kbd-macro].
A prefix argument serves as a repeat count.
+*/
{
  if (cur_mp == NULL)
    {
      minibuf_error ("No kbd macro has been defined");
      return leNIL;
    }

  /* FIXME: Call execute-kbd-macro (needs a way to reverse keystrtovec) */
  /* F_execute_kbd_macro (uniarg, true, leAddDataElement (leNew (NULL), astr_cstr (keyvectostr (cur_mp)), false)); */
  macro_keys = cur_mp;
  execute_with_uniarg (uniarg, call_macro, NULL);
}
END_DEFUN

DEFUN_NONINTERACTIVE_ARGS ("execute-kbd-macro", execute_kbd_macro,
                   STR_ARG (keystr))
/*+
Execute macro as string of editor command characters.
+*/
{
  STR_INIT (keystr);
  gl_list_t keys = keystrtovec (astr_cstr (keystr));
  if (keys)
    {
      macro_keys = keys;
      execute_with_uniarg (uniarg, call_macro, NULL);
    }
  else
    ok = leNIL;
}
END_DEFUN
