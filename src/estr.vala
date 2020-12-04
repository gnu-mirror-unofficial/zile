/* Dynamically-allocated strings with line ending encoding.

   Copyright (c) 2011-2020 Free Software Foundation, Inc.

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

public class ImmutableEstr {
	/*
	 * String positions start at zero, as with ordinary C strings.
	 *
	 * Strings may contain NULs, but always have a terminating NUL, so treating
	 * them as NUL-terminated will not result in buffer overflows.
	 */
	public char *text { public get; protected set; } /* The string buffer. */
	public size_t length { public get; protected set; } /* The length of the string. */
	public string eol { public get; protected set; } /* EOL type. */

	/* End-of-line types. */
	public const string eol_lf = "\n";
	public const string eol_crlf = "\r\n";
	public const string eol_cr = "\r";

	public static ImmutableEstr empty;
	static construct {
		empty = ImmutableEstr.of ("", 0);
	}

	/*
	 * Make a new constant string from a counted C string.
	 */
	public static ImmutableEstr of (string text, size_t length, string eol=eol_lf) {
		var es = new ImmutableEstr ();
		es.text = text;
		es.length = length;
		es.eol = eol;
		return es;
	}

	public ImmutableEstr substring (size_t pos, size_t length) {
		var es = new ImmutableEstr ();
		es.text = text + pos;
		es.length = length;
		es.eol = eol;
		return es;
	}

	public size_t prev_line (size_t o) {
		size_t so = start_of_line (o);
		return (so == 0) ? size_t.MAX : start_of_line (so - eol.length);
	}

	public size_t next_line (size_t o) {
		size_t eo = end_of_line (o);
		return (eo == length) ? size_t.MAX : eo + eol.length;
	}

	public size_t start_of_line (size_t o) {
		char *prev = memrmem ((string) text, (ssize_t) o, eol, eol.length);
		return prev != null ? prev - text + eol.length : 0;
	}

	public size_t end_of_line (size_t o) {
		char *next = Gnu.memmem ((string) (text + o), (ssize_t) (length - o), eol, eol.length);
		return next != null ? (size_t) (next - text) : length;
	}

	public size_t lines () {
		char *s = text;
		char *next = null;
		size_t lines = 0;
		for (size_t len = length;
			 (next = Gnu.memmem ((string) s, (ssize_t) len, eol, eol.length)) != null;
			 len -= (size_t) (next - s) + eol.length, s = next + eol.length)
			lines++;
		return lines;
	}

	/*
	 * Return the length in bytes if the newlines were replaced with
	 * `eol_type`.
	 */
	public size_t len_with_eol (string eol_type) {
		return length + lines () * (eol_type.length - eol.length);
	}
}

public class Estr : ImmutableEstr {
	protected const int ALLOCATION_CHUNK_SIZE = 16;
	size_t buf_size;

	/* Prevent constructor being called outside class. */
	private Estr () { }

	/*
	 * Allocate a new string with zero length.
	 */
	public static Estr of_empty (string eol=eol_lf) {
		var es = new Estr ();
		es.buf_size = ALLOCATION_CHUNK_SIZE;
		es.length = 0;
		es.text = malloc0 (es.buf_size + 1);
		es.eol = eol;
		return es;
	}

	public static Estr copy (ImmutableEstr ies) {
		var es = of_empty ();
		es.cat (ies);
		return es;
	}

	~Estr () {
		free (text);
	}

	public void set_char (size_t pos, char c) {
		text[pos] = c;
	}

	/*
	 * Change the length of an estr, possibly reallocating it if it needs to
	 * grow, or has shrunk considerably.
	 */
	void resize (size_t length) {
		if (length > buf_size || length < buf_size / 2) {
			buf_size = length + ALLOCATION_CHUNK_SIZE;
			text = realloc (text, buf_size + 1);
		}
		this.length = length;
		text[length] = '\0';
	}

	/* Maximum number of EOLs to check before deciding type. */
	public void set_eol_from_text () {
		const int MAX_EOL_CHECK_COUNT = 3;
		bool first_eol = true;
		size_t total_eols = 0;
		for (size_t i = 0; i < length && total_eols < MAX_EOL_CHECK_COUNT; i++) {
			char c = text[i];
			if (c == '\n' || c == '\r') {
				string this_eol_type;
				total_eols++;
				if (c == '\n')
					this_eol_type = eol_lf;
				else if (i == length - 1 || text[i + 1] != '\n')
					this_eol_type = eol_cr;
				else {
					this_eol_type = eol_crlf;
					i++;
				}

				if (first_eol) {
					/* This is the first end-of-line. */
					eol = this_eol_type;
					first_eol = false;
				} else if (eol != this_eol_type) {
					/* This EOL is different from the last; arbitrarily choose LF. */
					eol = eol_lf;
					break;
				}
			}
		}
	}

	/*
	 * Overwrite characters starting at `pos', with the argument string.
	 */
	public void replace (size_t pos, ImmutableEstr src) {
		char *s = src.text;
		for (size_t len = src.length; len > 0;) {
			char *next = Gnu.memmem ((string) s, (ssize_t) len, src.eol, src.eol.length);
			size_t line_len = next != null ? (size_t) (next - s) : len;
			Memory.move (text + pos, s, line_len);
			pos += line_len;
			len -= line_len;
			s = next;
			if (len > 0) {
				Memory.move (text + pos, eol, eol.length);
				s += src.eol.length;
				len -= src.eol.length;
				pos += eol.length;
			}
		}
	}

	public void cat (ImmutableEstr src) {
		size_t oldlen = length;
		insert (oldlen, src.len_with_eol (eol));
		replace (oldlen, src);
	}

	/*
	 * Remove `size' chars from `es' at position `pos'.
	 */
	public void remove (size_t pos, size_t size) {
		assert (pos <= length);
		assert (size <= length - pos);
		Memory.move (text + pos, text + pos + size, length - (pos + size));
		resize (length - size);
	}

	/*
	 * Insert gap of `size' characters in `es' at position `pos'.
	 */
	public void insert (size_t pos, size_t size) {
		assert (pos <= length);
		assert (pos + size >= size_t.max (pos, size));    /* Check for overflow. */
		resize (length + size);
		Memory.move (text + pos + size, text + pos, length - (pos + size));
		Memory.set (text + pos, '\0', size);
	}

	public void move (size_t to, size_t from, size_t n) {
		assert (to <= length);
		assert (from <= length);
		assert (n <= length - size_t.max (from, to));
		Memory.move (text + to, text + from, n);
	}

	public void set (size_t pos, int c, size_t n) {
		assert (pos <= length);
		assert (n <= length - pos);
		Memory.set (text + pos, c, n);
	}

	public static Estr from_file (string filename) throws Error {
		string s;
		FileUtils.get_contents (filename, out s);
		var es = new Estr ();
		es.length = s.length;
		es.text = (owned) s;
		es.set_eol_from_text ();
		return es;
	}
}
