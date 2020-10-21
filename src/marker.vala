/* Marker facility functions

   Copyright (c) 2004-2020 Free Software Foundation, Inc.

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

public class Marker {
	public Marker? next { get; set; } /* Used to chain all markers in the buffer. */
	public size_t o { get; set; } /* Marker offset within buffer. */
	internal Buffer? bp;					  /* Buffer that marker points into. */

	public void	unchain () {
		if (this.bp == null)
			return;

		Marker prev = null;
		for (Marker m = this.bp.markers; m != null; m = m.next) {
			if (m == this) {
				if (prev != null)
					prev.next = m.next;
				else
					m.bp.markers = m.next;

				m.bp = null;
				break;
			}
			prev = m;
		}
	}

	public void move (Buffer bp, size_t o) {
		if (bp != this.bp) {
			/* Unchain with the previous pointed buffer.  */
			this.unchain ();

			/* Change the buffer.  */
			this.bp = bp;

			/* Chain with the new buffer.  */
			this.next = bp.markers;
			bp.markers = this;
		}

		/* Change the point.  */
		this.o = o;
	}

	public static Marker copy (Marker? m) {
		Marker marker = null;
		if (m != null) {
			marker = new Marker ();
			marker.move (m.bp, m.o);
		}
		return marker;
	}

	public static Marker point () {
		Marker m = new Marker ();
		m.move (cur_bp, cur_bp.pt);
		return m;
	}
}

/*
 * Mark ring
 */

static List<Marker> mark_ring;	/* Mark ring. */

/* Push the current mark to the mark-ring. */
public void push_mark () {
	/* Save the mark.  */
	if (cur_bp.mark != null)
		mark_ring.append (Marker.copy (cur_bp.mark));
	else { /* Save an invalid mark.  */
		Marker m = new Marker ();
		m.move (cur_bp, 0);
		mark_ring.append (m);
	}

	funcall ("set-mark");
}

/* Pop a mark from the mark-ring and make it the current mark. */
public void pop_mark () {
	Marker m = mark_ring.nth_data (mark_ring.length () - 1);
	assert (m != null);

	/* Replace the mark. */
	assert (m.bp != null);
	Marker? buf_m = m.bp.mark;
	if (buf_m != null)
		buf_m.unchain ();

	m.bp.mark = Marker.copy (m);

	m.unchain ();
	mark_ring.remove (m);
}

/* Set the mark to point. */
public void set_mark () {
	if (cur_bp.mark == null)
		cur_bp.mark = Marker.point ();
	else
		cur_bp.mark.move (cur_bp, cur_bp.pt);
}
