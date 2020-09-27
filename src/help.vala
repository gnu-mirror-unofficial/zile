/* Self documentation facility functions

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

void write_function_description (va_list ap) {
	string name = ap.arg<string> ();
	string doc = ap.arg<string> ();
	int interactive = get_function_interactive (name);

	bprintf ("%s is %s built-in function in `C source code'.\n\n%s",
			 name,
			 interactive != 0 ? "an interactive" : "a",
			 doc);
}

/*
DEFUN_ARGS ("describe-function", describe_function, STR_ARG (func))
*+
Display the full documentation of a function.
+*/
public bool F_describe_function (long uniarg, Lexp *arglist) {
	bool ok = true;
	string? func = str_init (ref arglist);
	if (func == null)
		func = minibuf_read_function_name ("Describe function: ");
	if (func == null)
		ok = false;
	else {
		string doc = get_function_doc (func);
		if (doc == null)
			ok = false;
		else
			write_temp_buffer ("*Help*", true,
							   write_function_description, func, doc);
    }
	return ok;
}

void write_variable_description (va_list ap) {
	string name = ap.arg<string> ();
	string curval = ap.arg<string> ();
	string doc = ap.arg<string> ();
	bprintf ("%s is a variable defined in `C source code'.\n\nIts value is %s\n\n%s",
			 name, curval, doc);
}

/*
DEFUN_ARGS ("describe-variable", describe_variable, STR_ARG (name))
*+
Display the full documentation of a variable.
+*/
public bool F_describe_variable (long uniarg, Lexp *arglist) {
	bool ok = true;
	string? name = str_init (ref arglist);
	if (name == null)
		name = minibuf_read_variable_name ("Describe variable: ");
	if (name == null)
		ok = false;
	else {
		string defval;
		string doc = get_variable_doc (name, out defval);
		if (doc == null)
			ok = false;
		else
			write_temp_buffer ("*Help*", true,
							   write_variable_description,
							   name, get_variable (name), doc);
	}
	return ok;
}

void write_key_description (va_list ap) {
	string name = ap.arg<string> ();
	string doc = ap.arg<string> ();
	string binding = ap.arg<string> ();
	int interactive = get_function_interactive (name);

	assert (interactive != -1);

	bprintf ("%s runs the command %s, which is %s built-in\nfunction in `C source code'.\n\n%s",
			 binding, name,
			 interactive != 0 ? "an interactive" : "a",
			 doc);
}

/*
DEFUN_ARGS ("describe-key", describe_key, STR_ARG (keystr))
*+
Display documentation of the command invoked by a key sequence.
+*/
public bool F_describe_key (long uniarg, Lexp *arglist) {
	bool ok = true;
	string name = null, doc, binding = "";

	string? keystr = str_init (ref arglist);
	if (keystr != null) {
		Array<uint?>? keys = keystrtovec (keystr);
		if (keys != null) {
			name = get_function_name (get_function_by_keys (keys));
			binding = keyvectodesc (keys);
        } else
			ok = false;
    } else {
		Minibuf.write ("Describe key:");
		Array<uint?> keys = get_key_sequence ();
		name = get_function_name (get_function_by_keys (keys));
		binding = keyvectodesc (keys);

		if (name == null) {
			Minibuf.error ("%s is undefined", binding);
			ok = false;
        }
    }

	if (ok) {
		Minibuf.write ("%s runs the command `%s'", binding, name);

		doc = get_function_doc (name);
		if (doc == null)
			ok = false;
		else
			write_temp_buffer ("*Help*", true,
							   write_key_description, name, doc, binding);
    }
	return ok;
}
