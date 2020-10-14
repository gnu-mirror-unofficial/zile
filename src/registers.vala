/* Registers facility functions

   Copyright (c) 2001-2020 Free Software Foundation, Inc.

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

int NUM_REGISTERS = 256;

Estr regs[256 /* FIXME: NUM_REGISTERS */];

long regnum;

bool insert_register () {
	insert_estr (regs[regnum]);
	return true;
}


public void registers_init () {
	new LispFunc (
		"copy-to-register",
		(uniarg, arglist) => {
			bool ok = true;
			long reg = 1;
			if (noarg (arglist)) {
				Minibuf.write ("Copy to register: ");
				reg = (long) getkey (GETKEY_DEFAULT);
			} else if (!int_init (ref arglist, ref reg))
				ok = false;

			if (ok) {
				if (reg == KBD_CANCEL)
					ok = funcall ("keyboard-quit");
				else {
					Minibuf.clear ();
					if (reg < 0)
						reg = 0;
					reg %= NUM_REGISTERS; /* Nice numbering relies on NUM_REGISTERS
											 being a power of 2. */

					if (warn_if_no_mark ())
						ok = false;
					else {
						long index = reg;
						regs[index] = get_buffer_region (cur_bp, Region.calculate ());
					}
				}
			}
			return ok;
		},
		true,
		"""Copy region into register REGISTER."""
		);

	new LispFunc (
		"insert-register",
		(uniarg, arglist) => {
			bool ok = true;
			if (warn_if_readonly_buffer ())
				return false;

			long reg = 1;
			if (noarg (arglist)) {
				Minibuf.write ("Insert register: ");
				reg = (long) getkey (GETKEY_DEFAULT);
			} else if (!int_init (ref arglist, ref reg))
				ok = false;

			if (ok) {
				if (reg == KBD_CANCEL)
					ok = funcall ("keyboard-quit");
				else {
					Minibuf.clear ();
					reg %= NUM_REGISTERS;

					long index = reg;
					if (regs[index] == null) {
						Minibuf.error ("Register does not contain text");
						ok = false;
					} else {
						funcall ("set-mark-command");
						regnum = reg;
						execute_with_uniarg (uniarg, insert_register, null);
						funcall ("exchange-point-and-mark");
						deactivate_mark ();
					}
				}
			}
			return ok;
		},
		true,
		"""Insert contents of the user specified register.
Puts point before and mark after the inserted text."""
		);

	new LispFunc (
		"list-registers",
		(uniarg, arglist) => {
			write_temp_buffer (
				"*Registers List*",
				true,
				() => {
					for (uint i = 0; i < NUM_REGISTERS; ++i)
						if (regs[i] != null) {
							string s = ((string) regs[i].text).chug ();
							int len = int.min (20, int.max (0, ((int) cur_wp.ewidth) - 6)) + 1;

							bprintf ("Register %s contains ", ((char) i).isprint () ? "%c".printf ((char) i) : "\\%o".printf (i));
							if (s.length > 0)
								bprintf ("text starting with\n    %.*s\n", len, s);
							else if (s != (string) regs[i].text)
								bprintf ("whitespace\n");
							else
								bprintf ("the empty string\n");
						}
				});
			return true;
		},
		true,
		"""List defined registers."""
		);
}
