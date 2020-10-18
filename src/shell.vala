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

bool pipe_command (string cmd, ImmutableEstr? instr, bool do_insert, bool do_replace) {
	SubprocessFlags flags = STDOUT_PIPE;
	Bytes input = null;
	if (instr != null) {
		input = new Bytes.static (((string) instr.text).data);
		flags |= STDIN_PIPE;
	}
	Bytes? output;
	try {
		var process = new Subprocess (flags, "/bin/sh", "-c", cmd);
		process.communicate (input, null, out output, null);
		assert (output != null);
	} catch (Error e) {
		return false;
	}
	Estr res = null;
	if (output != null) {
		ImmutableEstr es = ImmutableEstr.of ((string) output.get_data (), output.length);
		res = Estr.of_empty ();
		res.cat (es);
		res.set_eol_from_text ();
	}
	if (res == null || res.length == 0)
		Minibuf.write ("(Shell command succeeded with no output)");
	else {
		if (do_insert) {
			size_t del = 0;
			if (do_replace && !cur_bp.warn_if_no_mark ()) {
				Region r = Region.calculate ();
				cur_bp.goto_offset (r.start);
				del = r.size ();
			}
			cur_bp.replace_estr (del, res);
		} else {
			int eol_pos = ((string) res.text).last_index_of_char ('\n');
			bool more_than_one_line = eol_pos != -1 && eol_pos != res.length - 1;
			write_temp_buffer (
				"*Shell Command Output*",
				more_than_one_line,
				() => { cur_bp.insert_estr (res); }
				);
			if (!more_than_one_line)
				Minibuf.write ("%s", res.text);
		}
	}

	return true;
}

string? minibuf_read_shell_command () {
	string? ms = Minibuf.read ("Shell command: ", "");
	if (ms == null) {
		funcall ("keyboard-quit");
		return null;
	}

	return ms.length == 0 ? null : ms;
}


public void shell_init () {
	new LispFunc (
		"shell-command",
		(uniarg, arglist) => {
			bool ok = true;
			string? cmd = str_init (ref arglist);
			if (cmd == null)
				cmd = minibuf_read_shell_command ();
			bool insert;
			if (!bool_init (ref arglist, out insert))
				insert = Flags.SET_UNIARG in lastflag;

			if (cmd != null)
				ok = pipe_command (cmd, null, insert, false);
			return ok;
		},
		true,
		"""Execute string COMMAND in inferior shell; display output, if any.
With prefix argument, insert the command's output at point.

Command is executed synchronously.  The output appears in the buffer
`*Shell Command Output*'.  If the output is short enough to display
in the echo area, it is shown there, but it is nonetheless available
in buffer `*Shell Command Output*' even though that buffer is not
automatically displayed.

The optional second argument OUTPUT-BUFFER, if non-nil,
says to insert the output in the current buffer."""
		);

	new LispFunc (
		"shell-command-on-region",
		(uniarg, arglist) => {
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
				if (cur_bp.warn_if_no_mark ())
					ok = false;
				else
					ok = pipe_command (cmd, cur_bp.get_region (Region.calculate ()), insert, true);
			}
			return ok;
		},
		true,
		"""Execute string command in inferior shell with region as input.
Normally display output (if any) in temp buffer `*Shell Command Output*';
Prefix arg means replace the region with it.  Return the exit code of
command.

If the command generates output, the output may be displayed
in the echo area or in a buffer.
If the output is short enough to display in the echo area, it is shown
there.  Otherwise it is displayed in the buffer `*Shell Command Output*'.
The output is available in that buffer in both cases."""
		);
}
