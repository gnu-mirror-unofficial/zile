/* Minibuffer facility functions

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

using Curses;

using Lisp;

namespace Minibuf {
	public static History files_history;
	public static string contents;

	/*--------------------------------------------------------------------------
	 * Minibuffer wrapper functions.
	 *--------------------------------------------------------------------------*/

	public void init () {
		files_history = new History ();
	}

	public bool no_error ()	{
		return contents == null;
	}

	public void refresh () {
		if (cur_wp != null) {
			if (contents != null)
				TermMinibuf.write (contents);

			/* Redisplay (and leave the cursor in the correct position). */
			term_redraw_cursor ();
			term_refresh ();
		}
	}

	void vwrite (string fmt, va_list ap) {
		string s = fmt.vprintf (ap);
		if (contents == null || s != contents) {
			contents = s;
			refresh ();
		}
	}

	/*
	 * Write the specified string in the minibuffer.
	 */
	public void write (string fmt, ...) {
		vwrite (fmt, va_list());
	}

	/*
	 * Write the specified error string in the minibuffer and signal an error.
	 */
	public void error (string fmt, ...)	{
		vwrite (fmt, va_list ());
		ding ();
	}

	/*
	 * Read a string from the minibuffer.
	 */
	public string? read (string fmt, string? value, ...) {
		return TermMinibuf.read (fmt.vprintf (va_list ()), value != null ? value : "", long.MAX, null, null);
	}

	/*
	 * Read a non-negative number from the minibuffer.
	 */
	public long read_number (string fmt, ...) {
		ulong n = 0;
		string buf = fmt.vprintf (va_list());

		do {
			string? a = read ("%s", "", buf);
			if (a == null) {
				n = long.MAX;
				funcall (F_keyboard_quit);
				break;
			}
			if (a.length == 0) {
				n = long.MAX - 1;
				break;
			}
			if (long.try_parse (a, out n, null, 10) == false) {
				write ("Please enter a number.");
				ding ();
				continue;
			}
		} while (false);

		return (long) n;
	}

	/*
	 * Read a filename from the minibuffer.
	 */
	public string? read_filename (string fmt, string value, string? file, ...) {
		string? p = null;

		string a = value;
		if (file == null && a.length > 0 && a.get (a.length - 1) != '/')
			a += "/";

		if ((a = expand_path (a)) != null) {
			string buf = fmt.vprintf (va_list());

			a = compact_path (a);

			var cp = new Completion (true);
			long pos = a.length;
			if (file != null)
				pos -= file.length;
			p = TermMinibuf.read (buf, a, pos, cp, files_history);

			if (p != null && (p = expand_path (p)) != null)
				files_history.add_element (p);
		}

		return p;
	}

	public bool test_in_completions (string ms, List<string> completions) {
		return completions.find_custom (ms, GLib.strcmp) != null;
	}

	public int read_yesno (string fmt, ...) {
		string errmsg = "Please answer yes or no.";
		Completion cp = new Completion (false);
		int ret = -1;

		cp.completions.append ("no");
		cp.completions.append ("yes");

		string? ms = vread_completion (fmt, "", cp, null, errmsg,
									   test_in_completions, errmsg, va_list());

		if (ms != null) {
			unowned List<string> elem = cp.completions.find_custom (ms, GLib.strcmp);
			GLib.assert (elem != null);
			ret = elem.data == "yes" ? 1 : 0;
		}

		return ret;
	}

	public string? read_completion (string fmt, string val, Completion *cp, History? hp, ...) {
		return TermMinibuf.read (fmt.vprintf (va_list ()), val, long.MAX, cp, hp);
	}

	/*
	 * Read a string from the minibuffer using a completion.
	 */
	public string? vread_completion (string fmt, string val, Completion cp,
									 History? hp, string empty_err,
									 CompletionDelegate test,
									 string invalid_err, va_list ap) {
		string? ms = null;
		string buf = fmt.vprintf (ap);

		for (;;) {
			ms = TermMinibuf.read (buf, val, long.MAX, cp, hp);

			if (ms == null) { /* Cancelled. */
				funcall (F_keyboard_quit);
				break;
			} else if (ms.length == 0) {
				error ("%s", empty_err);
				ms = null;
				break;
			} else {
				/* Complete partial words if possible. */
				if (cp.try (ms, false) == Completion.Code.matched)
					ms = cp.match;

				if (test (ms, cp.completions)) {
					if (hp != null)
						hp.add_element (ms);
					clear ();
					break;
				} else {
					error (invalid_err, ms);
					waitkey ();
				}
			}
		}

		return ms;
	}

	/*
	 * Clear the minibuffer.
	 */
	public void clear () {
		TermMinibuf.write ("");
	}
}
