/* Regions

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

public class Region {
	public size_t start { get; set; }
	public size_t end { get; set; }

	/*
	 * Make a region from two offsets.
	 */
	public Region (size_t o1, size_t o2) {
		this.start = size_t.min (o1, o2);
		this.end = size_t.max (o1, o2);
	}

	public size_t size () {
		return this.end - this.start;
	}

	/*
	 * Return the region between point and mark.
	 */
	public static Region calculate () {
		return new Region (cur_bp.pt, cur_bp.mark.o);
	}

	public bool delete () {
		if (cur_bp.warn_if_readonly ())
			return false;

		Marker m = Marker.point ();
		cur_bp.goto_offset (this.start);
		cur_bp.replace_estr (this.size (), ImmutableEstr.empty);
		cur_bp.goto_offset (m.o);
		m.unchain ();
		return true;
	}

	public bool	contains (size_t o) {
		return o >= this.start && o < this.end;
	}
}
