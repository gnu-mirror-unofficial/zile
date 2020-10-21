/* Zile variables handling functions

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
 * Variable type.
 */
public class VarEntry {
	public string name;			/* Variable name. */
	public string defval;		/* Default value. */
	public string val;			/* Current value, if any. */
	public bool local;			/* If true, becomes local when set. */
	public string doc;			/* Documentation */
}

HashTable<string, VarEntry> main_vars;

public void init_builtin_var (string name, string defval, bool local, string doc) {
	VarEntry v = new VarEntry ();
	v.name = name;
	v.val = v.defval = defval;
	v.local = local;
	v.doc = doc;
	main_vars.insert (name, v);
}

HashTable<string, VarEntry> new_varlist () {
	return new HashTable<string, VarEntry> (str_hash, str_equal);
}

void set_variable (string name, string val) {
	/* Find whether variable is buffer-local when set, and if needed
	   create a buffer-local variable list. */
	HashTable<string, VarEntry> var_list = main_vars;
	VarEntry v = main_vars.lookup (name);
	if (v != null && v.local) {
		if (cur_bp.vars == null)
			cur_bp.vars = new_varlist ();
		var_list = cur_bp.vars;
	}

	/* Create variable if it doesn't already exist. */
	if (v == null) {
		v = new VarEntry ();
		v.defval = val;
		v.local = false;
		v.doc = "";
	}

	/* Update value. */
	v.val = val;

	/* Set variable. */
	var_list.insert (name, v);
}

static VarEntry? get_variable_entry (Buffer? bp, string name) {
	if (bp != null && bp.vars != null)
		return bp.vars.lookup (name);
	return main_vars.lookup (name);
}

public unowned string? get_variable_doc (string name, out unowned string defval) {
	VarEntry? v = get_variable_entry (null, name);
	if (v == null) {
		defval = null;
		return null;
	}

	defval = v.defval;
	return v.doc;
}

unowned string? get_variable (string name) {
	VarEntry v = get_variable_entry (cur_bp, name);
	return v != null ? v.val : null;
}

bool get_variable_bool (string name) {
	string val = get_variable (name);
	if (val != null)
		return !str_equal (val, "nil");
	return false;
}

string? minibuf_read_variable_name (string fmt, ...) {
	Completion cp = new Completion (false);
	main_vars.@foreach ((key, val) => {
			cp.completions.add (val.name);
		});

	return Minibuf.vread_completion (fmt, "", cp, null,
									 "No variable name given",
									 "Undefined variable name `%s'", va_list ());
}


public void variables_init () {
	new LispFunc (
		"set-variable",
		(uniarg, arglist) => {
			bool ok = true;
			string? name = str_init (ref arglist);
			if (name == null)
				name = minibuf_read_variable_name ("Set variable: ");
			if (name == null)
				return false;
			string? val = str_init (ref arglist);
			if (val == null)
				val = Minibuf.read ("Set %s to value: ", "", name);
			if (val == null)
				ok = funcall ("keyboard-quit");

			if (ok)
				set_variable (name, val);
			return ok;
		},
		true,
		"""Set a variable value to the user-specified value."""
		);
}
