/* Macro facility functions

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

class Macro {
	public Gee.List<uint> keys;	/* List of keystrokes. */

	public Macro () {
		this.keys = new ArrayList<uint> ();
	}
}

static Macro? cur_mp = null;
static Macro? cmd_mp = null;

public void add_cmd_to_macro () {
	assert (cmd_mp != null);
	cur_mp.keys.add_all (cmd_mp.keys);
	cmd_mp = null;
}

public void add_key_to_cmd (uint key) {
	if (cmd_mp == null)
		cmd_mp = new Macro ();

	cur_mp.keys.add (key);
}

public void remove_key_from_cmd () {
	assert (cmd_mp != null);
	cmd_mp.keys.remove_at (cmd_mp.keys.size - 1);
}

public void cancel_kbd_macro () {
	cmd_mp = cur_mp = null;
	thisflag &= ~Flags.DEFINING_MACRO;
}

void process_keys (Gee.List<uint> keys) {
	size_t cur = term_buf_len ();
	for (uint i = 0; i < keys.size; i++)
		pushkey (keys.@get ((int) (keys.size - i - 1)));

	while (term_buf_len () > cur)
		get_and_run_command ();
}

static Gee.List<uint> macro_keys;

// FIXME: Make this a delegate
bool call_macro () {
	process_keys (macro_keys);
	return true;
}


public void macro_init () {
	new LispFunc (
		"start-kbd-macro",
		(uniarg, args) => {
			if (Flags.DEFINING_MACRO in thisflag) {
				Minibuf.error ("Already defining a keyboard macro");
				return false;
			}

			if (cur_mp != null)
				cancel_kbd_macro ();

			Minibuf.write ("Defining keyboard macro...");

			thisflag |= Flags.DEFINING_MACRO;
			cur_mp = new Macro ();

			return true;
		},
		true,
		"""Record subsequent keyboard input, defining a keyboard macro.
		The commands are recorded even as they are executed.
		Use \\[end-kbd-macro] to finish recording and make the macro available."""
		);

	new LispFunc (
		"end-kbd-macro",
		(uniarg, args) => {
			if (!(Flags.DEFINING_MACRO in thisflag)) {
				Minibuf.error ("Not defining a keyboard macro");
				return false;
			}

			thisflag &= ~Flags.DEFINING_MACRO;
			return true;
		},
		true,
		"""Finish defining a keyboard macro.
		The definition was started by \\[start-kbd-macro].
		The macro is now available for use via \\[call-last-kbd-macro]."""
		);

	new LispFunc (
		"call-last-kbd-macro",
		(uniarg, args) => {
			if (cur_mp == null) {
				Minibuf.error ("No kbd macro has been defined");
				return false;
			}

			/* FIXME: Call execute-kbd-macro (needs a way to reverse keystrtovec) */
			/* F_execute_kbd_macro (uniarg, true, leAddDataElement (leNew (null), keyvectostr (cur_mp.keys), false)); */
			macro_keys = cur_mp.keys;
			execute_with_uniarg (uniarg, call_macro, null);
			return true;
		},
		true,
		"""Call the last keyboard macro that you defined with \\[start-kbd-macro].
		A prefix argument serves as a repeat count."""
		);

	new LispFunc (
		"execute-kbd-macro",
		(uniarg, args) => {
			string? keystr = args.poll ();
			Gee.List<uint>? keys = keystrtovec (keystr);
			if (keys == null)
				return false;

			macro_keys = keys;
			execute_with_uniarg (uniarg, call_macro, null);
			return true;
		},
		true,
		"""Execute macro as string of editor command characters."""
		);
}
