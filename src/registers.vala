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

Estr *regs[256 /* FIXME: NUM_REGISTERS */];

/*
DEFUN_ARGS ("copy-to-register", copy_to_register, INT_ARG (reg))
*+
Copy region into register REGISTER.
+*/
public bool F_copy_to_register (long uniarg, Lexp *arglist) {
	bool ok = true;
	long reg = 1;
	if (noarg (arglist)) {
		Minibuf.write ("Copy to register: ");
		reg = (long) getkey (GETKEY_DEFAULT);
    } else if (!int_init (ref arglist, ref reg))
		ok = false;

	if (ok) {
		if (reg == KBD_CANCEL)
			ok = funcall (F_keyboard_quit);
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
}

long regnum;

bool insert_register () {
	insert_estr (regs[regnum]);
	return true;
}

/*
DEFUN_ARGS ("insert-register", insert_register, INT_ARG (reg))
*+
Insert contents of the user specified register.
Puts point before and mark after the inserted text.
+*/
public bool F_insert_register (long uniarg, Lexp *arglist) {
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
			ok = funcall (F_keyboard_quit);
		else {
			Minibuf.clear ();
			reg %= NUM_REGISTERS;

			long index = reg;
			if (regs[index] == null) {
				Minibuf.error ("Register does not contain text");
				ok = false;
			} else {
				funcall (F_set_mark_command);
				regnum = reg;
				execute_with_uniarg (uniarg, insert_register, null);
				funcall (F_exchange_point_and_mark);
				deactivate_mark ();
			}
		}
	}
	return ok;
}

static void write_registers_list (va_list ap) {
	for (uint i = 0; i < NUM_REGISTERS; ++i)
		if (regs[i] != null) {
			string s = estr_get_as (regs[i]).cstr ().chug ();
			int len = int.min (20, int.max (0, ((int) cur_wp.ewidth) - 6)) + 1;

			bprintf ("Register %s contains ", ((char) i).isprint () ? "%c".printf ((char) i) : "\\%o".printf (i));
			if (s.length > 0)
				bprintf ("text starting with\n    %.*s\n", len, s);
			else if (s != estr_get_as (regs[i]).cstr ())
				bprintf ("whitespace\n");
			else
				bprintf ("the empty string\n");
		}
}

/*
DEFUN ("list-registers", list_registers)
*+
List defined registers.
+*/
public bool F_list_registers (long uniarg, Lexp *arglist) {
	write_temp_buffer ("*Registers List*", true, write_registers_list);
	return true;
}
