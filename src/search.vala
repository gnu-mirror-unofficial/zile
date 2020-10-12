/* Search and replace functions

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

using Regex;

using Lisp;

/* Return true if there are no upper-case letters in the given string.
   If `regex' is true, ignore escaped characters. */
bool no_upper (string s, uint len, bool regex) {
	bool quote_flag = false;

	for (uint i = 0; i < len; i++) {
		if (regex && s[i] == '\\')
			quote_flag = !quote_flag;
		else if (!quote_flag && s[i].isupper ())
			return false;
	}

	return true;
}

unowned string? re_find_err = null;

long find_substr (Astr *a, string n, size_t nsize,
				  bool forward, bool notbol, bool noteol, bool regex, bool icase) {
	long ret = -1;
	Pattern pattern = Pattern ();
	Registers search_regs = Registers ();
	Syntax syntax = SyntaxType.EMACS;

	if (!regex)
		syntax |= Syntax.PLAIN;
	if (icase)
		syntax |= Syntax.ICASE;
	set_syntax (syntax);
	search_regs.num_regs = 1;

	re_find_err = compile_pattern (n, (int) nsize, &pattern);
	pattern.not_bol = notbol;
	pattern.not_eol = noteol;
	long len = (long) a.len ();
	if (re_find_err == null)
		ret = Regex.search (&pattern, a.cstr (), (Offset) len,
							(Offset) (forward ? 0 : len), (Offset) (forward ? len : -len),
							&search_regs);

	if (ret >= 0)
		ret = forward ? search_regs.end[0] : ret;

	return ret;
}

bool search (string s, bool forward, bool regexp) {
	uint ssize = s.length;
	if (ssize < 1)
		return false;

	/* Attempt match. */
	size_t o = cur_bp.pt;
	bool notbol = forward ? o > 0 : false;
	bool noteol = forward ? false : o < get_buffer_size (cur_bp);
	long pos = find_substr (forward ? get_buffer_post_point (cur_bp) : get_buffer_pre_point (cur_bp),
							s, ssize, forward, notbol, noteol, regexp,
							get_variable_bool ("case-fold-search") && no_upper (s, ssize, regexp));
	if (pos < 0)
		return false;

	goto_offset (pos + (forward ? cur_bp.pt : 0));
	thisflag |= Flags.NEED_RESYNC;
	return true;
}

string? last_search = null;

bool do_search (bool forward, bool regexp, string? pattern_in) {
	bool ok = false;
	string? pattern = pattern_in;

	if (pattern == null)
		pattern = Minibuf.read ("%s%s: ", last_search,
								regexp ? "RE search" : "Search", forward ? "" : " backward");

	if (pattern == null)
		return funcall ("keyboard-quit");
	if (pattern.length != 0) {
		last_search = pattern;

		if (!search (pattern, forward, regexp))
			Minibuf.error ("Search failed: \"%s\"", pattern);
		else
			ok = true;
	}

	return ok;
}

/*
 * Incremental search engine.
 */
bool isearch (bool forward, bool regexp) {
	Marker old_mark = Marker.copy (cur_wp.bp.mark);

	cur_wp.bp.isearch = true;

	bool last = true;
	string pattern = "";
	size_t start = cur_bp.pt, cur = start;
	for (;;) {
		/* Make the minibuf message. */
		Astr *buf = Astr.fmt ("%sI-search%s: %s",
							  (last ?
							   (regexp ? "Regexp " : "") :
							   (regexp ? "Failing regexp " : "Failing ")),
							  forward ? "" : " backward",
							  pattern);

		/* Regex error. */
		if (re_find_err != null) {
			if (re_find_err.has_prefix ("Premature ") ||
				re_find_err.has_prefix ("Unmatched ") ||
				re_find_err.has_prefix ("Invalid ")) {
				re_find_err = "incomplete input";
			}
			buf.cat (Astr.fmt (" [%s]", re_find_err));
			re_find_err = null;
		}

		Minibuf.write ("%s", buf.cstr ());

		uint c = (uint) getkey (GETKEY_DEFAULT);

		if (c == KBD_CANCEL) {
			goto_offset (start);
			thisflag |= Flags.NEED_RESYNC;

			/* Quit. */
			funcall ("keyboard-quit");

			/* Restore old mark position. */
			if (cur_bp.mark != null)
				cur_bp.mark.unchain ();

			cur_bp.mark = Marker.copy (old_mark);
			break;
		} else if (c == KBD_BS) {
			if (pattern.length > 0) {
				pattern = pattern.slice (0, -1);
				cur = start;
				goto_offset (start);
				thisflag |= Flags.NEED_RESYNC;
			} else
				ding ();
		} else if ((c & KBD_CTRL) != 0 && (c & 0xff) == 'q') {
			Minibuf.write ("%s^Q-", buf.cstr ());
			pattern += ((char) getkey_unfiltered (GETKEY_DEFAULT)).to_string ();
		} else if ((c & KBD_CTRL) != 0 && ((char) (c & 0xff) == 'r' || (char) (c & 0xff) == 's')) {
			/* Invert direction. */
			if ((char) (c & 0xff) == 'r')
				forward = false;
			else if ((char) (c & 0xff) == 's')
				forward = true;
			if (pattern.length > 0) {
				/* Find next match. */
				cur = cur_bp.pt;
				/* Save search string. */
				last_search = pattern;
			} else if (last_search != null)
				pattern = last_search;
		} else if ((c & KBD_META) != 0 || (c & KBD_CTRL) != 0 || c > KBD_TAB) {
			if (c == KBD_RET && pattern.length == 0)
				do_search (forward, regexp, null);
			else {
				if (pattern.length > 0) {
					/* Save mark. */
					set_mark ();
					cur_bp.mark.o = start;

					/* Save search string. */
					last_search = pattern;

					Minibuf.write ("Mark saved when search started");
				} else
					Minibuf.clear ();
				if (c != KBD_RET)
					ungetkey (c);
			}
			break;
		} else
			pattern += ((char) c).to_string ();

		if (pattern.length > 0) {
			goto_offset (cur);
			last = search (pattern, forward, regexp);
		} else
			last = true;

		if (Flags.NEED_RESYNC in thisflag) {
			cur_wp.resync ();
			term_redisplay ();
		}
	}

	/* done */
	cur_wp.bp.isearch = false;

	if (old_mark != null)
		old_mark.unchain ();

	return true;
}

/*
 * Check the case of a string.
 * Returns 2 if it is all upper case, 1 if just the first letter is,
 * and 0 otherwise.
 */
int check_case (Astr *a) {
	size_t i;
	for (i = 0; i < a.len () && a.get (i).isupper (); i++)
		;
	if (i == a.len ())
		return 2;
	else if (i == 1)
		for (; i < a.len () && !a.get (i).isupper (); i++)
			;
	return i == a.len () ? 1 : 0;
}


public void search_init () {
	new LispFunc (
		"search-forward",
		(uniarg, arglist) => {
			string? pattern = str_init (ref arglist);
			return do_search (true, false, pattern);
		},
		true,
		"""Search forward from point for the user specified text."""
		);

	new LispFunc (
		"search-backward",
		(uniarg, arglist) => {
			string? pattern = str_init (ref arglist);
			return do_search (false, false, pattern);
		},
		true,
		"""Search backward from point for the user specified text."""
		);

	new LispFunc (
		"search-forward-regexp",
		(uniarg, arglist) => {
			string? pattern = str_init (ref arglist);
			return do_search (true, true, pattern);
		},
		true,
		"""Search forward from point for regular expression REGEXP."""
		);

	new LispFunc (
		"search-backward-regexp",
		(uniarg, arglist) => {
			string pattern = str_init (ref arglist);
			return do_search (false, true, pattern);
		},
		true,
		"""Search backward from point for match for regular expression REGEXP."""
		);

	new LispFunc (
		"isearch-forward",
		(uniarg, arglist) => {
			return isearch (true, Flags.SET_UNIARG in lastflag);
		},
		true,
		"""Do incremental search forward.
With a prefix argument, do an incremental regular expression search instead.

As you type characters, they add to the search string and are found.

Type \\[isearch-exit] to exit, leaving point at location found.
Type \\[isearch-repeat-forward] to search again forward, \\[isearch-repeat-backward] to search again backward.
\\[isearch-abort] when search is successful aborts and moves point to starting point."""
		);

	new LispFunc (
		"isearch-backward",
		(uniarg, arglist) => {
			return isearch (false, Flags.SET_UNIARG in lastflag);
		},
		true,
		"""Do incremental search backward.
With a prefix argument, do a regular expression search instead.
See the command `isearch-forward' for more information."""
		);

	new LispFunc (
		"isearch-forward-regexp",
		(uniarg, arglist) => {
			return isearch (true, !(Flags.SET_UNIARG in lastflag));
		},
		true,
		"""Do incremental search forward for regular expression.
With a prefix argument, do a regular string search instead.
Like ordinary incremental search except that your input is treated
as a regexp.  See the command `isearch-forward' for more information."""
		);

	new LispFunc (
		"isearch-backward-regexp",
		(uniarg, arglist) => {
			return isearch (false, !(Flags.SET_UNIARG in lastflag));
		},
		true,
		"""Do incremental search backward for regular expression.
With a prefix argument, do a regular string search instead.
Like ordinary incremental search except that your input is treated
as a regexp.  See the command `isearch-forward-regexp` for more information."""
		);

	new LispFunc (
		"query-replace",
		(uniarg, arglist) => {
			bool ok = true;
			string? find = Minibuf.read ("Query replace string: ", "");
			if (find == null)
				return funcall ("keyboard-quit");
			if (find.length == 0)
				return false;
			bool find_no_upper = no_upper (find, find.length, false);

			string? repl = Minibuf.read ("Query replace `%s' with: ", "", find);
			if (repl == null)
				return funcall ("keyboard-quit");

			bool noask = false;
			size_t count = 0;
			while (search (find, true, false)) {
				uint c = ' ';

				if (!noask) {
					if (Flags.NEED_RESYNC in thisflag)
						cur_wp.resync ();

					Minibuf.write ("Query replacing `%s' with `%s' (y, n, !, ., q)? ", find, repl);
					c = (uint) getkey (GETKEY_DEFAULT);
					Minibuf.clear ();

					if (c == 'q')			/* Quit immediately. */
						break;
					else if (c == KBD_CANCEL) {
						ok = funcall ("keyboard-quit");
						break;
					} else if (c == '!')
						noask = true;
				}

				if (c == KBD_RET || c == ' ' || c == 'y' || c == 'Y' ||  c == '.' || c == '!') { /* Perform replacement. */
					++count;
					string case_repl = repl;
					Region r = new Region (cur_bp.pt - find.length, cur_bp.pt);
					if (find_no_upper && get_variable_bool ("case-replace")) {
						int case_type = check_case (estr_get_as (get_buffer_region (cur_bp, r)));
						if (case_type != 0)
							case_repl = Astr.new_cstr (repl).recase (case_type == 1 ? Case.capitalized : Case.upper).cstr ();
					}

					Marker m = Marker.point ();
					goto_offset (r.start);
					replace_estr (find.length, estr_new_astr (Astr.new_cstr (case_repl)));
					goto_offset (m.o);
					m.unchain ();

					if (c == '.')		/* Replace and quit. */
						break;
				} else if (!(c == KBD_RET || c == KBD_DEL || c == 'n' || c == 'N')) {
					ungetkey (c);
					ok = false;
					break;
				}
			}

			if (Flags.NEED_RESYNC in thisflag)
				cur_wp.resync ();

			if (ok)
				Minibuf.write ("Replaced %zu occurrences", count);

			return ok;
		},
		true,
		"""Replace occurrences of a string with other text.
As each match is found, the user must type a character saying
what to do with it."""
		);
}
