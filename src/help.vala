/* Self documentation facility functions

   Copyright (c) 1997-2021 Free Software Foundation, Inc.

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
   along with this program; if not, see <https://www.gnu.org/licenses/>.  */

public void help_init () {
	new LispFunc (
		"describe-function",
		(uniarg, args) => {
			bool ok = true;
			string? name = args.poll ();
			if (name == null)
				name = minibuf_read_function_name ("Describe function: ");
			if (name == null)
				ok = false;
			else {
				LispFunc? func = LispFunc.find (name);
				if (func == null)
					ok = false;
				else
					write_temp_buffer (
						"*Help*",
						true,
						() => {
							bprintf ("%s is %s built-in function in `C source code'.\n\n%s",
									 func.name,
									 func.interactive ? "an interactive" : "a",
									 func.doc);
						});
			}
			return ok;
		},
		true,
		"""Display the full documentation of a function."""
		);

	new LispFunc (
		"describe-variable",
		(uniarg, args) => {
			bool ok = true;
			string? name = args.poll ();
			if (name == null)
				name = minibuf_read_variable_name ("Describe variable: ");
			if (name == null)
				ok = false;
			else {
				string defval;
				string doc = get_variable_doc (name, out defval);
				if (doc == null)
					ok = false;
				else
					write_temp_buffer (
						"*Help*",
						true,
						() => {
							bprintf ("%s is a variable defined in `C source code'.\n\nIts value is %s\n\n%s",
									 name, get_variable (name), doc);
						});
			}
			return ok;
		},
		true,
		"""Display the full documentation of a variable."""
		);

	new LispFunc (
		"describe-key",
		(uniarg, args) => {
			bool ok = true;
			string name = null, binding = "";

			string? keystr = args.poll ();
			if (keystr != null) {
				Gee.List<Keystroke>? keys = keystrtovec (keystr);
				if (keys != null) {
					name = get_function_by_keys (keys).name;
					binding = keyvectodesc (keys);
				} else
					ok = false;
			} else {
				Minibuf.write ("Describe key:");
				Gee.List<Keystroke> keys = get_key_sequence ();
				name = get_function_by_keys (keys).name;
				binding = keyvectodesc (keys);

				if (name == null) {
					Minibuf.error ("%s is undefined", binding);
					ok = false;
				}
			}

			if (ok) {
				Minibuf.write ("%s runs the command `%s'", binding, name);

				LispFunc? func = LispFunc.find (name);
				if (func == null)
					ok = false;
				else
					write_temp_buffer (
						"*Help*",
						true,
						() => {
							bprintf ("%s runs the command %s, which is %s built-in\nfunction in `C source code'.\n\n%s",
									 binding, func.name,
									 func.interactive ? "an interactive" : "a",
									 func.doc);
						});
			}
			return ok;
		},
		true,
		"""Display documentation of the command invoked by a key sequence."""
		);
}
