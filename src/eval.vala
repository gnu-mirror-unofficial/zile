/* Lisp eval

   Copyright (c) 2001-2020 Free Software Foundation, Inc.

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

[CCode (has_target=false)]
public delegate bool MovementDelegate ();
[CCode (has_target=false)]
public delegate bool MovementNDelegate (long uniarg);

/*
 * Zile Lisp functions.
 */
struct Fentry {
	string name;		/* The function name. */
	void * func;		/* The function pointer. */
	bool interactive;	/* Whether function can be used interactively. */
	string doc;			/* Documentation string. */
}

Fentry? get_fentry (string name) {
	foreach (Fentry f in fentry_table) {
		if (name == f.name)
			return f;
	}
	return null;
}

Function get_function (string name) {
	Fentry? f = get_fentry (name);
	return f != null ? (Function) f.func : null;
}

/* Return function's interactive flag, or -1 if not found. */
int get_function_interactive (string name) {
	Fentry? f = get_fentry (name);
	return f != null ? (int) f.interactive : -1;
}

string get_function_doc (string name) {
	Fentry? f = get_fentry (name);
	return f != null ? f.doc : null;
}

string? get_function_name (Function p) {
	foreach (Fentry f in fentry_table)
		if ((Function) f.func == p)
			return f.name;
	return null;
}


public Lexp *leNIL;
public Lexp *leT;

size_t countNodes (Lexp *branch) {
	int count;
	for (count = 0; branch != null; branch = branch->next, count++)
		;
	return count;
}

Lexp *evaluateBranch (Lexp * trybranch) {
	if (trybranch == null)
		return null;

	Lexp *keyword;
	if (trybranch->branch != null)
		keyword = evaluateBranch (trybranch->branch);
	else
		keyword = new Lexp (trybranch->data);

	if (keyword->data == null)
		return leNIL;

	Fentry? func = get_fentry (keyword->data);
	if (func != null)
		return call_command ((Function) func.func, 1, trybranch) ? leT : leNIL;

	return null;
}

Lexp *evaluateNode (Lexp * node) {
	Lexp *value;

	if (node == null)
		return leNIL;

	if (node->branch != null) {
		if (node->quoted != 0)
			value = leDup (node->branch);
		else
			value = evaluateBranch (node->branch);
    } else {
		string? s = get_variable (node->data);
		value = new Lexp (s != null ? s : node->data);
    }

	return value;
}

/*
DEFUN_NONINTERACTIVE ("setq", setq)
*+
(setq [sym val]...)

Set each sym to the value of its val.
The symbols sym are variables; they are literal (not evaluated).
The values val are expressions; they are evaluated.
+*/
public bool F_setq (long uniarg, Lexp *arglist) {
	if (arglist != null && countNodes (arglist) >= 2) {
		for (Lexp *current = arglist->next; current != null; current = current->next->next) {
			set_variable (current->data, evaluateNode (current->next)->data);
			if (current->next == null)
				break; /* Cope with odd-length argument lists. */
        }
    }
	return true;
}

public void leEval (Lexp *list) {
	for (; list != null; list = list->next)
		evaluateBranch (list->branch);
}

public bool execute_with_uniarg (long uniarg, MovementDelegate forward, MovementDelegate? backward) {
	if (backward != null && uniarg < 0) {
		forward = backward;
		uniarg = -uniarg;
    }
	bool ret = true;
	for (int uni = 0; ret && uni < uniarg; ++uni)
		ret = forward ();

	return ret;
}

public bool move_with_uniarg (long uniarg, MovementNDelegate move) {
	bool ret = true;
	for (ulong uni = 0; ret && uni < (ulong) uniarg.abs (); ++uni)
		ret = move (uniarg < 0 ? - 1 : 1);
	return ret;
}

bool execute_function (string name, long uniarg, bool is_uniarg) {
	Function func = get_function (name);
	return func != null ? call_command (func, uniarg, is_uniarg ? null : leNIL) : false;
}

/*
DEFUN ("execute-extended-command", execute_extended_command)
*+
Read function name, then read its arguments and call it.
+*/
public bool F_execute_extended_command (long uniarg, Lexp *arglist) {
	string msg = "";

	if (Flags.SET_UNIARG in lastflag) {
		if (Flags.UNIARG_EMPTY in lastflag)
			msg = "C-u ";
		else
			msg = @"$uniarg ";
    }
	msg += "M-x ";

	string? name = minibuf_read_function_name ("%s", msg);
	if (name == null)
		return false;

	return execute_function (name, uniarg, Flags.SET_UNIARG in lastflag);
}

/*
 * Read a function name from the minibuffer.
 */
History *functions_history = null;
string? minibuf_read_function_name (string fmt, ...) {
	Completion cp = new Completion (false);

	for (size_t i = 0; i < fentry_table.length; ++i)
		if (fentry_table[i].interactive)
			cp.completions.append (fentry_table[i].name);
	cp.completions.sort (strcmp); // FIXME: Move this inside Completion

	return Minibuf.vread_completion (fmt, "", cp, functions_history,
									 "No function name given",
									 Minibuf.test_in_completions,
									 "Undefined function name `%s'", va_list());
}

public void init_eval () {
	functions_history = new History ();
}
