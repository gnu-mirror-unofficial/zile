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

using Gee;

/*--------------------------------------------------------------------------
 * Key binding.
 *--------------------------------------------------------------------------*/

// FIXME:
// public struct Key : size_t {};
// public struct KeySequence : Gee.List<uint> {};

public class Binding {
	public LispFunc? func;			/* (Leaf node): the function. */
	public Map<uint, Binding>? map;	/* (Other node): Map of key code to Binding. */
	/* Note: the root is always a non-leaf node. */

	public Binding () {
		map = new TreeMap<uint, Binding> ();
	}

	public Binding? find (Gee.List<uint> keys) {
		if (keys.size == 0) {
			/* No more keys: either we found a binding, or we're part-way
			 * through a prefix. */
			assert (func != null || map != null);
			return this;
		} else {
			assert (map != null);
			Binding p = map.@get (keys.first ());
			return p == null ? null : p.find (keys[1 : keys.size]);
		}
	}

	public void bind (Gee.List<uint> keys, LispFunc func) {
		/* If we are on the last keystroke, insert the function. */
		if (keys.size == 0) {
			map = null; /* Erase any previous suffixes. */
			this.func = func;
			return;
		}

		Binding? branch = map.@get (keys.first ());

		/* If this is part of a new prefix, add a new branch. */
		if (branch == null) {
			branch = new Binding ();
			map.@set (keys.first (), branch);
		} else
			/* Erase any previous binding the current key might have had. */
			branch.func = null;

		/* We have more keystrokes: recurse. */
		branch.bind (keys[1 : keys.size], func);
	}
}

Binding root_bindings;

public uint binding_completion (string a) {
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
Gee.List<uint> get_key_sequence () {
	var keys = new Gee.ArrayList<uint> ();
	uint key = 0;

	do
		key = (uint) getkey (GETKEY_DEFAULT);
	while (key == KBD_NOKEY);
	keys.add ((uint) key);
	for (;;) {
		Binding p = root_bindings.find (keys);
		if (p == null || p.func != null)
			break;
		keys.add (binding_completion (keyvectodesc (keys)));
	}

	return keys;
}

public LispFunc get_function_by_keys (Gee.List<uint> keys) {
	/* Detect Meta-digit */
	if (keys.size == 1) {
		uint key = keys.@get (0);
		if ((key & KBD_META) != 0 &&
			(((char) (key & 0xff)).isdigit () || (char) (key & 0xff) == '-'))
			return LispFunc.find ("universal-argument");
	}

	/* See if we've got a valid key sequence */
	Binding? p = root_bindings.find (keys);
	return p != null ? p.func : null;
}

bool self_insert_command () {
	bool ret = true;
	/* Mask out ~KBD_CTRL to allow control sequences to be themselves. */
	int key = (int) (lastkey () & ~KBD_CTRL);
	cur_bp.mark_active = false;
	if (key <= 0xff) {
		if (((char) key).isspace () && cur_bp.autofill)
			ret = fill_break_line () != -1;
		cur_bp.insert_char ((char) key);
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

bool call_command (LispFunc f, long uniarg, Gee.Queue<string>? args) {
	thisflag = lastflag & Flags.DEFINING_MACRO;
	undo_start_sequence ();

	/* Reset last_uniarg before function call, so recursion (e.g. in
	   macros) works. */
	if (!(Flags.SET_UNIARG in thisflag))
		last_uniarg = 1;

	/* Execute the command. */
	_this_command = f;
	bool ok = f.func (uniarg, args);
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
	Gee.List<uint> keys = get_key_sequence ();
	LispFunc f = get_function_by_keys (keys);

	Minibuf.clear ();
	if (f != null)
		call_command (f, last_uniarg, Flags.SET_UNIARG in lastflag ? null : new ArrayQueue<string> ());
	else
		Minibuf.error ("%s is undefined", keyvectodesc (keys));
}

public void init_default_bindings () {
	root_bindings = new Binding ();

	/* Bind all printing keys to self_insert_command */
	for (uint i = 0; i <= 0xff; i++) {
		if (((char) i).isprint ()) {
			var keys = new Gee.ArrayList<uint> ();
			keys.add (i);
			root_bindings.bind (keys, LispFunc.find ("self-insert-command"));
		}
	}

	lisp_loadstring (default_bindings);
}

delegate void BindingsProcessor (string key, Binding p);
delegate void BindingsWalker (Binding tree);
void walk_bindings (BindingsProcessor process) {
	/* FIXME: Use a container rather than a primitive array to work around
	 * https://gitlab.gnome.org/GNOME/vala/-/issues/1090 */
	var keys = new ArrayList<string> ();
	BindingsWalker walker = null;
	walker = (tree) => {
		assert (tree.map != null);
		foreach (uint key in tree.map.keys) {
			Binding p = tree.map.@get (key);
			assert (p != null);

			if (p.func != null)
				process (string.joinv (" ", keys.to_array ()), p);
			else {
				keys.add (chordtodesc (key));
				walker (p);
				keys.remove_at (keys.size - 1);
			}
		}
	};

	walker (root_bindings);
}


public void bind_init () {
	new LispFunc (
		"global-set-key",
		(uniarg, args) => {
			Gee.List<uint>? keys;
			string? keystr = args.poll ();
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

			string? name = args.poll ();
			if (name == null)
				name = minibuf_read_function_name ("Set key %s to command: ", keystr);
			if (name == null)
				return false;

			LispFunc func = LispFunc.find (name);
			if (func == null) { /* Possible if called non-interactively */
				Minibuf.error ("No such function `%s'", name);
				return false;
			}
			root_bindings.bind (keys, func);
			return true;
		},
		true,
		"""Bind a command to a key sequence.
Read key sequence and function name, and bind the function to the key
sequence."""
		);

	new LispFunc (
		"self-insert-command",
		(uniarg, args) => {
			return execute_with_uniarg (uniarg, self_insert_command, null);
		},
		true,
		"""Insert the character you type.
Whichever character you type to run this command is inserted."""
		);

	new LispFunc (
		"where-is",
		(uniarg, args) => {
			string? name = minibuf_read_function_name ("Where is command: ");
			bool ok = false;

			if (name != null) {
				LispFunc? f = LispFunc.find (name);
				if (f != null) {
					string bindings = "";
					walk_bindings ((key, p) => {
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
		(uniarg, args) => {
			write_temp_buffer (
				"*Help*",
				true,
				() => {
					bprintf ("Key translations:\n");
					bprintf ("%-15s %s\n", "key", "binding");
					bprintf ("%-15s %s\n", "---", "-------");

					walk_bindings ((key, p) => {
							bprintf ("%-15s %s\n", key, p.func.name);
						});
				});
			return true;
		},
		true,
		"""Show a list of all defined keys, and their definitions."""
		);
}
