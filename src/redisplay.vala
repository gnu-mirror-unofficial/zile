/* Terminal independent redisplay routines

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

public void resize_windows () {
	/* Resize windows horizontally. */
	Window wp;
	for (wp = head_wp; wp != null; wp = wp.next)
		wp.ewidth = wp.fwidth = term_width ();

	/* Work out difference in window height; windows may be taller than
	   terminal if the terminal was very short. */
	int hdelta;
	for (hdelta = (int) term_height () - 1, wp = head_wp;
		 wp != null;
		 hdelta -= (int) wp.fheight, wp = wp.next)
		;

	/* Resize windows vertically. */
	if (hdelta > 0) { /* Increase windows height. */
		for (wp = head_wp; hdelta > 0; wp = wp.next) {
			if (wp == null)
				wp = head_wp;
			assert (wp != null);
			++wp.fheight;
			++wp.eheight;
			--hdelta;
        }
    } else { /* Decrease windows' height, and close windows if necessary. */
		for (bool decreased = true; decreased;) {
			decreased = false;
			for (wp = head_wp; wp != null && hdelta < 0; wp = wp.next) {
				if (wp.fheight > 2) {
					--wp.fheight;
					--wp.eheight;
					++hdelta;
					decreased = true;
                } else if (cur_wp != head_wp || cur_wp.next != null) {
					Window new_wp = wp.next;
					wp.delete ();
					wp = new_wp;
					assert (wp != null);
					decreased = true;
                }
            }
        }
    }

	funcall (F_recenter);
}

public void recenter (Window wp) {
	size_t n = offset_to_line (wp.bp, wp.o ());

	if (n > wp.eheight / 2)
		wp.topdelta = wp.eheight / 2;
	else
		wp.topdelta = n;
}

/*
DEFUN ("recenter", recenter)
*+
Center point in selected window and redisplay frame.
+*/
public bool F_recenter (long uniarg, Lexp *arglist) {
	recenter (cur_wp);
	term_clear ();
	term_redisplay ();
	term_refresh ();
	return true;
}
