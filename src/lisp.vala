/* "Lisp" "interpreter".

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
   along with this program; if not, see <https://www.gnu.org/licenses/>.  */

using Gee;

errordomain ParseError { EOF, UNCLOSED_QUOTE }

public class Lexp {
	/* A Lexp is either an atom or a list, and may be quoted.
	   N.B. This is not the same as in Lisp (car and cdr). */
	public bool quoted;
	public string atom;
	public Gee.List<Lexp>? list;

	public Lexp (string? text=null) {
		if (text != null)
			this.atom = text;
		else
			this.list = new ArrayList<Lexp> ();
	}

	public bool eval () {
		if (atom != null) /* Don't evaluate atoms. */
			return false;

		Gee.Queue<string>? args = null;
		if (list != null) {
			args = new ArrayQueue<string> ();
			args.add_all_iterator (list.map<string> ((l) => { return l.atom; }));
		}

		LispFunc? func = LispFunc.find (args.poll ());
		if (func != null)
			return call_command (func, 1, args);
		return false;
	}

	public static void eval_list (Gee.List<Lexp> list) {
		foreach (Lexp l in list)
			l.eval ();
	}


	/* Sexp parser. */

	enum TokenType {
		closeparen,
		openparen,
		quote,
		word,
	}

	static char read_char (string a, ref uint pos) throws ParseError {
		if (pos >= a.length)
			throw new ParseError.EOF ("EOF");
		return a[pos++];
	}

	static TokenType read_token (string a, ref uint pos, out string tok)
			throws ParseError {
		/* Chew space to next token */
		char c = 0;
		do {
			c = read_char (a, ref pos);

			/* Munch comments */
			if (c == ';')
				do
					c = read_char (a, ref pos);
				while (c != '\n');
		} while (c.isspace ());

		/* Snag token */
		tok = "";
		if (c == '(')
			return TokenType.openparen;
		else if (c == ')')
			return TokenType.closeparen;
		else if (c == '\'')
			return TokenType.quote;

		/* It looks like a symbol or string. */
		bool doublequotes = false;
		if (c == '\"') {
			doublequotes = true;
			c = read_char (a, ref pos);
		}

		for (;; c = read_char (a, ref pos)) {
			tok += ((char) c).to_string ();

			if (!doublequotes) {
				if (c == ')' || c == '(' || c == ';' || c.isspace ()) {
					pos--;
					tok = tok.slice (0, -1);
					return TokenType.word;
				}
			} else {
				if (c == '\n' || c == '\r')
					throw new ParseError.UNCLOSED_QUOTE ("EOL");
				if (c == '\"') {
					tok = tok.slice (0, -1);
					return TokenType.word;
				}
			}
		}
	}

	static Lexp read_sexp (string a, ref uint pos, out TokenType tokenid)
			throws ParseError {
		string tok;
		tokenid = read_token (a, ref pos, out tok);
		var sexp = new Lexp ();

		if (tokenid == TokenType.quote) {
			sexp.quoted = true;
			tokenid = read_token (a, ref pos, out tok);
		}

		switch (tokenid) {
		case TokenType.openparen:
			sexp.list = read_list (a, ref pos);
			break;

		case TokenType.word:
			sexp.atom = tok;
			break;

		case TokenType.closeparen:
			break;

		default:
			break;
		}

		return sexp;
	}

	public static Gee.List<Lexp>? read_list (string a, ref uint pos) {
		Gee.List<Lexp> list = new ArrayList<Lexp> ();
		try {
			while (true) {
				TokenType tokenid;
				Lexp sexp = read_sexp (a, ref pos, out tokenid);
				if (tokenid == closeparen)
					break;
				list.add (sexp);
			}
		} catch (ParseError e) {
			if (!(e is ParseError.EOF))
				list = null;
		}
		return list;
	}
}


/* Calling Lisp functions. */

[CCode(has_target=false)]
public delegate bool Function (long uniarg, Gee.Queue<string>? args);

public bool funcall (string name, long? maybe_uniarg=null, Gee.Queue<string>? args=null) {
	/* FIXME: This code is a bit long-winded, to work around
	 * https://gitlab.gnome.org/GNOME/vala/-/issues/1084
	 */
	long uniarg;
	Gee.Queue<string>? args_ = args;
	if (maybe_uniarg == null) {
		uniarg = 1;
		args_ = new ArrayQueue<string> ();
	} else
		uniarg = maybe_uniarg;
	return LispFunc.find (name).func (uniarg, args_);
}

public bool noarg (Gee.Queue<string>? args) {
	return !(Flags.SET_UNIARG in lastflag) && (args != null && args.size == 0);
}

public bool bool_arg (Gee.Queue<string>? args, out bool val) {
	val = false;
	if (args != null && args.size > 0) {
		string s = args.poll ();
		val = !(s != null && s == "nil");
		return true;
	}
	return false;
}

public long? parse_number (string? s) {
	if (s == null)
		return null;
	long res;
	if (long.try_parse (s, out res, null, 10))
		return res;
	return null;
}

public bool int_arg (Gee.Queue<string>? args, out long n) {
	n = 0;
	if (args == null || args.size == 0)
		return false;
	string? s = args.poll ();
	if (s == null)
		return false;
	return long.try_parse (s, out n, null, 10);
}

public bool int_or_uniarg (Gee.Queue<string>? args, ref long n, long uniarg) {
	if (args != null && args.size > 0) {
		long? num = parse_number (args.poll ());
		if (num != null)
			n = num;
		return num != null;
	}
	n = uniarg;
	return true;
}


/* Loading Lisp. */

void lisp_loadstring (string a) {
	uint pos = 0;
	var list = Lexp.read_list (a, ref pos);
	if (list != null)
		Lexp.eval_list (list);
}

bool lisp_loadfile (string file) {
	string s;
	try {
		FileUtils.get_contents (file, out s);
	} catch {
		return false;
	}
	lisp_loadstring (s);
	return true;
}


public void lisp_init () {
	new LispFunc (
		"load",
		(uniarg, args) => {
			return args != null && !args.is_empty && lisp_loadfile (args.poll ());
		},
		true,
		"""Execute a file of Lisp code named FILE."""
		);
}
