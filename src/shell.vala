/* Shell command functions.

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

void write_shell_output (va_list ap) {
	insert_estr (estr_new (ap.arg<Astr *> (), coding_eol_lf));
}

bool pipe_command (string cmd, Astr *instr, bool do_insert, bool do_replace) {
	Bytes input = new Bytes.static (instr.cstr ().data);
	Bytes output;
	try {
		var process = new Subprocess (STDIN_PIPE | STDOUT_PIPE, "/bin/sh", "-c", cmd);
		process.communicate (input, null, out output, null);
	} catch (Error e) {
		return false;
	}
	Astr *res = null;
	if (output.get_data () != null)
		res = Astr.new_cstr ((string) output.get_data ());

	if (res == null || res.len () == 0)
		Minibuf.write ("(Shell command succeeded with no output)");
	else {
		if (do_insert) {
			size_t del = 0;
			if (do_replace && !warn_if_no_mark ()) {
				Region r = Region.calculate ();
				goto_offset (r.start);
				del = r.size ();
			}
			replace_estr (del, estr_new_astr (res));
		} else {
			int eol_pos = res.cstr ().last_index_of_char ('\n');
			bool more_than_one_line = eol_pos != -1 && eol_pos != res.len () - 1;
			write_temp_buffer ("*Shell Command Output*", more_than_one_line,
							   write_shell_output, res);
			if (!more_than_one_line)
				Minibuf.write ("%s", res.cstr ());
		}
	}

	return true;
}

string? minibuf_read_shell_command () {
	string? ms = Minibuf.read ("Shell command: ", "");
	if (ms == null) {
		funcall (F_keyboard_quit);
		return null;
	}

	return ms.length == 0 ? null : ms;
}

/*
DEFUN_ARGS ("shell-command", shell_command, STR_ARG (cmd) BOOL_ARG (insert))
*+
Execute string COMMAND in inferior shell; display output, if any.
With prefix argument, insert the command's output at point.

Command is executed synchronously.  The output appears in the buffer
`*Shell Command Output*'.  If the output is short enough to display
in the echo area, it is shown there, but it is nonetheless available
in buffer `*Shell Command Output*' even though that buffer is not
automatically displayed.

The optional second argument OUTPUT-BUFFER, if non-nil,
says to insert the output in the current buffer.
+*/
public bool F_shell_command (long uniarg, Lexp *arglist) {
	bool ok = true;
	string? cmd = str_init (ref arglist);
	if (cmd == null)
		cmd = minibuf_read_shell_command ();
	bool insert;
	if (!bool_init (ref arglist, out insert))
		insert = Flags.SET_UNIARG in lastflag;

	if (cmd != null)
		ok = pipe_command (cmd, Astr.new_ (), insert, false);
	return ok;
}

/*
DEFUN_ARGS ("shell-command-on-region", shell_command_on_region, STR_ARG (start) STR_ARG (end) STR_ARG (cmd) BOOL_ARG (insert))
*+
Execute string command in inferior shell with region as input.
Normally display output (if any) in temp buffer `*Shell Command Output*';
Prefix arg means replace the region with it.  Return the exit code of
command.

If the command generates output, the output may be displayed
in the echo area or in a buffer.
If the output is short enough to display in the echo area, it is shown
there.  Otherwise it is displayed in the buffer `*Shell Command Output*'.
The output is available in that buffer in both cases.
+*/
public bool F_shell_command_on_region (long uniarg, Lexp *arglist) {
	/* Skip arguments `start' and `end' for Emacs compatibility. */
	str_init (ref arglist);
	str_init (ref arglist);

	string? cmd = str_init (ref arglist);
	if (cmd == null)
		cmd = minibuf_read_shell_command ();
	bool insert;
	if (!bool_init (ref arglist, out insert))
		insert = Flags.SET_UNIARG in lastflag;

	bool ok = true;
	if (cmd != null) {
		if (warn_if_no_mark ())
			ok = false;
		else
			ok = pipe_command (cmd, estr_get_as (get_buffer_region (cur_bp, Region.calculate ())), insert, true);
	}
	return ok;
}
