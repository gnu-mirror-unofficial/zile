/* Completion facility functions

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

public class Completion {
	public string match;		/* The match buffer. */
	public Buffer? old_bp;		/* The buffer from which the completion was invoked. */
	public List<string> completions;	/* The completions list. */
	public List<string> matches;		/* The matches list. */
	public long matchsize;	/* The match buffer size. */
	public Flags flags;			/* Completion flags. */
	public string? path;		/* Path for a filename completion. */

	public enum Code {
		notmatched,
		matched,
		matchednonunique,
		nonunique,
	}

	[Flags]
	public enum Flags {
		POPPEDUP, /* Completion window has been popped up. */
		CLOSE,	  /* The completion window should be closed. */
		FILENAME, /* This is a filename completion. */
	}

	public Completion (bool fileflag) {
		completions = new List<string> ();
		matches = new List<string> ();

		if (fileflag) {
			path = "";
			flags |= FILENAME;
		}
	}

	public static void scroll_up () {
		Window old_wp = cur_wp;
		Window wp = Window.find ("*Completions*");
		assert (wp != null);
		wp.set_current ();
		if (funcall ("scroll-up") == false) {
			funcall ("beginning-of-buffer");
			cur_wp.resync ();
		}
		old_wp.set_current ();

		term_redisplay ();
	}

	public static void scroll_down () {
		Window old_wp = cur_wp;
		Window? wp = Window.find ("*Completions*");
		assert (wp != null);
		wp.set_current ();
		if (funcall ("scroll-down") == false) {
			funcall ("end-of-buffer");
			cur_wp.resync ();
		}
		old_wp.set_current ();

		term_redisplay ();
	}

	// FIXME: Use Gee.Traversable.map
	static uint max_length (List<string> l) {
		uint maxlen = 0;
		for (uint i = 0; i < l.length (); i++)
			maxlen = uint.max (l.nth_data (i).length, maxlen);
		return maxlen;
	}

	void popup_completion (bool allflag) {
		flags |= POPPEDUP;
		if (head_wp.next == null)
			flags |= CLOSE;

		unowned List<string> l = allflag ? completions : matches;
		write_temp_buffer (
			"*Completions*", true,
			() => {
				/* Print the list of completions in a set of columns. */
				uint max = max_length (l) + 5;
				uint numcols = ((uint) cur_wp.ewidth - 1) / max;

				bprintf ("Possible completions are:\n");
				for (uint i = 0, col = 0; i < l.length (); i++) {
					bprintf ("%-*s", (int) max, l.nth_data (i));

					col = (col + 1) % numcols;
					if (col == 0)
						insert_newline ();
				}
			});

		if (Flags.CLOSE in flags)
			old_bp = cur_bp;

		term_redisplay ();
	}

	/*
	 * Reread directory for completions.
	 */
	string? readdir (string in_path) {
		string path = in_path;
		completions = new List<string> ();

		if ((path = expand_path (path)) == null)
			return null;

		/* Split up path with dirname and basename, unless it ends in `/',
		   in which case it's considered to be entirely dirname. */
		string pdir;
		if (path[path.length - 1] != '/') {
			pdir = Path.get_dirname (path);
			if (pdir != "/")
				pdir += "/";
			path = Path.get_basename (path);
		} else {
			pdir = path;
			path = "";
		}

		Dir dir = null;
		try {
			dir = Dir.open (pdir);
			string? name = null;
			while ((name = dir.read_name ()) != null) {
				string p = Path.build_filename (pdir, name);
				string s = name;
				if (FileUtils.test (p, FileTest.IS_DIR))
					s += "/";
				completions.append (s);
			}
		} catch (FileError err) { /* Ignore the error. */ }
		completions.sort (strcmp);

		this.path = compact_path (pdir);

		return dir != null ? path : null;
	}

	/*
	 * Match completions.
	 */
	public Code try (string in_search, bool popup_when_complete) {
		string? search = in_search;
		matches = new List<string> ();

		if (Flags.FILENAME in flags)
			if ((search = readdir (search)) == null)
				return Code.notmatched;

		if (search.length == 0) {
			match = completions.first ().data;
			if (completions.length () > 1) {
				matchsize = 0;
				popup_completion (true);
				return Code.nonunique;
			} else {
				matchsize = match.length;
				return Code.matched;
			}
		}

		size_t fullmatches = 0;
		for (uint i = 0; i < completions.length (); i++) {
			string s = completions.nth_data (i);
			if (Posix.strncmp (s, search, search.length) == 0) {
				matches.append (s);
				if (s == search)
					++fullmatches;
			}
		}
		matches.sort (strcmp);

		if (matches.length () == 0)
			return Code.notmatched;
		else if (matches.length () == 1) {
			match = matches.first ().data;
			matchsize = match.length;
			return Code.matched;
		} else if (matches.length () > 1 && fullmatches == 1) {
			match = matches.first ().data;
			matchsize = match.length;
			if (popup_when_complete)
				popup_completion (false);
			return Code.matchednonunique;
		}

		for (uint j = search.length;; ++j) {
			char c = matches.first ().data[j];
			for (uint i = 1; i < matches.length (); ++i) {
				if (matches.nth_data (i)[j] != c) {
					match = matches.first ().data;
					matchsize = j;
					popup_completion (false);
					return Code.nonunique;
				}
			}
		}
	}
}
