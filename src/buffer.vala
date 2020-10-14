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
   along with GNU Zile; see the file COPYING.  If not, write to the
   Free Software Foundation, Fifth Floor, 51 Franklin Street, Boston,
   MA 02111-1301, USA.  */

using Lisp;

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
	public size_t pt;			/* The point. FIXME: have accessor methods. */
	internal Estr text;			/* The text. FIXME: make private */
	internal size_t gap;		/* Size of gap after point. FIXME: make private*/

	/*
	 * Allocate a new buffer structure, set the default local
	 * variable values, and insert it into the buffer list.
	 */
	public Buffer () {
		text = Estr.of_empty ();
		dir = Environment.get_current_dir ();

		/* Insert into buffer list. */
		next = head_bp;
		head_bp = this;

		init_buffer (this);
	}
}

/* Buffer methods that know about the gap. */

size_t buffer_pre_point (Buffer bp, out char *ptr) {
	ptr = bp.text.text;
	return bp.pt;
}

size_t buffer_post_point (Buffer bp, out char *ptr) {
	size_t post_gap = bp.pt + bp.gap;
	ptr = bp.text.text + post_gap;
	return bp.text.length - post_gap;
}

void set_buffer_pt (Buffer bp, size_t o) {
	if (o < bp.pt) {
		bp.text.move (o + bp.gap, o, bp.pt - o);
		bp.text.set (o, '\0', size_t.min (bp.pt - o, bp.gap));
	} else if (o > bp.pt) {
		bp.text.move (bp.pt, bp.pt + bp.gap, o - bp.pt);
		bp.text.set (o + bp.gap - size_t.min (o - bp.pt, bp.gap), '\0', size_t.min (o - bp.pt, bp.gap));
	}
	bp.pt = o;
}

size_t realo_to_o (Buffer bp, size_t o) {
	if (o == size_t.MAX)
		return o;
	else if (o < bp.pt + bp.gap)
		return size_t.min (o, bp.pt);
	else
		return o - bp.gap;
}

size_t o_to_realo (Buffer bp, size_t o) {
	return o < bp.pt ? o : o + bp.gap;
}

size_t get_buffer_size (Buffer bp) {
	return realo_to_o (bp, bp.text.length);
}

size_t buffer_line_len (Buffer bp, size_t o) {
	return realo_to_o (bp, bp.text.end_of_line (o_to_realo (bp, o))) -
		realo_to_o (bp, bp.text.start_of_line (o_to_realo (bp, o)));
}

/*
 * Replace `del' chars after point with `es'.
 */
const int MIN_GAP = 1024; /* Minimum gap size after resize. */
const int MAX_GAP = 4096; /* Maximum permitted gap size. */
public bool replace_estr (size_t del, ImmutableEstr es) {
	if (warn_if_readonly_buffer ())
		return false;

	size_t newlen = es.len_with_eol (get_buffer_eol (cur_bp));
	undo_save_block (cur_bp.pt, del, newlen);

	/* Adjust gap. */
	size_t oldgap = cur_bp.gap;
	size_t added_gap = oldgap + del < newlen ? MIN_GAP : 0;
	if (added_gap > 0) {
		/* If gap would vanish, open it to MIN_GAP. */
		cur_bp.text.insert (cur_bp.pt, (newlen + MIN_GAP) - (oldgap + del));
		cur_bp.gap = MIN_GAP;
	} else if (oldgap + del > MAX_GAP + newlen) {
		/* If gap would be larger than MAX_GAP, restrict it to MAX_GAP. */
		cur_bp.text.remove (cur_bp.pt + newlen + MAX_GAP, (oldgap + del) - (MAX_GAP + newlen));
		cur_bp.gap = MAX_GAP;
	} else
		cur_bp.gap = oldgap + del - newlen;

	/* Zero any new bit of gap not produced by Astr.insert. */
	if (size_t.max (oldgap, newlen) + added_gap < cur_bp.gap + newlen)
		cur_bp.text.set (cur_bp.pt + size_t.max (oldgap, newlen) + added_gap,
						 '\0',
						 newlen + cur_bp.gap - size_t.max (oldgap, newlen) - added_gap);

	/* Insert `newlen' chars. */
	cur_bp.text.replace (cur_bp.pt, es);
	cur_bp.pt = cur_bp.pt + newlen;

	/* Adjust markers. */
	for (Marker? m = cur_bp.markers; m != null; m = m.next)
		if (m.o > cur_bp.pt - newlen)
			m.o = size_t.max (cur_bp.pt - newlen, m.o + newlen - del);

	cur_bp.modified = true;
	if (es.next_line (0) != size_t.MAX)
		thisflag |= Flags.NEED_RESYNC;
	return true;
}

bool insert_estr (ImmutableEstr es) {
	return replace_estr (0, es);
}

char get_buffer_char (Buffer bp, size_t o) {
	return bp.text.text[o_to_realo (bp, o)];
}

size_t buffer_prev_line (Buffer bp, size_t o) {
	return realo_to_o (bp, bp.text.prev_line (o_to_realo (bp, o)));
}

size_t buffer_next_line (Buffer bp, size_t o) {
	return realo_to_o (bp, bp.text.next_line (o_to_realo (bp, o)));
}

size_t buffer_start_of_line (Buffer bp, size_t o) {
	return realo_to_o (bp, bp.text.start_of_line (o_to_realo (bp, o)));
}

size_t buffer_end_of_line (Buffer bp, size_t o) {
	return realo_to_o (bp, bp.text.end_of_line (o_to_realo (bp, o)));
}

size_t get_buffer_line_o (Buffer bp) {
	return realo_to_o (bp, bp.text.start_of_line (o_to_realo (bp, bp.pt)));
}


/* Buffer methods that don't know about the gap. */

unowned string get_buffer_eol (Buffer bp) {
	return bp.text.eol;
}

/* Get the buffer region as an Estr. */
Estr get_buffer_region (Buffer bp, Region r) {
	Estr es = Estr.of_empty (get_buffer_eol (bp));
	if (r.start < bp.pt) {
		char *ptr;
		buffer_pre_point (bp, out ptr);
		es.cat (ImmutableEstr.of ((string) (ptr + r.start), size_t.min (r.end, bp.pt) - r.start, get_buffer_eol (bp)));
	}
	if (r.end > bp.pt) {
		size_t from = size_t.max (r.start, bp.pt);
		char *ptr;
		buffer_post_point (bp, out ptr);
		es.cat (ImmutableEstr.of ((string) (ptr + from - bp.pt), r.end - from, get_buffer_eol (bp)));
	}
	return es;
}

/*
 * Insert the character `c' at point in the current buffer.
 */
bool insert_char (char c) {
	return insert_estr (ImmutableEstr.of ((string) &c, 1));
}

bool delete_char () {
	deactivate_mark ();

	if (eobp ()) {
		Minibuf.error ("End of buffer");
		return false;
	}

	if (warn_if_readonly_buffer ())
		return false;

	if (eolp ()) {
		replace_estr (get_buffer_eol (cur_bp).length, ImmutableEstr.empty);
		thisflag |= Flags.NEED_RESYNC;
	} else
		replace_estr (1, ImmutableEstr.empty);
	cur_bp.modified = true;

	return true;
}

delegate size_t PreOrPostPoint (Buffer bp, out char *ptr);
void insert_half_buffer (Buffer bp, PreOrPostPoint f) {
	char *ptr;
	size_t len = f (bp, out ptr);
	ImmutableEstr es = ImmutableEstr.of ((string) ptr, len, get_buffer_eol (bp));
	/* Copy text to avoid problems when bp == cur_bp. */
	if (bp != cur_bp)
		insert_estr (es);
	else {
		Estr es_ = Estr.of_empty (get_buffer_eol (bp));
		es_.cat (es);
		insert_estr (es_);
	}
}

void insert_buffer (Buffer bp) {
	insert_half_buffer (bp, buffer_pre_point);
	insert_half_buffer (bp, buffer_post_point);
}

/*
 * Unchain the buffer's markers.
 */
void destroy_buffer (Buffer bp) {
	while (bp.markers != null)
		bp.markers.unchain ();
}

/*
 * Initialise a buffer
 */
public void init_buffer (Buffer bp) {
	if (get_variable_bool ("auto-fill-mode"))
		bp.autofill = true;
}

/*
 * Get filename, or buffer name if null.
 */
string get_buffer_filename_or_name (Buffer bp) {
	string? fname = bp.filename;
	return fname != null ? fname : bp.name;
}

/*
 * Set a new filename, and from it a name, for the buffer.
 */
void set_buffer_names (Buffer bp, string filename) {
	bp.filename = filename;
	if (filename[0] != '/')
		bp.filename = Path.build_filename (Environment.get_current_dir (), bp.filename);

	string name = Path.get_basename (bp.filename);
	/* Note: there can't be more than size_t.MAX buffers. */
	for (size_t i = 2; find_buffer (name) != null; i++)
		name += @"<$i>";
	bp.name = name;
}

/*
 * Search for a buffer named `name'.
 */
Buffer? find_buffer (string name) {
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
void move_buffer_to_head (Buffer bp) {
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
void switch_to_buffer (Buffer bp) {
	GLib.assert (cur_wp.bp == cur_bp);

	/* The buffer is the current buffer; return safely.  */
	if (cur_bp == bp)
		return;

	/* Set current buffer.  */
	cur_bp = bp;
	cur_wp.bp = cur_bp;

	/* Move the buffer to head.  */
	move_buffer_to_head (bp);

	/* Change to buffer's default directory.  */
	if (Posix.chdir (bp.dir) != 0) { /* Ignore error. */ }

	thisflag |= Flags.NEED_RESYNC;
}

/*
 * Print an error message into the echo area and return true
 * if the current buffer is readonly; otherwise return false.
 */
bool warn_if_readonly_buffer ()
{
	if (cur_bp.readonly) {
		Minibuf.error ("Buffer is readonly: %s", cur_bp.name);
		return true;
	}
	return false;
}

bool warn_if_no_mark () {
	if (cur_bp.mark == null) {
		Minibuf.error ("The mark is not set now");
		return true;
	} else if (!cur_bp.mark_active) {
		Minibuf.error ("The mark is not active now");
		return true;
	}
	return false;
}

/*
 * Set the specified buffer temporary flag and move the buffer
 * to the end of the buffer list.
 */
void set_temporary_buffer (Buffer bp) {
	bp.temporary = true;

	if (bp == head_bp) {
		if (head_bp.next == null)
			return;
		head_bp = head_bp.next;
	} else if (bp.next == null)
		return;

	Buffer? bp0;
	for (bp0 = head_bp; bp0 != null; bp0 = bp0.next)
		if (bp0.next == bp) {
			bp0.next = bp0.next.next;
			break;
		}

	assert (head_bp != null);
	for (bp0 = head_bp; bp0.next != null; bp0 = bp0.next)
		;

	bp0.next = bp;
	bp.next = null;
}

void activate_mark () {
	cur_bp.mark_active = true;
}

void deactivate_mark ()
{
	cur_bp.mark_active = false;
}

/*
 * Return a safe tab width for the given buffer.
 */
size_t tab_width (Buffer bp) {
	long res;
	lisp_to_number (get_variable_bp (bp, "tab-width"), out res);
	if (res < 1)
		res = 8;
	return res;
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

/*
 * Remove the specified buffer from the buffer list and deallocate
 * its space.  Recreate the scratch buffer when required.
 */
void kill_buffer (Buffer kill_bp) {
	Buffer? next_bp;
	if (kill_bp.next != null)
		next_bp = kill_bp.next;
	else {
		if (head_bp == kill_bp)
			next_bp = null;
		else
			next_bp = head_bp;
	}

	/* Search for windows displaying the buffer to kill. */
	for (Window wp = head_wp; wp != null; wp = wp.next)
		if (wp.bp == kill_bp) {
			wp.bp = next_bp;
			wp.topdelta = 0;
			wp.saved_pt = null;
		}

	/* Remove the buffer from the buffer list. */
	if (cur_bp == kill_bp)
		cur_bp = next_bp;
	if (head_bp == kill_bp)
		head_bp = head_bp.next;
	for (Buffer? bp = head_bp; bp != null && bp.next != null; bp = bp.next)
		if (bp.next == kill_bp) {
			bp.next = bp.next.next;
			break;
		}

	destroy_buffer (kill_bp);

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

Completion make_buffer_completion () {
  Completion cp = new Completion (false);
  for (Buffer? bp = head_bp; bp != null; bp = bp.next)
	  cp.completions.append (bp.name);
  cp.completions.sort (GLib.strcmp); // FIXME
  return cp;
}

/*
 * Check if the buffer has been modified.  If so, asks the user if
 * they want to save the changes.  If the response is positive, return
 * true, else false.
 */
bool check_modified_buffer (Buffer bp) {
	if (bp.modified && !bp.nosave)
		for (;;) {
			int ans = Minibuf.read_yesno
				("Buffer %s modified; kill anyway? (yes or no) ", bp.name);
			if (ans == -1) {
				funcall ("keyboard-quit");
				return false;
			}
			else if (ans == 0)
				return false;
			break;
		}

	return true;
}


/* Basic movement routines */

bool move_char (long offset) {
	int dir = offset >= 0 ? 1 : -1;
	for (ulong i = 0; i < (ulong) (offset.abs ()); i++) {
		if (dir > 0 ? !eolp () : !bolp ())
			set_buffer_pt (cur_bp, cur_bp.pt + dir);
		else if (dir > 0 ? !eobp () : !bobp ()) {
			thisflag |= Flags.NEED_RESYNC;
			set_buffer_pt (cur_bp, cur_bp.pt + dir * Posix.strlen (get_buffer_eol (cur_bp)));
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
 * Go to the goal column.  Take care of expanding tabulations.
 */
void goto_goalc () {
	size_t i, col = 0, t = tab_width (cur_bp);

	for (i = get_buffer_line_o (cur_bp);
		 i < get_buffer_line_o (cur_bp) + buffer_line_len (cur_bp, cur_bp.pt);
		 i++)
		if (col == cur_bp.goalc)
			break;
		else if (get_buffer_char (cur_bp, i) == '\t')
			for (size_t w = t - col % t; w > 0 && ++col < cur_bp.goalc; w--)
				;
		else
			++col;

	set_buffer_pt (cur_bp, i);
}

delegate size_t BufferMoveLine (Buffer bp, size_t o);
public bool move_line (long n) {
	BufferMoveLine func = buffer_next_line;
	if (n < 0) {
		n = -n;
		func = buffer_prev_line;
	}

	if (last_command () != LispFunc.find ("next-line") &&
		last_command () != LispFunc.find ("previous-line"))
		cur_bp.goalc = get_goalc ();

	for (; n > 0; n--) {
		size_t o = func (cur_bp, cur_bp.pt);
		if (o == size_t.MAX)
			break;
		set_buffer_pt (cur_bp, o);
	}

	goto_goalc ();
	thisflag |= Flags.NEED_RESYNC;

	return n == 0;
}

public size_t offset_to_line (Buffer bp, size_t offset) {
	size_t n = 0;
	for (size_t o = 0; buffer_end_of_line (bp, o) < offset; o = buffer_next_line (bp, o))
		n++;
	return n;
}

public void goto_offset (size_t o) {
	size_t old_lineo = get_buffer_line_o (cur_bp);
	set_buffer_pt (cur_bp, o);
	if (get_buffer_line_o (cur_bp) != old_lineo) {
		cur_bp.goalc = get_goalc ();
		thisflag |= Flags.NEED_RESYNC;
	}
}


public void buffer_init () {
	new LispFunc (
		"kill-buffer",
		(uniarg, arglist) => {
			bool ok = true;

			string? buf = str_init (ref arglist);
			if (buf == null) {
				Completion *cp = make_buffer_completion ();
				buf = Minibuf.read_completion ("Kill buffer (default %s): ",
											   "", cp, null, cur_bp.name);
				if (buf == null)
					ok = funcall ("keyboard-quit");
			}

			Buffer? bp = null;
			if (buf != null && buf.length > 0) {
				bp = find_buffer (buf);
				if (bp == null) {
					Minibuf.error ("Buffer `%s' not found", buf);
					ok = false;
				}
			} else
				bp = cur_bp;

			if (ok) {
				if (!check_modified_buffer (bp))
					ok = false;
				else
					kill_buffer (bp);
			}

			return ok;
		},
		true,
		"""Kill buffer BUFFER.
With a nil argument, kill the current buffer."""
		);
}
