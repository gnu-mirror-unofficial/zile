/* Lisp parser

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

public class Lexp {
	/* either data or a branch */
	public Lexp *branch;
	public string data;
	public int quoted;

	/* for the next in the list in the current parenlevel */
	public Lexp *next;

	public Lexp (string? text) {
		if (text != null)
			this.data = text;
	}
}

namespace Lisp {
	[CCode(has_target=false)]
	public delegate bool Function (long uniarg, Lexp *list);

	public bool funcall (string name) {
		return LispFunc.find (name).func (1, leNIL);
	}

	public bool funcall_arg (string name, long uniarg) {
		return LispFunc.find (name).func (uniarg, null);
	}

	public string str_init (ref Lexp *arglist) {
		string? name = null;
		if (arglist != null && arglist->next != null) {
			if (arglist->next->data != null)
				name = arglist->next->data;
			arglist = arglist->next;
		}
		return name;
	}

	public bool bool_init (ref Lexp *arglist, out bool value) {
		value = false;
		if (arglist != null && arglist->next != null) {
			string s = arglist->next->data;
			arglist = arglist->next;
			value = !(s != null && s == "nil");
			return true;
		}
		return false;
	}

	public bool int_init (ref Lexp *arglist, ref long n) {
		if (arglist == null || arglist->next == null)
			return false;
		string? s = arglist->next->data;
		if (s == null)
			return false;
		arglist = arglist->next;
		return long.try_parse (s, out n, null, 10);
	}

	public bool int_or_uniarg_init (ref Lexp *arglist, ref long n, long uniarg) {
		if (arglist != null && arglist->next != null)
			return int_init(ref arglist, ref n);
		n = uniarg;
		return true;
	}

	public bool noarg (Lexp *arglist) {
		return !(Flags.SET_UNIARG in lastflag) && (arglist == leNIL || (arglist != null && arglist->next == null));
	}
}


enum TokenName {
	eof,
	closeparen,
	openparen,
	newline,
	quote,
	word,
}

int read_char (string a, ref uint pos) {
	if (pos < a.length)
		return a[pos++];
	return FileStream.EOF;
}

string read_token (out TokenName tokenid, string a, ref uint pos) {
	int c = 0;
	bool doublequotes = false;
	string tok = "";

	tokenid = TokenName.eof;

	/* Chew space to next token */
	do {
		c = read_char (a, ref pos);

		/* Munch comments */
		if (c == ';')
			do
				c = read_char (a, ref pos);
			while (c != FileStream.EOF && c != '\n');
	}
	while (c != FileStream.EOF && (c == ' ' || c == '\t'));

	/* Snag token */
	if (c == '(') {
		tokenid = TokenName.openparen;
		return tok;
	} else if (c == ')') {
		tokenid = TokenName.closeparen;
		return tok;
	} else if (c == '\'') {
		tokenid = TokenName.quote;
		return tok;
	} else if (c == '\n') {
		tokenid = TokenName.newline;
		return tok;
	} else if (c == FileStream.EOF) {
		tokenid = TokenName.eof;
		return tok;
	}

	/* It looks like a string. Snag to the next whitespace. */
	if (c == '\"') {
		doublequotes = true;
		c = read_char (a, ref pos);
	}

	for (;; c = read_char (a, ref pos)) {
		tok += ((char) c).to_string ();

		if (!doublequotes) {
			if (c == ')' || c == '(' || c == ';' || c == ' ' || c == '\n'
				|| c == '\r' || c == FileStream.EOF) {
				pos--;
				tok = tok.slice (0, -1);
				tokenid = TokenName.word;
				return tok;
			}
		} else {
			bool eol = false;
			if (c == '\n' || c == '\r' || c == FileStream.EOF) {
				pos--;
				eol = true;
			}
			if (eol || c == '\"') {
				tok = tok.slice (0, -1);
				tokenid = TokenName.word;
				return tok;
			}
		}
	}
}

Lexp *lisp_read (Lexp *list, string a, ref uint pos) {
	bool quoted = false;

	for (;;) {
		TokenName tokenid;
		string tok = read_token (out tokenid, a, ref pos);

		switch (tokenid) {
		case TokenName.quote:
			quoted = true;
			break;

		case TokenName.openparen:
			list = leAddBranchElement (list, lisp_read (null, a, ref pos), quoted ? 1 : 0);
			quoted = false;
			break;

		case TokenName.newline:
			quoted = false;
			break;

		case TokenName.word:
			list = leAddDataElement (list, tok, quoted ? 1 : 0);
			quoted = false;
			break;

		case TokenName.closeparen:
			return list;

		case TokenName.eof:
			return list;

		default:
			break;
		}
	}
}

void lisp_loadstring (string a) {
	uint pos = 0;
	leEval (lisp_read (null, a, ref pos));
}

bool lisp_loadfile (string file) {
	Astr *a = Astr.readf (file);
	if (a == null)
		return false;
	lisp_loadstring (a.cstr ());
	return true;
}

public bool lisp_to_number (string? s, out long res) {
	res = 0;
	if (s == null)
		return false;
	return long.try_parse (s, out res, null, 10);
}


public void lisp_init () {
	leNIL = new Lexp ("nil");
	leT = new Lexp ("t");

	new LispFunc (
		"load",
		(uniarg, arglist) => {
			return arglist != null && countNodes (arglist) >= 2 &&
			lisp_loadfile (arglist->next->data);
		},
		true,
		"""Execute a file of Lisp code named FILE."""
		);
}
