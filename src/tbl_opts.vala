/* Table of command-line options.

   Copyright (c) 2009-2020 Free Software Foundation, Inc.

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

using GetoptLong;

using Config;

public abstract class HelpElement {}

public class Doc : HelpElement {
	public string text;

	public Doc (string text) {
		this.text = text;
	}
}

public enum ArgType {function = 1, loadfile, file}

public class Opt : HelpElement {
	public string longname;
	public char shortname;
	public int arg;
	public string argstring;
	public string docstring;

	public Opt (string longname, char shortname, int arg, string argstring, string docstring) {
		this.longname = longname;
		this.shortname = shortname;
		this.arg = arg;
		this.argstring = argstring;
		this.docstring = docstring;
	}
}

public class Arg : HelpElement {
	public string argstring;
	public string docstring;

	public Arg (string argstring, string docstring) {
		this.argstring = argstring;
		this.docstring = docstring;
	}
}

HelpElement[] opts;

/* Options table
 *
 * Options which take no argument have optional_argument, so that no
 * arguments are signalled as extraneous, as in Emacs.
 */
public void init_cmdline () {
	opts = {
		new Doc ("Initialization options:"),
		new Doc (""),
		new Opt ("no-init-file", 'q', optional, "", "do not load ~/." + PACKAGE),
		new Opt ("funcall", 'f', required, "FUNC", "call " + PACKAGE_NAME + " Lisp function FUNC with no arguments"),
		new Opt ("load", 'l', required, "FILE", "load " + PACKAGE_NAME + " Lisp FILE using the load function"),
		new Opt ("help", '\0', optional, "", "display this help message and exit"),
		new Opt ("version", '\0', optional, "", "display version information and exit"),
		new Doc (""),
		new Doc ("Action options:"),
		new Doc (""),
		new Arg ("FILE", "visit FILE using find-file"),
		new Arg ("+LINE FILE", "visit FILE using find-file, then go to line LINE"),
	};
}
