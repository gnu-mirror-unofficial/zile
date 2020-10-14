/* Undo facility functions

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

/*
 * Undo action
 */
public enum UndoType {
	START_SEQUENCE,
	END_SEQUENCE,
	SAVE_BLOCK,
}

public class Undo {
	public UndoType type;	/* The type of undo delta. */
	public size_t o;		/* Buffer offset of the undo delta. */
	public bool unchanged;	/* Flag indicating that reverting this undo leaves
							   the buffer in an unchanged state. */
	public Estr text;		/* Old text. */
	public size_t size;		/* Size of replacement text. */
}

/*
 * Save a reverse delta for doing undo.
 */
void undo_save (UndoType type, size_t o, size_t osize, size_t size) {
	if (cur_bp.noundo)
		return;

	Undo u = new Undo ();
	u.type = type;
	u.o = o;

	if (type == SAVE_BLOCK) {
		u.size = size;
		u.text = get_buffer_region (cur_bp, new Region (o, o + osize));
		u.unchanged = !cur_bp.modified;
	}

	cur_bp.last_undop->prepend (u);
}

public void undo_start_sequence () {
	if (cur_bp != null)
		undo_save (START_SEQUENCE, cur_bp.pt, 0, 0);
}

public void undo_end_sequence () {
	if (cur_bp != null) {
		List<Undo> *l = cur_bp.last_undop;
		if (l->length () > 0) {
			if (l->data.type == START_SEQUENCE)
				cur_bp.last_undop = l->next;
			else
				undo_save (END_SEQUENCE, 0, 0, 0);
		}

		/* Update list pointer */
		if (last_command () != LispFunc.find ("undo"))
			cur_bp.next_undop = cur_bp.last_undop;
	}
}

public void undo_save_block (size_t o, size_t osize, size_t size) {
	undo_save (SAVE_BLOCK, o, osize, size);
}

/*
 * Revert an action.  Return the next undo entry.
 */
List<Undo> *revert_action (List<Undo> *l) {
	if (l->data.type == END_SEQUENCE)
		for (l = l->next; l->data.type != START_SEQUENCE; l = revert_action (l))
			;

	if (l->data.type != END_SEQUENCE)
		goto_offset (l->data.o);
	if (l->data.type == SAVE_BLOCK)
		replace_estr (l->data.size, l->data.text);
	if (l->data.unchanged)
		cur_bp.modified = false;

	return l->next;
}

/*
 * Set unchanged flags to false.
 */
public void undo_set_unchanged (List<Undo> l) {
	foreach (Undo u in l) {
		u.unchanged = false;
	}
}


public void undo_init () {
	new LispFunc (
		"undo",
		(uniarg, arglist) => {
			if (cur_bp.noundo) {
				Minibuf.error ("Undo disabled in this buffer");
				return false;
			}

			if (warn_if_readonly_buffer ())
				return false;

			if (cur_bp.next_undop == null) {
				Minibuf.error ("No further undo information");
				cur_bp.next_undop = cur_bp.last_undop;
				return false;
			}

			cur_bp.next_undop = revert_action (cur_bp.next_undop);
			Minibuf.write ("Undo!");
			return true;
		},
		true,
		"""Undo some previous changes.
		Repeat this command to undo more changes."""
		);
}
