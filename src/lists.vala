/* Lisp lists

   Copyright (c) 2008-2020 Free Software Foundation, Inc.

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


Lexp *leAddTail (Lexp * list, Lexp * element) {
	Lexp *temp = list;

	/* if either element or list doesn't exist, return the `new' list */
	if (element == null)
		return list;
	if (list == null)
		return element;

	/* find the end element of the list */
	while (temp->next != null)
		temp = temp->next;

	/* tack ourselves on */
	temp->next = element;

	/* return the list */
	return list;
}

Lexp *leAddBranchElement (Lexp * list, Lexp * branch, int quoted) {
	Lexp *temp = new Lexp (null);
	temp->branch = branch;
	temp->quoted = quoted;
	return leAddTail (list, temp);
}

Lexp *leAddDataElement (Lexp * list, string data, int quoted) {
	Lexp *newdata = new Lexp (data);
	newdata->quoted = quoted;
	return leAddTail (list, newdata);
}

Lexp *leDup (Lexp * list) {
	Lexp *temp;

	if (list == null)
		return null;

	temp = new Lexp (list->data);
	temp->branch = leDup (list->branch);
	temp->next = leDup (list->next);

	return temp;
}
