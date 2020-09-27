/* Minibuffer handling

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

namespace TermMinibuf {
	public void write (string s) {
		term_move (term_height () - 1, 0);
		term_clrtoeol ();
		term_addstr (s);
	}

	void draw_read (string prompt, string val,
					size_t prompt_len, string match, size_t pointo) {
		write (prompt);

		int margin = 1;
		size_t n = 0;
		if (prompt_len + pointo + 1 >= term_width ()) {
			margin++;
			term_addstr ("$");
			n = pointo - pointo % (term_width () - prompt_len - 2);
		}

		term_addstr (val.substring ((long) n));
		term_addstr (match);

		if (val.substring ((long) n).length >= term_width () - prompt_len - margin) {
			term_move (term_height () - 1, term_width () - 1);
			term_addstr ("$");
		}

		term_move (term_height () - 1,
				   prompt_len + margin - 1 + pointo % (term_width () - prompt_len -
													   margin));

		term_refresh ();
	}

	void maybe_close_popup (Completion? cp) {
		Window wp = null;
		Window old_wp = cur_wp;
		if (cp != null && (cp.flags & Completion.Flags.POPPEDUP) != 0 &&
			(wp = Window.find ("*Completions*")) != null) {
			wp.set_current ();
			if ((cp.flags & Completion.Flags.CLOSE) != 0)
				funcall (F_delete_window);
			else if (cp.old_bp != null)
				switch_to_buffer (cp.old_bp);
			old_wp.set_current ();
			term_redisplay ();
		}
	}

	delegate void Closure ();
	public string? read (string prompt, string val, long pos, Completion? cp, History? hp) {
		if (hp != null)
			hp.prepare ();

		uint c = 0;
		int thistab = 0, lasttab = -1;
		string? a = val, saved = null;

		size_t prompt_len = prompt.length;
		if (pos == long.MAX)
			pos = a.length;

		Closure do_got_tab = () => {
			if (cp == null) {
				ding ();
				return;
			}

			if (lasttab != -1 && lasttab != Completion.Code.notmatched
				&& (Completion.Flags.POPPEDUP in cp.flags)) {
				Completion.scroll_up ();
				thistab = lasttab;
			} else {
				thistab = cp.try (a, true);

				Closure some_match = () => {
					string bs = "";
					if (Completion.Flags.FILENAME in cp.flags)
						bs = cp.path;
					bs += cp.match.substring (0, cp.matchsize);
					if (!a.has_prefix (bs))
						thistab = -1;
					a = bs;
					pos = a.length;
				};

				switch (thistab) {
				case Completion.Code.matched:
					maybe_close_popup (cp);
					cp.flags &= ~Completion.Flags.POPPEDUP;
					some_match ();
					break;
				case Completion.Code.matchednonunique:
					some_match ();
					break;
				case Completion.Code.nonunique:
					some_match ();
					break;
				case Completion.Code.notmatched:
					ding ();
					break;
				default:
					break;
				}
			}
		};

		Closure other_key = () => {
			if (c > 255 || !((char) c).isprint ())
				ding ();
			else {
				a = a.slice (0, pos) + ((char) c).to_string () + a.substring (pos);
				pos++;
			}
		};

		do {
			string s;
			switch (lasttab) {
			case Completion.Code.matchednonunique:
				s = " [Complete, but not unique]";
				break;
			case Completion.Code.notmatched:
				s = " [No match]";
				break;
			case Completion.Code.matched:
				s = " [Sole completion]";
				break;
			default:
				s = "";
				break;
			}
			draw_read (prompt, a, prompt_len, s, pos);

			thistab = -1;

			switch (c = getkeystroke (GETKEY_DEFAULT)) {
			case KBD_NOKEY:
			case KBD_RET:
				break;
			case KBD_CTRL | 'z':
				funcall (F_suspend_emacs);
				break;
			case KBD_CANCEL:
				a = null;
				break;
			case KBD_CTRL | 'a':
			case KBD_HOME:
				pos = 0;
				break;
			case KBD_CTRL | 'e':
			case KBD_END:
				pos = a.length;
				break;
			case KBD_CTRL | 'b':
			case KBD_LEFT:
				if (pos > 0)
					--pos;
				else
					ding ();
				break;
			case KBD_CTRL | 'f':
			case KBD_RIGHT:
				if (pos < a.length)
					++pos;
				else
					ding ();
				break;
			case KBD_CTRL | 'k':
				/* FIXME: do kill-register save. */
				if (pos < a.length)
					a = a.substring (0, pos);
				else
					ding ();
				break;
			case KBD_BS:
				if (pos > 0) {
					a = a.slice (0, pos - 1) + a.substring (pos);
					--pos;
				} else
					ding ();
				break;
			case KBD_CTRL | 'd':
			case KBD_DEL:
				if (pos < a.length)
					a = a.slice (0, pos) + a.substring (pos + 1);
				else
					ding ();
				break;
			case KBD_META | 'v':
			case KBD_PGUP:
				if (cp == null) {
					ding ();
					break;
				}

				if ((cp.flags & Completion.Flags.POPPEDUP) != 0) {
					Completion.scroll_down ();
					thistab = lasttab;
				}
				break;
			case KBD_CTRL | 'v':
			case KBD_PGDN:
				if (cp == null) {
					ding ();
					break;
				}

				if ((cp.flags & Completion.Flags.POPPEDUP) != 0) {
					Completion.scroll_up ();
					thistab = lasttab;
				}
				break;
			case KBD_UP:
			case KBD_META | 'p':
				if (hp != null) {
					string? elem = hp.previous_element ();
					if (elem != null) {
						if (saved == null)
							saved = a;
						a = elem;
					}
				}
				break;
			case KBD_DOWN:
			case KBD_META | 'n':
				if (hp != null) {
					string? elem = hp.next_element ();
					if (elem != null)
						a = elem;
					else if (saved != null) {
						a = saved;
						saved = null;
					}
				}
				break;
			case KBD_TAB:
				do_got_tab ();
				break;
			case ' ':
				if (cp != null) {
					do_got_tab ();
					break;
				}
				other_key ();
				break;
			default:
				other_key ();
				break;
			}

			lasttab = thistab;
		} while (c != KBD_RET && c != KBD_CANCEL);

		Minibuf.clear ();
		maybe_close_popup (cp);
		return a;
	}
}
