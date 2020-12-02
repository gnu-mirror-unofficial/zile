/* Buffer-oriented functions

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
   along with this program; if not, see <https://www.gnu.org/licenses/>.  */

public class Buffer {
	public string name;			/* The name of the buffer. */
	public string filename;		/* The file being edited. */
	public Buffer? next;		/* Next buffer in buffer list. */
	public size_t goalc;		/* Goal column for previous/next-line commands. */
	public Marker? mark;		/* The mark. */
	public Marker markers;		/* Markers list (updated whenever text is changed). */
	public List<Undo> *last_undop;		/* Most recent undo delta. */
	public List<Undo> *next_undop;		/* Next undo delta to apply. */
	public HashTable<string, VarEntry> vars;	/* Buffer-local variables. */
	public bool modified;		/* Modified flag. */
	public bool nosave;			/* The buffer need not be saved. */
	public bool needname;		/* On save, ask for a file name. */
	public bool temporary;		/* The buffer is a temporary buffer. */
	public bool readonly;		/* The buffer cannot be modified. */
	public bool backup;			/* The old file has already been backed up. */
	public bool noundo;			/* Do not record undo informations. */
	public bool autofill;		/* The buffer is in Auto Fill mode. */
	public bool isearch;		/* The buffer is in Isearch loop. */
	public bool mark_active;	/* The mark is active. */
	public string dir;			/* The default directory. */

	private size_t _pt;			/* The point. */
	public size_t pt  {
		public get { return _pt; }
		private set {
			if (value < _pt) {
				text.move (value + gap, value, _pt - value);
				text.set (value, '\0', size_t.min (_pt - value, gap));
			} else if (value > _pt) {
				text.move (_pt, _pt + gap, value - _pt);
				text.set (value + gap - size_t.min (value - _pt, gap), '\0', size_t.min (value - _pt, gap));
			}
			_pt = value;
			goalc = calculate_goalc (_pt);
		}
	}
	private Estr text;			/* The text. */
	private size_t gap;			/* Size of gap after point. */

	/*
	 * Allocate a new buffer structure, set the default local
	 * variable values, and insert it into the buffer list.
	 */
	public Buffer (Estr es=Estr.of_empty()) {
		text = es;
		dir = Environment.get_current_dir ();

		/* Insert into buffer list. */
		next = head_bp;
		head_bp = this;

		init ();
	}


	/* Buffer methods that know about the gap. */

	public ImmutableEstr pre_point () {
		return text.substring (0, pt);
	}

	public ImmutableEstr post_point () {
		size_t post_gap = pt + gap;
		return text.substring (post_gap, text.length - post_gap);
	}

	public size_t realo_to_o (size_t o) {
		if (o == size_t.MAX)
			return o;
		else if (o < pt + gap)
			return size_t.min (o, pt);
		else
			return o - gap;
	}

	public size_t o_to_realo (size_t o) {
		return o < pt ? o : o + gap;
	}

	public virtual size_t length {
		get { return realo_to_o (text.length); }
	}

	public size_t line_len (size_t o) {
		return realo_to_o (text.end_of_line (o_to_realo (o))) -
			realo_to_o (text.start_of_line (o_to_realo (o)));
	}

	public char get_char (size_t o) {
		return text.text[o_to_realo (o)];
	}

	public size_t prev_line (size_t o) {
		return realo_to_o (text.prev_line (o_to_realo (o)));
	}

	public size_t next_line (size_t o) {
		return realo_to_o (text.next_line (o_to_realo (o)));
	}

	public size_t start_of_line (size_t o) {
		return realo_to_o (text.start_of_line (o_to_realo (o)));
	}

	public size_t end_of_line (size_t o) {
		return realo_to_o (text.end_of_line (o_to_realo (o)));
	}

	public size_t line_o () {
		return realo_to_o (text.start_of_line (o_to_realo (pt)));
	}

	/*
	 * Replace `del' chars after point with `es'.
	 */
	const int MIN_GAP = 1024; /* Minimum gap size after resize. */
	const int MAX_GAP = 4096; /* Maximum permitted gap size. */
	public bool replace_estr (size_t del, ImmutableEstr es) {
		if (warn_if_readonly ())
			return false;

		size_t newlen = es.len_with_eol (eol);
		undo_save_block (pt, del, newlen);

		/* Adjust gap. */
		size_t oldgap = gap;
		size_t added_gap = oldgap + del < newlen ? MIN_GAP : 0;
		if (added_gap > 0) {
			/* If gap would vanish, open it to MIN_GAP. */
			text.insert (pt, (newlen + MIN_GAP) - (oldgap + del));
			gap = MIN_GAP;
		} else if (oldgap + del > MAX_GAP + newlen) {
			/* If gap would be larger than MAX_GAP, restrict it to MAX_GAP. */
			text.remove (pt + newlen + MAX_GAP, (oldgap + del) - (MAX_GAP + newlen));
			gap = MAX_GAP;
		} else
			gap = oldgap + del - newlen;

		/* Zero any new bit of gap not produced by Estr.insert. */
		if (size_t.max (oldgap, newlen) + added_gap < gap + newlen)
			text.set (pt + size_t.max (oldgap, newlen) + added_gap,
					  '\0',
					  newlen + gap - size_t.max (oldgap, newlen) - added_gap);

		/* Insert `newlen' chars, and adjust raw point position `_pt'. */
		text.replace (pt, es);
		_pt += newlen;
		goalc = calculate_goalc (_pt);

		/* Adjust markers. */
		for (Marker? m = markers; m != null; m = m.next)
			if (m.o > pt - newlen)
				m.o = size_t.max (pt - newlen, m.o + newlen - del);

		modified = true;
		if (es.next_line (0) != size_t.MAX)
			thisflag |= Flags.NEED_RESYNC;
		return true;
	}

	public ImmutableEstr get_region (Region r) {
		Estr es = Estr.of_empty (eol);
		if (r.start < pt)
			es.cat (text.substring (r.start, size_t.min (r.end, pt) - r.start));
		if (r.end > pt) {
			size_t from = size_t.max (r.start, pt);
			es.cat (text.substring (gap + from, r.end - from));
		}
		return es;
	}


	/* Buffer methods that don't know about the gap. */

	public virtual unowned string eol {
		get { return text.eol; }
	}

	public bool insert_estr (ImmutableEstr es) {
		return replace_estr (0, es);
	}

	public bool is_empty_line () {
		return line_len (pt) == 0;
	}

	public bool is_blank_line () {
		for (size_t i = 0; i < line_len (pt); i++)
		{
			char c = get_char (line_o () + i);
			if (c != ' ' && c != '\t')
				return false;
		}
		return true;
	}

	/* Returns the character following point in the current buffer. */
	public char following_char () {
		if (eobp ())
			return 0;
		else if (eolp ())
			return '\n';
		else
			return get_char (pt);
	}

	/* Return the character preceding point in the current buffer. */
	public char preceding_char () {
		if (bobp ())
			return 0;
		else if (bolp ())
			return '\n';
		else
			return get_char (pt - 1);
	}

	/* Return true if point is at the beginning of the buffer. */
	public bool bobp () {
		return pt == 0;
	}

	/* Return true if point is at the end of the buffer. */
	public bool eobp () {
		return pt == length;
	}

	/* Return true if point is at the beginning of a line. */
	public bool bolp () {
		return pt == line_o ();
	}

	/* Return true if point is at the end of a line. */
	public bool eolp () {
		return pt - line_o () == line_len (pt);
	}

	/*
	 * Insert the character `c' at point.
	 */
	public bool insert_char (char c) {
		return insert_estr (ImmutableEstr.of ((string) &c, 1));
	}

	public bool delete_char () {
		mark_active = false;

		if (eobp ()) {
			Minibuf.error ("End of buffer");
			return false;
		}

		if (warn_if_readonly ())
			return false;

		if (eolp ()) {
			replace_estr (eol.length, ImmutableEstr.empty);
			thisflag |= Flags.NEED_RESYNC;
		} else
			replace_estr (1, ImmutableEstr.empty);
		modified = true;

		return true;
	}

	public bool backward_delete_char () {
		mark_active = false;

		if (!move_char (-1)) {
			Minibuf.error ("Beginning of buffer");
			return false;
		}

		delete_char ();
		return true;
	}

	void insert_half_buffer (Buffer bp, ImmutableEstr es) {
		/* Copy text to avoid problems when bp == this. */
		if (bp != this)
			insert_estr (es);
		else
			insert_estr (Estr.copy (es));
	}

	public void insert_buffer (Buffer bp) {
		insert_half_buffer (bp, bp.pre_point ());
		insert_half_buffer (bp, bp.post_point ());
	}

	/*
	 * Unchain the buffer's markers.
	 */
	~Buffer () {
		while (markers != null)
			markers.unchain ();
	}

	/*
	 * Initialise a buffer
	 */
	public void init () {
		if (get_variable_bool ("auto-fill-mode"))
			autofill = true;
	}

	/*
	 * Get filename, or buffer name if null.
	 */
	public string get_filename_or_name () {
		string? fname = filename;
		return fname != null ? fname : name;
	}

	/*
	 * Set a new filename, and from it a name, for the buffer.
	 */
	public void set_names (string new_filename) {
		filename = new_filename;
		if (filename[0] != '/')
			filename = Path.build_filename (Environment.get_current_dir (), filename);

		string new_name = Path.get_basename (filename);
		/* Note: there can't be more than size_t.MAX buffers. */
		for (size_t i = 2; find (new_name) != null; i++)
			new_name += @"<$i>";
		name = new_name;
	}

	public unowned string? get_variable (string name) {
		VarEntry v = get_variable_entry (this, name);
		return v != null ? v.val : null;
	}

	/*
	 * Search for a buffer named `name'.
	 */
	public static Buffer? find (string name) {
		for (Buffer? bp = head_bp; bp != null; bp = bp.next) {
			string? bname = bp.name;
			if (bname != null && bname == name)
				return bp;
		}

		return null;
	}

	/*
	 * Move the given buffer to head.
	 */
	static void move_to_head (Buffer bp) {
		Buffer? prev = null;
		for (Buffer it = head_bp; it != bp; prev = it, it = it.next)
			;
		if (prev != null) {
			prev.next = bp.next;
			bp.next = head_bp;
			head_bp = bp;
		}
	}

	/*
	 * Switch to the specified buffer.
	 */
	public void switch_to () {
		GLib.assert (cur_wp.bp == cur_bp);

		/* The buffer is the current buffer; return safely.  */
		if (cur_bp == this)
			return;

		/* Set current buffer.  */
		cur_bp = this;
		cur_wp.bp = cur_bp;

		/* Move the buffer to head.  */
		move_to_head (this);

		/* Change to buffer's default directory.  */
		if (Posix.chdir (dir) != 0) { /* Ignore error. */ }

		thisflag |= Flags.NEED_RESYNC;
	}

	/*
	 * Print an error message into the echo area and return true
	 * if the current buffer is readonly; otherwise return false.
	 */
	public bool warn_if_readonly () {
		if (readonly) {
			Minibuf.error ("Buffer is readonly: %s", name);
			return true;
		}
		return false;
	}

	public bool warn_if_no_mark () {
		if (mark == null) {
			Minibuf.error ("The mark is not set now");
			return true;
		} else if (!mark_active) {
			Minibuf.error ("The mark is not active now");
			return true;
		}
		return false;
	}

	/*
	 * Set the specified buffer temporary flag and move the buffer
	 * to the end of the buffer list.
	 */
	public void set_temporary () {
		temporary = true;

		if (this == head_bp) {
			if (head_bp.next == null)
				return;
			head_bp = head_bp.next;
		} else if (next == null)
			return;

		Buffer? bp;
		for (bp = head_bp; bp != null; bp = bp.next)
			if (bp.next == this) {
				bp.next = bp.next.next;
				break;
			}

		assert (head_bp != null);
		for (bp = head_bp; bp.next != null; bp = bp.next)
			;

		bp.next = this;
		next = null;
	}

	/*
	 * Return a safe tab width.
	 */
	public size_t tab_width () {
		long? res = parse_number (get_variable ("tab-width"));
		if (res == null || res < 1)
			res = 8;
		return res;
	}

	/*
	 * Remove the buffer from the buffer list and deallocate
	 * its space.  Recreate the scratch buffer when required.
	 */
	public void kill () {
		Buffer? next_bp;
		if (next != null)
			next_bp = next;
		else {
			if (head_bp == this)
				next_bp = null;
			else
				next_bp = head_bp;
		}

		/* Search for windows displaying the buffer to kill. */
		for (Window wp = head_wp; wp != null; wp = wp.next)
			if (wp.bp == this) {
				wp.bp = next_bp;
				wp.topdelta = 0;
				wp.saved_pt = null;
			}

		/* Remove the buffer from the buffer list. */
		if (cur_bp == this)
			cur_bp = next_bp;
		if (head_bp == this)
			head_bp = head_bp.next;
		for (Buffer? bp = head_bp; bp != null && bp.next != null; bp = bp.next)
			if (bp.next == this) {
				bp.next = bp.next.next;
				break;
			}

		/* If no buffers left, recreate scratch buffer and point windows at
		   it. */
		if (next_bp == null) {
			cur_bp = head_bp = next_bp = create_scratch_buffer ();
			for (Window wp = head_wp; wp != null; wp = wp.next)
				wp.bp = head_bp;
		}

		/* Resync windows that need it. */
		for (Window wp = head_wp; wp != null; wp = wp.next)
			if (wp.bp == next_bp)
				wp.resync ();
	}

	public static Completion make_buffer_completion () {
		Completion cp = new Completion (false);
		for (Buffer? bp = head_bp; bp != null; bp = bp.next)
			cp.completions.add (bp.name);
		return cp;
	}

	/*
	 * Check if the buffer has been modified.  If so, asks the user if
	 * they want to save the changes.  If the response is positive, return
	 * true, else false.
	 */
	public bool check_modified () {
		if (modified && !nosave) {
			bool? ans = Minibuf.read_yesno ("Buffer %s modified; kill anyway? (yes or no) ", name);
			if (ans == null) {
				funcall ("keyboard-quit");
				return false;
			} else if (ans == false)
				return false;
		}
		return true;
	}


	/* Basic movement routines */

	public bool move_char (long offset) {
		int dir = offset >= 0 ? 1 : -1;
		for (ulong i = 0; i < (ulong) (offset.abs ()); i++) {
			if (dir > 0 ? !eolp () : !bolp ())
				pt += dir;
			else if (dir > 0 ? !eobp () : !bobp ()) {
				thisflag |= Flags.NEED_RESYNC;
				pt += dir * Posix.strlen (eol);
				if (dir > 0)
					funcall ("beginning-of-line");
				else
					funcall ("end-of-line");
			} else
				return false;
		}

		return true;
	}

	/*
	 * Calculate the goal column.  Take care of expanding tabulations.
	 */
	public size_t calculate_goalc (size_t o) {
		size_t col = 0, t = tab_width ();
		size_t start = start_of_line (o), end = o - start;

		for (size_t i = 0; i < end; i++, col++)
			if (get_char (start + i) == '\t')
				col |= t - 1;

		return col;
	}

	/*
	 * Go to the goal column.  Take care of expanding tabulations.
	 */
	public void goto_goalc () {
		size_t i, col = 0, t = tab_width ();

		for (i = line_o ();
			 i < line_o () + line_len (pt);
			 i++)
			if (col == goalc)
				break;
			else if (get_char (i) == '\t')
				for (size_t w = t - col % t; w > 0 && ++col < goalc; w--)
					;
			else
				++col;

		pt = i;
	}

	delegate size_t BufferMoveLine (size_t o);
	public bool move_line (long n) {
		BufferMoveLine func = next_line;
		if (n < 0) {
			n = -n;
			func = prev_line;
		}

		size_t save_goalc = goalc;
		for (; n > 0; n--) {
			size_t o = func (pt);
			if (o == size_t.MAX)
				break;
			pt = o;
		}
		goalc = save_goalc;

		goto_goalc ();
		goalc = save_goalc;
		thisflag |= Flags.NEED_RESYNC;

		return n == 0;
	}

	public bool move_word (long dir) {
		bool gotword = false;
		do {
			for (; !(dir > 0 ? eolp () : bolp ()); move_char (dir)) {
				if (iswordchar (get_char (pt - ((dir < 0) ? 1 : 0))))
					gotword = true;
				else if (gotword)
					break;
			}
		} while (!gotword && move_char (dir));
		return gotword;
	}

	public bool move_sexp (long dir) {
		bool gotsexp = false;
		bool single_quote = dir < 0, double_quote = single_quote;
		int level = 0;

		for (;;) {
			while (dir > 0 ? !eolp () : !bolp ()) {
				size_t o = pt - (dir < 0 ? 1 : 0);
				char c = get_char (o);

				/* Skip escaped quotes. */
				if ((c == '\"' || c == '\'') && o > line_o () &&
					get_char (o - 1) == '\\') {
					move_char (dir);
					/* Treat escaped ' and " like word chars. */
					c = 'a';
				}

				if ((dir > 0 && isopenbracketchar (c, single_quote, double_quote)) ||
					(dir <= 0 && isclosebracketchar (c, single_quote, double_quote))) {
					if (level == 0 && gotsexp)
						return true;

					level++;
					gotsexp = true;
					if (c == '\"')
						double_quote = !double_quote;
					if (c == '\'')
						single_quote = !double_quote;
				} else if ((dir > 0 && isclosebracketchar (c, single_quote, double_quote)) ||
						   (dir <= 0 && isopenbracketchar (c, single_quote, double_quote))) {
					if (level == 0 && gotsexp)
						return true;

					level--;
					gotsexp = true;
					if (c == '\"')
						double_quote = !double_quote;
					if (c == '\'')
						single_quote = !single_quote;

					if (level < 0) {
						Minibuf.error ("Scan error: \"Containing expression ends prematurely\"");
						return false;
					}
				}

				move_char (dir);

				if (!(c.isalnum () || c == '$' || c == '_')) {
					if (gotsexp && level == 0) {
						if (!(isopenbracketchar (c, single_quote, double_quote) ||
							  isclosebracketchar (c, single_quote, double_quote)))
							move_char (-dir);
						return true;
					}
				} else
					gotsexp = true;
			}
			if (gotsexp && level == 0)
				return true;
			if (dir > 0 ? !move_line (1) : !move_line (-1)) {
				if (level != 0)
					Minibuf.error ("Scan error: \"Unbalanced parentheses\"");
				break;
			}
			if (dir > 0)
				funcall ("beginning-of-line");
			else
				funcall ("end-of-line");
		}
		return false;
	}

	public size_t offset_to_line (size_t offset) {
		size_t n = 0;
		for (size_t o = 0; end_of_line (o) < offset; o = next_line (o))
			n++;
		return n;
	}

	public void goto_offset (size_t o) {
		size_t old_lineo = line_o ();
		pt = o;
		if (line_o () != old_lineo)
			thisflag |= Flags.NEED_RESYNC;
	}
}


Buffer create_auto_buffer (string name) {
	Buffer bp = new Buffer ();
	bp.name = name;
	bp.needname = true;
	bp.temporary = true;
	bp.nosave = true;
	return bp;
}

Buffer create_scratch_buffer () {
	return create_auto_buffer ("*scratch*");
}


public void buffer_init_lisp () {
	new LispFunc (
		"kill-buffer",
		(uniarg, args) => {
			bool ok = true;

			string? buf = args.poll ();
			if (buf == null) {
				Completion *cp = Buffer.make_buffer_completion ();
				buf = Minibuf.read_completion ("Kill buffer (default %s): ",
											   "", cp, null, cur_bp.name);
				if (buf == null)
					ok = funcall ("keyboard-quit");
			}

			Buffer? bp = null;
			if (buf != null && buf.length > 0) {
				bp = Buffer.find (buf);
				if (bp == null) {
					Minibuf.error ("Buffer `%s' not found", buf);
					ok = false;
				}
			} else
				bp = cur_bp;

			if (ok) {
				if (!bp.check_modified ())
					ok = false;
				else
					bp.kill ();
			}

			return ok;
		},
		true,
		"""Kill buffer BUFFER.
With a nil argument, kill the current buffer."""
		);
}
