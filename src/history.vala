/* History facility functions

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

public class History {
	List<string> elements;		/* Elements. */
	uint? sel;					/* Selected element. */

	public History () {
		this.elements = new List<string> ();
	}

	public void add_element (string s) {
		if (this.elements.length () == 0 || this.elements.last ().data != s)
			this.elements.append (s);
	}

	public void prepare () {
		this.sel = null;
	}

	public unowned string? previous_element () {
		/* First time that we use `previous-history-element'. */
		if (this.sel == null) { /* Select last element. */
			if (this.elements.length () > 0)
				this.sel = this.elements.length () - 1;
		} else if (this.sel > 0) { /* Is there another element? */
			/* Select it. */
			this.sel--;
		}

		return this.sel == null ? null : this.elements.nth_data (this.sel);
	}

	public unowned string? next_element () {
		if (this.elements.length () > 0 && this.sel != null) {
			/* Next element. */
			if (this.sel + 1 < this.elements.length ()) {
				this.sel++;
			} else /*  No more elements (back to original status). */
				this.sel = null;
		}

		return this.sel == null ? null : this.elements.nth_data (this.sel);
	}
}
