/* Key bindings and extended commands

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
   along with GNU Zile; see the file COPYING.  If not, write to the
   Free Software Foundation, Fifth Floor, 51 Franklin Street, Boston,
   MA 02111-1301, USA.  */

using Lisp;

/*--------------------------------------------------------------------------
 * Key binding.
 *--------------------------------------------------------------------------*/

public class Binding {
	public size_t key; /* The key code (for every level except the root). */
	public LispFunc? func; /* The function for this key (if a leaf node). */

	/* Branch Array. FIXME: make a hash table. */
	public Array<Binding> vec;

	public Binding () {
		this.vec = new Array<Binding> ();
	}
}

Binding root_bindings;

Binding? search_node (Binding tree, uint key) {
	for (uint i = 0; i < tree.vec.length; ++i)
		if (tree.vec.index (i).key == key)
			return tree.vec.index (i);

	return null;
}

void bind_key_vec (Binding tree, Array<uint?> keys, uint from, LispFunc func) {
	Binding? s = search_node (tree, keys.index (from));
	uint n = keys.length - from;

	if (s == null) {
		Binding p = new Binding ();
		p.key = keys.index (from);

		/* Erase any previous binding the current key might have had in case
		   it was non-prefix and is now being made prefix. */
		tree.func = null;
		tree.vec.append_val (p);

		if (n == 1)
			p.func = func;
		else if (n > 1)
			bind_key_vec (p, keys, from + 1, func);
	} else if (n > 1)
		bind_key_vec (s, keys, from + 1, func);
	else
		s.func = func;
}

Binding? search_key (Binding tree, Array<uint?> keys, uint from) {
	Binding? p = search_node (tree, keys.index (from));
	if (p == null)
		return null;
	else if (keys.length - from == 1)
		return p;
	else
		return search_key (p, keys, from + 1);
}

public uint do_binding_completion (string a) {
	string b = "";

	if (Flags.SET_UNIARG in lastflag) {
		long arg = last_uniarg.abs ();
		do {
			b = "%c %s".printf ((char) (arg % 10 + '0'), b);
			arg /= 10;
		} while (arg != 0);

		if (last_uniarg < 0)
			b = "- " + b;
	}

	Minibuf.write ("%s%s%s-",
				   (Flags.SET_UNIARG | Flags.UNIARG_EMPTY) in lastflag ? "C-u " : "",
				   b, a);
	uint key = (uint) getkey (GETKEY_DEFAULT);
	Minibuf.clear ();

	return key;
}

/* Get a key sequence from the keyboard; the sequence returned
   has at most the last stroke unbound. */
Array<uint?> get_key_sequence () {
	var keys = new Array<uint?> ();
	uint key = 0;

	do
		key = (uint) getkey (GETKEY_DEFAULT);
	while (key == KBD_NOKEY);
	keys.append_val ((uint) key);
	for (;;) {
		Binding p = search_key (root_bindings, keys, 0);
		if (p == null || p.func != null)
			break;
		string a = keyvectodesc (keys);
		keys.append_val ((uint) do_binding_completion (a));
	}

	return keys;
}

LispFunc get_function_by_keys (Array<uint?> keys)
{
	/* Detect Meta-digit */
	if (keys.length == 1) {
		uint key = keys.index (0);
		if ((key & KBD_META) != 0 &&
			(((char) (key & 0xff)).isdigit () || (char) (key & 0xff) == '-'))
			return LispFunc.find ("universal-argument");
	}

	/* See if we've got a valid key sequence */
	Binding? p = search_key (root_bindings, keys, 0);
	return p != null ? p.func : null;
}

bool self_insert_command () {
	bool ret = true;
	/* Mask out ~KBD_CTRL to allow control sequences to be themselves. */
	int key = (int) (lastkey () & ~KBD_CTRL);
	deactivate_mark ();
	if (key <= 0xff) {
		if (((char) key).isspace () && cur_bp.autofill)
			ret = fill_break_line () != -1;
		insert_char ((char) key);
	} else {
		ding ();
		ret = false;
	}

	return ret;
}

LispFunc _last_command;
LispFunc _this_command;

LispFunc last_command () {
	return _last_command;
}

void set_this_command (LispFunc cmd) {
	_this_command = cmd;
}

bool call_command (LispFunc f, long uniarg, Lexp *branch) {
	thisflag = lastflag & Flags.DEFINING_MACRO;
	undo_start_sequence ();

	/* Reset last_uniarg before function call, so recursion (e.g. in
	   macros) works. */
	if (!(Flags.SET_UNIARG in thisflag))
		last_uniarg = 1;

	/* Execute the command. */
	_this_command = f;
	bool ok = f.func ((long) uniarg, branch);
	_last_command = _this_command;

	/* Only add keystrokes if we were already in macro defining mode
	   before the function call, to cope with start-kbd-macro. */
	if (Flags.DEFINING_MACRO in (lastflag & thisflag))
		add_cmd_to_macro ();

	undo_end_sequence ();
	lastflag = thisflag;

	return ok;
}

void get_and_run_command () {
	Array<uint?> keys = get_key_sequence ();
	LispFunc f = get_function_by_keys (keys);

	Minibuf.clear ();
	if (f != null)
		call_command (f, last_uniarg, Flags.SET_UNIARG in lastflag ? null : leNIL);
	else
		Minibuf.error ("%s is undefined", keyvectodesc (keys));
}

public void init_default_bindings () {
	root_bindings = new Binding ();

	/* Bind all printing keys to self_insert_command */
	for (uint i = 0; i <= 0xff; i++) {
		var keys = new Array<uint?> ();
		if (((char) i).isprint ()) {
			keys.append_val (i);
			bind_key_vec (root_bindings, keys, 0, LispFunc.find ("self-insert-command"));
		}
	}

	lisp_loadstring (default_bindings);
}

delegate void BindingsProcessor (string key, Binding p);
void walk_bindings_tree (Binding tree, Array<string> keys, BindingsProcessor process) {
	for (uint i = 0; i < tree.vec.length; ++i) {
		Binding p = tree.vec.index (i);
		assert (p != null);

		if (p.func != null) {
			string key = "";
			for (uint j = 0; j < keys.length; j++)
				key += keys.index (j) + " ";
			key += chordtodesc (p.key);
			process (key, p);
		} else {
			keys.append_val (chordtodesc (p.key));
			walk_bindings_tree (p, keys, process);
			keys.remove_index (keys.length - 1);
		}
	}
}

void walk_bindings (Binding tree, BindingsProcessor process) {
	walk_bindings_tree (tree, new Array<string> (), process);
}


public void bind_init () {
	new LispFunc (
		"global-set-key",
		(uniarg, arglist) => {
			Array<uint?>? keys;
			string keystr = str_init (ref arglist);
			if (keystr != null) {
				keys = keystrtovec (keystr);
				if (keys == null) {
					Minibuf.error ("Key sequence %s is invalid", keystr);
					return false;
				}
			} else {
				Minibuf.write ("Set key globally: ");
				keys = get_key_sequence ();
				keystr = keyvectodesc (keys);
			}

			string? name = str_init (ref arglist);
			if (name == null)
				name = minibuf_read_function_name ("Set key %s to command: ", keystr);
			if (name == null)
				return false;

			LispFunc func = LispFunc.find (name);
			if (func == null) { /* Possible if called non-interactively */
				Minibuf.error ("No such function `%s'", name);
				return false;
			}
			bind_key_vec (root_bindings, keys, 0, func);
			return true;
		},
		true,
		"""Bind a command to a key sequence.
Read key sequence and function name, and bind the function to the key
sequence."""
		);

	new LispFunc (
		"self-insert-command",
		(uniarg, arglist) => {
			return execute_with_uniarg (uniarg, self_insert_command, null);
		},
		true,
		"""Insert the character you type.
Whichever character you type to run this command is inserted."""
		);

	new LispFunc (
		"where-is",
		(uniarg, arglist) => {
			string? name = minibuf_read_function_name ("Where is command: ");
			bool ok = false;

			if (name != null) {
				LispFunc? f = LispFunc.find (name);
				if (f != null) {
					string bindings = "";
					walk_bindings (root_bindings, (key, p) => {
							if (p.func == f) {
								if (bindings.length > 0)
									bindings += ", ";
								bindings += key;
							}
						});

					if (bindings.length == 0)
						Minibuf.write ("%s is not on any key", name);
					else
						Minibuf.write ("%s is on %s", name, bindings);
					ok = true;
				}
			}
			return ok;
		},
		true,
		"""Print message listing key sequences that invoke the command DEFINITION.
Argument is a command name."""
		);

	new LispFunc (
		"describe-bindings",
		(uniarg, arglist) => {
			write_temp_buffer (
				"*Help*",
				true,
				() => {
					bprintf ("Key translations:\n");
					bprintf ("%-15s %s\n", "key", "binding");
					bprintf ("%-15s %s\n", "---", "-------");

					walk_bindings (root_bindings, (key, p) => {
							bprintf ("%-15s %s\n", key, p.func.name);
						});
				});
			return true;
		},
		true,
		"""Show a list of all defined keys, and their definitions."""
		);
}
