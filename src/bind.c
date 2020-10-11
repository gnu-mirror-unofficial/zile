/* Key bindings and extended commands

   Copyright (c) 1997-2012 Free Software Foundation, Inc.

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
#include <ctype.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include "gl_array_list.h"
#include "gl_linked_list.h"

#include "main.h"
#include "extern.h"

/*--------------------------------------------------------------------------
 * Key binding.
 *--------------------------------------------------------------------------*/

struct Binding
{
  size_t key; /* The key code (for every level except the root). */
  Function func; /* The function for this key (if a leaf node). */

  /* Branch vector, number of items, max number of items. */
  Binding *vec;
  size_t vecnum, vecmax;
};

static Binding root_bindings;

static Binding
node_new (int vecmax)
{
  Binding p = (Binding) XZALLOC (struct Binding);

  p->vecmax = vecmax;
  p->vec = (Binding *) XCALLOC (vecmax, struct Binding);

  return p;
}

static Binding
search_node (Binding tree, size_t key)
{
  for (size_t i = 0; i < tree->vecnum; ++i)
    if (tree->vec[i]->key == key)
      return tree->vec[i];

  return NULL;
}

static void
add_node (Binding tree, Binding p)
{
  /* Erase any previous binding the current key might have had in case
     it was non-prefix and is now being made prefix, as we don't want
     to accidentally create a default for the prefix map. */
  if (tree->vecnum == 0)
    tree->func = NULL;

  /* Reallocate vector if there is not enough space. */
  if (tree->vecnum + 1 >= tree->vecmax)
    {
      tree->vecmax += 5;
      tree->vec = xrealloc (tree->vec, sizeof (*p) * tree->vecmax);
    }

  /* Insert the node. */
  tree->vec[tree->vecnum++] = p;
}

static void
bind_key_vec (Binding tree, gl_list_t keys, size_t from, Function func)
{
  Binding p, s = search_node (tree, (size_t) gl_list_get_at (keys, from));
  size_t n = gl_list_size (keys) - from;

  if (s == NULL)
    {
      p = node_new (n == 1 ? 1 : 5);
      p->key = (size_t) gl_list_get_at (keys, from);
      add_node (tree, p);
      if (n == 1)
        p->func = func;
      else if (n > 0)
        bind_key_vec (p, keys, from + 1, func);
    }
  else if (n > 1)
    bind_key_vec (s, keys, from + 1, func);
  else
    s->func = func;
}

static Binding
search_key (Binding tree, gl_list_t keys, size_t from)
{
  Binding p = search_node (tree, (size_t) gl_list_get_at (keys, from));
  if (p == NULL)
    return NULL;
  else if (gl_list_size (keys) - from == 1)
    return p;
  else
    return search_key (p, keys, from + 1);
}

size_t
do_binding_completion (astr as)
{
  astr bs = astr_new ();

  if (lastflag & FLAG_SET_UNIARG)
    {
      unsigned arg = abs (last_uniarg);
      do
        {
          bs = astr_fmt ("%c %s", arg % 10 + '0', astr_cstr (bs));
          arg /= 10;
        }
      while (arg != 0);

      if (last_uniarg < 0)
        bs = astr_fmt ("- %s", astr_cstr (bs));
    }

  minibuf_write ("%s%s%s-",
                 lastflag & (FLAG_SET_UNIARG | FLAG_UNIARG_EMPTY) ? "C-u " : "",
                 astr_cstr (bs),
                 astr_cstr (as));
  size_t key = getkey (GETKEY_DEFAULT);
  minibuf_clear ();

  return key;
}

/* Get a key sequence from the keyboard; the sequence returned
   has at most the last stroke unbound. */
gl_list_t
get_key_sequence (void)
{
  gl_list_t keys = gl_list_create_empty (GL_ARRAY_LIST,
                                         NULL, NULL, NULL, true);
  size_t key;

  do
    key = getkey (GETKEY_DEFAULT);
  while (key == KBD_NOKEY);
  gl_list_add_last (keys, (void *) key);
  for (;;)
    {
      astr as;
      Binding p = search_key (root_bindings, keys, 0);
      if (p == NULL || p->func != NULL)
        break;
      as = keyvectodesc (keys);
      gl_list_add_last (keys, (void *) do_binding_completion (as));
    }

  return keys;
}

Function
get_function_by_keys (gl_list_t keys)
{
  Binding p;

  /* Detect Meta-digit */
  if (gl_list_size (keys) == 1)
    {
      size_t key = (size_t) gl_list_get_at (keys, 0);
      if (key & KBD_META &&
          (isdigit ((int) (key & 0xff)) || (int) (key & 0xff) == '-'))
        return F_universal_argument;
    }

  /* See if we've got a valid key sequence */
  p = search_key (root_bindings, keys, 0);

  return p ? p->func : NULL;
}

static bool
self_insert_command (void)
{
  bool ret = true;
  /* Mask out ~KBD_CTRL to allow control sequences to be themselves. */
  int key = (int) (lastkey () & ~KBD_CTRL);
  deactivate_mark ();
  if (key <= 0xff)
    {
      if (isspace (key) && get_buffer_autofill (cur_bp))
        ret = fill_break_line () != -1;
      insert_char (key);
    }
  else
    {
      ding ();
      ret = false;
    }

  return ret;
}

DEFUN ("self-insert-command", self_insert_command)
/*+
Insert the character you type.
Whichever character you type to run this command is inserted.
+*/
{
  ok = execute_with_uniarg (uniarg, self_insert_command, NULL);
}
END_DEFUN

static Function _last_command;
static Function _this_command;

Function
last_command (void)
{
  return _last_command;
}

void
set_this_command (Function cmd)
{
  _this_command = cmd;
}

bool
call_command (Function f, long uniarg, bool uniflag, le *branch)
{
  thisflag = lastflag & FLAG_DEFINING_MACRO;
  undo_start_sequence ();

  /* Reset last_uniarg before function call, so recursion (e.g. in
     macros) works. */
  if (!(thisflag & FLAG_SET_UNIARG))
    last_uniarg = 1;

  /* Execute the command. */
  _this_command = f;
  bool ok = f (uniarg, uniflag, branch);
  _last_command = _this_command;

  /* Only add keystrokes if we were already in macro defining mode
     before the function call, to cope with start-kbd-macro. */
  if (lastflag & FLAG_DEFINING_MACRO && thisflag & FLAG_DEFINING_MACRO)
    add_cmd_to_macro ();

  undo_end_sequence ();
  lastflag = thisflag;

  return ok;
}

void
get_and_run_command (void)
{
  gl_list_t keys = get_key_sequence ();
  Function f = get_function_by_keys (keys);

  minibuf_clear ();

  if (f != NULL)
    call_command (f, last_uniarg, (lastflag & FLAG_SET_UNIARG) != 0, NULL);
  else
    minibuf_error ("%s is undefined", astr_cstr (keyvectodesc (keys)));
}

static Binding
init_bindings (void)
{
  return node_new (10);
}

void
init_default_bindings (void)
{
  root_bindings = init_bindings ();

  /* Bind all printing keys to self_insert_command */
  gl_list_t keys = gl_list_create_empty (GL_ARRAY_LIST,
                                         NULL, NULL, NULL, true);
  gl_list_add_last (keys, NULL);
  for (size_t i = 0; i <= 0xff; i++)
    {
      if (isprint (i))
        {
          gl_list_set_at (keys, 0, (void *) i);
          bind_key_vec (root_bindings, keys, 0, F_self_insert_command);
        }
    }

  astr as = astr_new_cstr (
#include "tbl_bindings.h"
);
  lisp_loadstring (as);
}

DEFUN_ARGS ("global-set-key", global_set_key,
            STR_ARG (keystr)
            STR_ARG (name))
/*+
Bind a command to a key sequence.
Read key sequence and function name, and bind the function to the key
sequence.
+*/
{
  gl_list_t keys;
  Function func;

  STR_INIT (keystr);
  if (keystr != NULL)
    {
      keys = keystrtovec (astr_cstr (keystr));
      if (keys == NULL)
        {
          minibuf_error ("Key sequence %s is invalid", astr_cstr (keystr));
          return leNIL;
        }
    }
  else
    {
      minibuf_write ("Set key globally: ");
      keys = get_key_sequence ();
      keystr = keyvectodesc (keys);
    }

  STR_INIT (name)
  else
    name = minibuf_read_function_name ("Set key %s to command: ",
                                       astr_cstr (keystr));
  if (name == NULL)
    return leNIL;

  func = get_function (astr_cstr (name));
  if (func == NULL) /* Possible if called non-interactively */
    {
      minibuf_error ("No such function `%s'", astr_cstr (name));
      return leNIL;
    }
  bind_key_vec (root_bindings, keys, 0, func);
}
END_DEFUN

static void
walk_bindings_tree (Binding tree, gl_list_t keys,
                    void (*process) (astr key, Binding p, void *st), void *st)
{
  for (size_t i = 0; i < tree->vecnum; ++i)
    {
      Binding p = tree->vec[i];
      if (p->func != NULL)
        {
          astr key = astr_new ();
          for (size_t j = 0; j < gl_list_size (keys); j++)
            {
              astr_cat (key, (const_astr) gl_list_get_at (keys, j));
              astr_cat_char (key, ' ');
            }
          astr_cat (key, chordtodesc (p->key));
          process (key, p, st);
        }
      else
        {
          gl_list_add_last (keys, chordtodesc (p->key));
          walk_bindings_tree (p, keys, process, st);
          assert (gl_list_remove_at (keys, gl_list_size (keys) - 1));
        }
    }
}

static void
walk_bindings (Binding tree, void (*process) (astr key, Binding p, void *st),
               void *st)
{
  walk_bindings_tree (tree, gl_list_create_empty (GL_LINKED_LIST,
                                                  NULL, NULL, NULL, true), process, st);
}

typedef struct
{
  Function f;
  astr bindings;
} gather_bindings_state;

static void
gather_bindings (astr key, Binding p, void *st)
{
  gather_bindings_state *g = (gather_bindings_state *) st;

  if (p->func == g->f)
    {
      if (astr_len (g->bindings) > 0)
        astr_cat_cstr (g->bindings, ", ");
      astr_cat (g->bindings, key);
    }
}

DEFUN ("where-is", where_is)
/*+
Print message listing key sequences that invoke the command DEFINITION.
Argument is a command name.
+*/
{
  const_astr name = minibuf_read_function_name ("Where is command: ");
  gather_bindings_state g;

  ok = leNIL;

  if (name)
    {
      g.f = get_function (astr_cstr (name));
      if (g.f)
        {
          g.bindings = astr_new ();
          walk_bindings (root_bindings, gather_bindings, &g);

          if (astr_len (g.bindings) == 0)
            minibuf_write ("%s is not on any key", astr_cstr (name));
          else
            minibuf_write ("%s is on %s", astr_cstr (name), astr_cstr (g.bindings));
          ok = leT;
        }
    }
}
END_DEFUN

static void
print_binding (astr key, Binding p, void *st _GL_UNUSED_PARAMETER)
{
  bprintf ("%-15s %s\n", astr_cstr (key), get_function_name (p->func));
}

static void
write_bindings_list (va_list ap _GL_UNUSED_PARAMETER)
{
  bprintf ("Key translations:\n");
  bprintf ("%-15s %s\n", "key", "binding");
  bprintf ("%-15s %s\n", "---", "-------");

  walk_bindings (root_bindings, print_binding, NULL);
}

DEFUN ("describe-bindings", describe_bindings)
/*+
Show a list of all defined keys, and their definitions.
+*/
{
  write_temp_buffer ("*Help*", true, write_bindings_list);
}
END_DEFUN
