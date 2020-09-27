/* Window handling functions

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

/* The current window. */
public Window cur_wp = null;
/* The first window in list. */
public Window head_wp = null;

/*
 * Structure
 */
public class Window {
	public Window next;		/* The next window in window list. */
	public Buffer bp;		/* The buffer displayed in window. */
	public size_t topdelta;	/* The top line delta from point. */
	public size_t start_column;	/* The start column of the window (>0 if scrolled
								   sideways). */
	public Marker? saved_pt;	/* The point line pointer, line number and offset
							   (used to hold the point in non-current windows). */
	public size_t fwidth;	/* The formal width and height of the window. */
	public size_t fheight;
	public size_t ewidth;	/* The effective width and height of the window. */
	public size_t eheight;
	public bool all_displayed; /* The bottom of the buffer is visible */
	internal size_t lastpointn;		/* The last point line number. */

	public static Window? find (string name) {
		for (Window wp = head_wp; wp != null; wp = wp.next)
			if (wp.bp.name == name)
				return wp;

		return null;
	}

	public size_t o () {
		/* The current window uses the current buffer point; all other
		   windows have a saved point, except that if a window has just been
		   killed, it needs to use its new buffer's current point. */
		if (this == cur_wp) {
			assert (bp == cur_bp);
			assert (saved_pt == null);
			return cur_bp.pt;
		} else {
			if (saved_pt != null)
				return saved_pt.o;
			else
				return bp.pt;
		}
	}

	public bool top_visible () {
		return offset_to_line (bp, o ()) == topdelta;
	}

	public bool bottom_visible () {
		return all_displayed;
	}

	public void resync () {
		size_t n = offset_to_line (bp, bp.pt);
		long delta = (long) (n - lastpointn);

		if (delta != 0) {
			if ((delta > 0 && topdelta + delta < eheight) ||
				(delta < 0 && topdelta >= (size_t) (-delta)))
				topdelta += delta;
			else if (n > eheight / 2)
				topdelta = eheight / 2;
			else
				topdelta = n;
		}
		lastpointn = n;
	}

	/*
	 * Set the current window and its buffer as the current buffer.
	 */
	public void set_current () {
		/* Save buffer's point in a new marker.  */
		if (cur_wp.saved_pt != null)
			cur_wp.saved_pt.unchain ();

		cur_wp.saved_pt = Marker.point ();

		cur_wp = this;
		cur_bp = bp;

		/* Update the buffer point with the window's saved point
		   marker.  */
		if (cur_wp.saved_pt != null) {
			goto_offset (cur_wp.saved_pt.o);
			cur_wp.saved_pt.unchain ();
			cur_wp.saved_pt = null;
		}
	}

	public void delete () {
		Window wp;

		if (this == head_wp)
			wp = head_wp = head_wp.next;
		else
			for (wp = head_wp; wp != null; wp = wp.next)
				if (wp.next == this) {
					wp.next = wp.next.next;
					break;
				}

		if (wp != null) {
			wp.fheight += this.fheight;
			wp.eheight += this.eheight + 1;
			wp.set_current ();
		}

		if (this.saved_pt != null)
			this.saved_pt.unchain ();
	}
}

/*
 * This function creates the scratch buffer and window when there are
 * no other windows (and possibly no other buffers).
 */
public void create_scratch_window () {
	Buffer bp = create_scratch_buffer ();
	Window wp = new Window ();
	cur_wp = head_wp = wp;
	wp.fwidth = wp.ewidth = term_width ();
	/* Save space for minibuffer. */
	wp.fheight = term_height () - 1;
	/* Save space for status line. */
	wp.eheight = wp.fheight - 1;
	wp.bp = cur_bp = bp;
}

/*
DEFUN ("split-window", split_window)
*+
Split current window into two windows, one above the other.
Both windows display the same buffer now current.
+*/
public bool F_split_window (long uniarg, Lexp *arglist) {
	/* Windows smaller than 4 lines cannot be split. */
	if (cur_wp.fheight < 4) {
		Minibuf.error ("Window height %zu too small (after splitting)",
					   cur_wp.fheight);
		return false;
	}

	/* Copy cur_wp. */
	Window newwp = new Window ();
	newwp.next = cur_wp.next;
	newwp.bp = cur_wp.bp;
	newwp.topdelta = cur_wp.topdelta;
	newwp.start_column = cur_wp.start_column;
	newwp.saved_pt = cur_wp.saved_pt;
	newwp.fwidth = cur_wp.fwidth;
	newwp.fheight = cur_wp.fheight;
	newwp.ewidth = cur_wp.ewidth;
	newwp.eheight = cur_wp.eheight;
	newwp.all_displayed = cur_wp.all_displayed;
	newwp.lastpointn = cur_wp.lastpointn;

	/* Adjust new window. */
	newwp.fheight = cur_wp.fheight / 2 + cur_wp.fheight % 2;
	newwp.eheight = newwp.fheight - 1;
	newwp.saved_pt = Marker.point ();

	/* Adjust cur_wp. */
	cur_wp.next = newwp;
	cur_wp.fheight = cur_wp.fheight / 2;
	cur_wp.eheight = cur_wp.fheight - 1;
	if (cur_wp.topdelta >= cur_wp.eheight)
		recenter (cur_wp);

	return true;
}

/*
DEFUN ("delete-window", delete_window)
*+
Remove the current window from the screen.
+*/
public bool F_delete_window (long uniarg, Lexp *arglist) {
	if (cur_wp == head_wp && cur_wp.next == null) {
		Minibuf.error ("Attempt to delete sole ordinary window");
		return false;
	}

	cur_wp.delete ();
	return true;
}

/*
DEFUN ("enlarge-window", enlarge_window)
*+
Make current window one line bigger.
+*/
public bool F_enlarge_window (long uniarg, Lexp *arglist) {
	if (cur_wp == head_wp && (cur_wp.next == null || cur_wp.next.fheight < 3))
		return false;

	Window wp = cur_wp.next;
	if (wp == null || wp.fheight < 3)
		for (wp = head_wp; wp != null; wp = wp.next)
			if (wp.next == cur_wp) {
				if (wp.fheight < 3)
					return false;
				break;
			}

	assert (wp != null);
	--wp.fheight;
	--wp.eheight;
	if (wp.topdelta >= wp.eheight)
		recenter (wp);
	++cur_wp.fheight;
	++cur_wp.eheight;

	return true;
}

/*
DEFUN ("shrink-window", shrink_window)
*+
Make current window one line smaller.
+*/
public bool F_shrink_window (long uniarg, Lexp *arglist) {
	if ((cur_wp == head_wp && cur_wp.next == null) || cur_wp.fheight < 3)
		return false;

	Window wp = cur_wp.next;
	if (wp == null)
		for (wp = head_wp; wp != null; wp = wp.next)
			if (wp.next == cur_wp)
				break;

	assert (wp != null);
	++wp.fheight;
	++wp.eheight;
	--cur_wp.fheight;
	--cur_wp.eheight;
	if (cur_wp.topdelta >= cur_wp.eheight)
		recenter (cur_wp);

	return true;
}

Window popup_window () {
	if (head_wp != null && head_wp.next == null) {
		/* There is only one window on the screen, so split it. */
		funcall (F_split_window);
		return cur_wp.next;
	}

	/* Use the window after the current one, or first window if none. */
	return cur_wp.next != null ? cur_wp.next : head_wp;
}

/*
DEFUN ("delete-other-windows", delete_other_windows)
*+
Make the selected window fill the screen.
+*/
public bool F_delete_other_windows (long uniarg, Lexp *arglist) {
	for (Window wp = head_wp, nextwp = null; wp != null; wp = nextwp) {
		nextwp = wp.next;
		if (wp != cur_wp)
			wp.delete ();
	}
	return true;
}

/*
DEFUN ("other-window", other_window)
*+
Select the first different window on the screen.
All windows are arranged in a cyclic order.
This command selects the window one step away in that order.
+*/
public bool F_other_window (long uniarg, Lexp *arglist) {
	if (cur_wp.next != null)
		cur_wp.next.set_current ();
	else
		head_wp.set_current ();
	return true;
}
