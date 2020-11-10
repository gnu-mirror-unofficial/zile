/* Program invocation, startup and shutdown

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
   along with this program; if not, see <https://www.gnu.org/licenses/>.  */

using Config;

using Posix;
using Gnu;

string program_name;
string ZILE_VERSION_STRING;
string ZILE_COPYRIGHT_STRING;

/* The current buffer; the first buffer in list. */
Buffer cur_bp;
Buffer head_bp;

/* The global editor flags, stored in `thisflag` and `lastflag`. */
public enum Flags {
	NEED_RESYNC,	/* A resync is required. */
	QUIT,			/* The user has asked to quit. */
	SET_UNIARG,		/* The last command modified the
					   universal arg variable `uniarg'. */
	UNIARG_EMPTY,	/* Current universal arg is just C-u's with no number. */
	DEFINING_MACRO, /* We are defining a macro. */
}
int thisflag = 0;
int lastflag = 0;

/* The universal argument repeat count. */
int last_uniarg = 1;

void segv_sig_handler (int signo) {
	Posix.stderr.printf (@"$program_name: $PACKAGE_NAME crashed.  Please send a bug report to " +
						 @"<$PACKAGE_BUGREPORT>.\r\n");
	zile_exit (true);
}

void other_sig_handler (int signo) {
	Posix.stderr.printf (@"$program_name: terminated with signal $signo.\r\n");
	zile_exit (false);
}

void signal_init () {
	/* Set up signal handling */
	Posix.signal (Posix.Signal.SEGV, segv_sig_handler);
	Posix.signal (Posix.Signal.BUS, segv_sig_handler);
	Posix.signal (Posix.Signal.HUP, other_sig_handler);
	Posix.signal (Posix.Signal.INT, other_sig_handler);
	Posix.signal (Posix.Signal.TERM, other_sig_handler);
}

public int main (string[] args)
{
	GLib.Log.set_always_fatal (LEVEL_CRITICAL);
	program_name = Path.get_basename (args[0]);
	init_cmdline ();

	var longopts = new GetoptOption[opts.length];
	for (uint i = 0, nextopt = 0; i < opts.length; i++) {
		var opt = opts[i];
		if (opt is Opt) {
			longopts[nextopt++] = GetoptOption () {
				name = ((Opt) opt).longname,
				has_arg = ((Opt) opt).arg,
				flag = null,
				val = ((Opt) opt).shortname
			};
		}
	}

	ZILE_VERSION_STRING = "GNU " + PACKAGE_NAME + " " + VERSION;
	ZILE_COPYRIGHT_STRING =
	"Copyright (C) 2020 Free Software Foundation, Inc.";

	string splash_str = "\n" +
"Welcome to GNU " + PACKAGE_NAME + ".\n" +
"\n" +
"Undo changes       C-x u        Exit " + PACKAGE_NAME + "         C-x C-c\n" +
"(`C-' means use the CTRL key.  `M-' means hold the Meta (or Alt) key.\n" +
"If you have no Meta key, you may type ESC followed by the character.)\n" +
"Combinations like `C-x u' mean first press `C-x', then `u'.\n" +
"\n" +
"Keys not working properly?  See file://" + PATH_DOCDIR + "/FAQ\n" +
"\n" +
ZILE_VERSION_STRING + "\n" +
ZILE_COPYRIGHT_STRING + "\n" +
"\n" +
"GNU " + PACKAGE_NAME + " comes with ABSOLUTELY NO WARRANTY.\n" +
PACKAGE_NAME + " is Free Software--Free as in Freedom--so you can redistribute copies\n" +
"of " + PACKAGE_NAME + " and modify it; see the file COPYING.  Otherwise, a copy can be\n" +
"downloaded from https://www.gnu.org/licenses/gpl.html.\n";

	/* Set up Lisp environment now so it's available to files and
	   expressions specified on the command-line. */
	lisp_init ();
	init_variables ();
	basic_init ();
	buffer_init_lisp ();
	bind_init ();
	eval_init ();
	file_init ();
	funcs_init ();
	help_init ();
	killring_init ();
	line_init ();
	macro_init ();
	redisplay_init ();
	registers_init ();
	search_init ();
	shell_init ();
	undo_init ();
	variables_init ();
	window_init ();

	bool qflag = false;
	var arg_type = new List<ArgType> ();
	var arg_arg = new List<string> ();
	var arg_line = new List<size_t?> ();
	size_t line = 1;

	opterr = 0; /* Don't display errors for unknown options */
	for (;;) {
		int this_optind = optind != 0 ? optind : 1;
		int longindex = -1;

		/* Leading `-' means process all arguments in order, treating
		   non-options as arguments to an option with code 1 */
		/* Leading `:' so as to return ':' for a missing arg, not '?' */
		int c = getopt_long (args, "-:f:l:q", longopts, out longindex);

		if (c == -1)
			break;
		else if (c == 1)	/* Non-option (assume file name) */
			longindex = 5;
		else if (c == '?')	/* Unknown option */
			Minibuf.error ("Unknown option `%s'", args[this_optind]);
		else if (c == ':') {/* Missing argument */
			Posix.stderr.printf (@"$program_name: Option `$(args[this_optind])' requires an argument\n");
			exit (EXIT_FAILURE);
        } else if (c == 'q')
			longindex = 0;
		else if (c == 'f')
			longindex = 1;
		else if (c == 'l')
			longindex = 2;

		switch (longindex) {
        case 0:
			qflag = true;
			break;
        case 1:
			arg_type.append (ArgType.function);
			arg_arg.append (optarg);
			arg_line.append (0);
			break;
        case 2: {
            arg_type.append (ArgType.loadfile);
            string a = expand_path (optarg);
            arg_arg.append (a);
            arg_line.append (0);
            break;
		}
        case 3:
			printf ("Usage: %s [OPTION-OR-FILENAME]...\n" +
					"\n" +
					"Run " + PACKAGE_NAME + ", the lightweight Emacs clone.\n" +
					"\n",
					args[0]);
			for (uint i = 0; i < opts.length; i++) {
				var opt = opts[i];
				if (opt is Doc)
					print (((Doc) opt).text + "\n");
				else if (opt is Opt) {
					string shortopt = ", -%c".printf (((Opt) opt).shortname);
				    string optstring = "--%s%s %s".printf (
						((Opt) opt).longname,
						((Opt) opt).shortname != 0 ? shortopt : "",
						((Opt) opt).argstring);
					print ("%-24s%s\n", optstring, ((Opt) opt).docstring);
				} else if (opt is Arg) {
					print ("%-24s%s\n", ((Arg) opt).argstring, ((Arg) opt).docstring);
				} else {
					Posix.abort ();
				}
			}
			print ("\n" +
					"Report bugs to " + PACKAGE_BUGREPORT + ".\n");
			exit (EXIT_SUCCESS);
			break;
        case 4:
			print (ZILE_VERSION_STRING + "\n" +
				   ZILE_COPYRIGHT_STRING + "\n" +
				   "GNU " + PACKAGE_NAME + " comes with ABSOLUTELY NO WARRANTY.\n" +
				   "You may redistribute copies of " + PACKAGE_NAME + "\n" +
				   "under the terms of the GNU General Public License.\n" +
				   "For more information about these matters, see the file named COPYING.\n");
			exit (EXIT_SUCCESS);
			break;
        case 5:
			if (optarg[0] == '+')
				long.try_parse (optarg.substring (1), out line, null, 10);
			else {
				arg_type.append (file);
				string a = expand_path (optarg);
				arg_arg.append (a);
				arg_line.append (line);
				line = 1;
            }
			break;
        default:
			break;
        }
    }

	signal_init ();

	Intl.setlocale (ALL, "");

	term_init ();

	/* Create the `*scratch*' buffer, so that initialisation commands
	   that act on a buffer have something to act on. */
	Minibuf.init ();
	create_scratch_window ();
	Buffer scratch_bp = cur_bp;
	bprintf ("%s",
";; This buffer is for notes you don't want to save.\n" +
";; If you want to create a file, visit that file with C-x C-f,\n" +
";; then enter the text in that file's own buffer.\n" +
"\n");
	cur_bp.modified = false;

	init_default_bindings ();

	if (!qflag)
		lisp_loadfile (Path.build_filename (Environment.get_home_dir (), "." + PACKAGE));

	/* Create the splash buffer & message only if no files, function or
	   load file is specified on the command line, and there has been no
	   error. */
	if (arg_arg.length () == 0 && Minibuf.no_error () &&
		!get_variable_bool ("inhibit-splash-screen")) {
		Buffer bp = create_auto_buffer ("*GNU " + PACKAGE_NAME + "*");
		bp.switch_to ();
		bprintf ("%s", splash_str);
		bp.readonly = true;
		funcall ("beginning-of-buffer");
    }

	/* Load files and load files and run functions given on the command
	   line. */
	bool ok = true;
	for (uint i = 0; ok && i < arg_arg.length (); i++) {
		string arg = arg_arg.nth_data (i);

		switch (arg_type.nth_data (i)) {
        case function:
		{
            ok = execute_function (arg, 1, false);
            if (!ok)
				Minibuf.error ("Function `%s' not defined", arg);
            break;
		}
        case loadfile:
			ok = lisp_loadfile (arg);
			if (!ok)
				Minibuf.error ("Cannot open load file: %s\n", arg);
			break;
        case file:
		{
            ok = find_file (arg);
            if (ok)
				funcall ("goto-line", (long) arg_line.nth_data (i));
			break;
		}
        default:
			break;
        }
		if (Flags.QUIT in thisflag)
			break;
    }
	lastflag |= Flags.NEED_RESYNC;

	/* Set up screen according to number of files loaded. */
	Buffer? last_bp = null;
	int files = 0;
	for (Buffer? bp = head_bp; bp != null; bp = bp.next) {
		/* Last buffer that isn't *scratch*. */
		if (bp.next != null && bp.next.next == null)
			last_bp = bp;
		files++;
    }
	if (files == 3) { /* *scratch* and two files. */
		funcall ("split-window");
		last_bp.switch_to ();
		funcall ("other-window");
    } else if (files > 3) /* More than two files. */
		funcall ("list-buffers");

	/* Reinitialise the scratch buffer to catch settings */
	scratch_bp.init ();

	/* Refresh minibuffer in case there was an error that couldn't be
	   written during startup */
	Minibuf.refresh ();

	/* Run the main loop. */
	while (!(Flags.QUIT in thisflag)) {
		if (Flags.NEED_RESYNC in lastflag)
			cur_wp.resync ();
		get_and_run_command ();
    }

	/* Tidy and close the terminal. */
	term_finish ();

	return EXIT_SUCCESS;
}
