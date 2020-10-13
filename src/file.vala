/* Disk file handling

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

using Posix;

using Config;
using Lisp;

/*
 * This functions does some corrections and expansions to
 * the passed path:
 *
 * - expands `~/' and `~name/' expressions;
 * - replaces `//' with `/' (restarting from the root directory);
 * - removes `..' and `.' entries.
 *
 * The return value indicates success or failure.
 */
string? expand_path (string path) {
	bool ok = true;
	string epath = "";

	if (path[0] != '/' && path[0] != '~') {
		epath = Environment.get_current_dir ();
		if (epath.length == 0 || epath[epath.length - 1] != '/')
			epath += "/";
    }

	for (uint i = 0; i < path.length;) {
		if (path[i] == '/') {
			if (path[++i] == '/') {
				/* Got `//'.  Restart from this point. */
				while (path[i] == '/')
					i++;
				epath = "";
            }
			if (epath.length == 0 || epath[epath.length - 1] != '/')
				epath += "/";
        } else if (path[i] == '~' && (i == 0 || path[i - 1] == '/')) {
			/* Got `/~' or leading `~'.  Restart from this point. */
			epath = "";
			++i;

			if (path[i] == '/') {
				/* Got `~/'.  Insert the user's home directory. */
				unowned Passwd? pw = getpwuid (getuid ());
				if (pw == null) {
					ok = false;
					break;
                }
				if (pw.pw_dir != "/")
					epath += pw.pw_dir;
            } else {
				/* Got `~something'.  Insert that user's home directory. */
				string a = "";
				while (path[i] != '\0' && path[i] != '/')
					a += path[i++].to_string ();
				unowned Passwd? pw = getpwnam (a);
				if (pw == null) {
					ok = false;
					break;
                }
				epath += pw.pw_dir;
            }
        } else if (path[i] == '.' && (path[i + 1] == '/' || path[i + 1] == '\0')) {
			/* Got `.'. */
			++i;
        } else if (path[i] == '.' && path[i + 1] == '.' && (path[i + 2] == '/' || path[i + 2] == '\0')) {
			/* Got `..'. */
			if (epath.length >= 1 && epath[epath.length - 1] == '/')
				epath = epath.slice (0, -1);
			while (epath[epath.length - 1] != '/' && epath.length >= 1)
				epath = epath.slice (0, -1);
			i += 2;
        }

		if (path[i] != '~')
			while (path[i] != '\0' && path[i] != '/')
				epath += path[i++].to_string ();
    }

	return ok ? epath : null;
}

/*
 * Return a `~/foo' like path if the user is under his home directory,
 * else the unmodified path.
 */
string compact_path (string in_path) {
	string path = in_path;
	unowned Passwd? pw = getpwuid (getuid ());

	if (pw != null) {
		/* Replace `/userhome/' (if found) with `~/'. */
		uint homelen = pw.pw_dir.length;
		if (homelen > 0 && pw.pw_dir[homelen - 1] == '/')
			homelen--;

		if (path.length > homelen &&
			strncmp (pw.pw_dir, path, homelen) == 0 &&
			path[homelen] == '/')
			path = "~/" + path.substring (homelen + 1);
    }

	return path;
}

/* Return true if file exists and can be written. */
bool check_writable (string filename) {
	return euidaccess (filename, W_OK) >= 0;
}

bool find_file (string filename) {
	Buffer? bp;
	for (bp = head_bp; bp != null; bp = bp.next)
		if (bp.filename == filename)
			break;

	if (bp == null) {
		if (FileUtils.test (filename, FileTest.EXISTS) &&
			!FileUtils.test (filename, FileTest.IS_REGULAR)) {
			Minibuf.error ("File exists but could not be read");
			return false;
        } else {
			bp = new Buffer ();
			set_buffer_names (bp, filename);
			bp.dir = Path.get_dirname (filename);

			Estr *es = estr_readf (filename);
			if (es == null)
				es = estr_new (coding_eol_lf);
			else
				bp.readonly = !check_writable (filename);
			bp.text = es;

			/* Reset undo history. */
			bp.next_undop = null;
			bp.last_undop = null;
			bp.modified = false;
        }
    }

	switch_to_buffer (bp);
	thisflag |= Flags.NEED_RESYNC;
	return true;
}

/*
 * Write buffer to given file name with given mode.
 */
ssize_t write_to_disk (Buffer bp, string filename, mode_t mode) {
	int fd = creat (filename, mode);
	if (fd < 0)
		return -1;

	ssize_t ret = 0;
	char *ptr;
	size_t len = buffer_pre_point (bp, out ptr);
	ssize_t written = write (fd, ptr, len);
	if (written < 0 || (size_t) written != len)
		ret = written;
	else {
		len = buffer_post_point (bp, out ptr);
		written = write (fd, ptr, len);
		if (written < 0 || (size_t) written != len)
			ret = written;
	}

	if (close (fd) < 0 && ret == 0)
		ret = -1;

	return ret;
}

/*
 * Create a backup filename according to user specified variables.
 */
string create_backup_filename (string filename, string? backupdir) {
	string res = null;

	/* Prepend the backup directory path to the filename */
	if (backupdir != null) {
		string buf = backupdir;
		if (buf[buf.length - 1] != '/')
			buf += "/";
		for (uint i = 0; i < filename.length; i++)
			if (filename[i] == '/')
				buf += "!";
			else
				buf += filename[i].to_string ();

		res = expand_path (buf);
    }

	if (res == null)
		res = filename;

	return res + "~";
}

/*
 * Write the buffer contents to a file.
 * Create a backup file if specified by the user variables.
 */
bool backup_and_write (Buffer bp, string filename) {
	/* Make backup of original file. */
	int fd = 0;
	bool backup = get_variable_bool ("make-backup-files");
	if (bp.backup && backup && (fd = open (filename, O_RDWR)) != -1) {
		close (fd);

		string backupdir = get_variable_bool ("backup-directory") ?
			get_variable ("backup-directory") : null;
		string bfilename = create_backup_filename (filename, backupdir);
		if (bfilename != null)
			try {
				File.new_for_path (filename).copy (File.new_for_path (bfilename),
												   FileCopyFlags.ALL_METADATA);
				bp.backup = true;
			} catch (Error e) {
				Minibuf.error ("Cannot make backup file: %s", e.message);
				waitkey ();
			}
    }

	ssize_t ret = write_to_disk (bp, filename, S_IRUSR | S_IWUSR |
								 S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH);
	if (ret == 0)
		return true;

	if (ret == -1)
		Minibuf.error ("Error writing `%s': %s", filename, Posix.strerror (errno));
	else
		Minibuf.error ("Error writing `%s'", filename);
	return false;
}

bool write_buffer (Buffer bp, bool needname, bool confirm, string? name0, string prompt) {
	int ans = 1;
	bool ok = true;
	string? name = null;

	if (!needname) {
		GLib.assert (name0 != null);
		name = name0;
	} else {
		name = Minibuf.read_filename ("%s", "", null, prompt);
		if (name == null)
			return funcall ("keyboard-quit");
		if (name.length == 0)
			return false;
		confirm = true;
    }

	if (confirm && FileUtils.test (name, FileTest.EXISTS)) {
		string buf = @"File `$name' exists; overwrite? (y or n) ";
		string errmsg = "";

		for (ans = -2; ans == -2;) {
			Minibuf.write ("%s%s", errmsg, buf);
			uint key = getkeystroke (GETKEY_DEFAULT);
			if (key == 'y' || key == 'Y' || key == ' ' || key == KBD_RET)
				ans = 1;
			else if (key == 'N' || key == 'n' || key == KBD_DEL)
				ans = 0;
			else if (key == (KBD_CTRL | 'g'))
				ans = -1;
			else
				errmsg = "Please answer y or n.  ";
		}

		if (ans == -1)
			funcall ("keyboard-quit");
		else if (ans == 0)
			Minibuf.error ("Canceled");
		if (ans != 1)
			ok = false;
    }

	if (ans == 1) {
		if (bp.filename == null || !(name == bp.filename))
			set_buffer_names (bp, name);
		bp.needname = false;
		bp.temporary = false;
		bp.nosave = false;
		if (backup_and_write (bp, name)) {
			Minibuf.write ("Wrote %s", name);
			bp.modified = false;
			undo_set_unchanged (bp.last_undop);
        } else
			ok = false;
    }

	return ok;
}

bool save_buffer (Buffer bp) {
	if (bp.modified)
		return write_buffer (bp, bp.needname, false, bp.filename, "File to save in: ");

	Minibuf.write ("(No changes need to be saved)");
	return true;
}

/*
 * Function called on unexpected error or Zile crash (SIGSEGV).
 * Attempts to save modified buffers.
 * If doabort is true, aborts to allow core dump generation;
 * otherwise, exit.
 */
public void zile_exit (bool doabort) {
	Posix.stderr.printf ("Trying to save modified buffers (if any)...\r\n");
	for (Buffer? bp = head_bp; bp != null; bp = bp.next)
		if (bp.modified && !bp.nosave) {
			string name = "%s.%sSAVE".printf (get_buffer_filename_or_name (bp), PACKAGE.up ());
			Posix.stderr.printf (@"Saving $name...\r\n");
			write_to_disk (bp, name, S_IRUSR | S_IWUSR);
		}

	if (doabort)
		abort ();
	else
		exit (EXIT_CRASH);
}


public void file_init () {
	new LispFunc (
		"find-file",
		(uniarg, arglist) => {
			bool ok = true;
			string? filename = str_init (ref arglist);
			if (filename == null) {
				filename = Minibuf.read_filename ("Find file: ", cur_bp.dir, null);
				if (filename == null)
					ok = funcall ("keyboard-quit");
			}
			if (filename == null || filename.length == 0)
				ok = false;

			if (ok)
				ok = find_file (filename);

			return ok;
		},
		true,
		"""Edit file FILENAME.
Switch to a buffer visiting file FILENAME,
creating one if none already exists."""
		);

	new LispFunc (
		"find-file-read-only",
		(uniarg, arglist) => {
			bool ok = LispFunc.find ("find-file").func (uniarg, arglist);
			if (ok)
				cur_bp.readonly = true;
			return ok;
		},
		true,
		"""Edit file FILENAME but don't allow changes.
Like `find-file', but marks buffer as read-only.
Use M-x toggle-read-only to permit editing."""
		);

	new LispFunc (
		"find-alternate-file",
		(uniarg, arglist) => {
			string buf = cur_bp.filename;
			string basename = null;

			if (buf == null)
				buf = cur_bp.dir;
			else
				basename = Path.get_basename (buf);
			string? ms = Minibuf.read_filename ("Find alternate: ", buf, basename);

			bool ok = false;
			if (ms == null)
				ok = funcall ("keyboard-quit");
			else if (ms.length > 0 && check_modified_buffer (cur_bp)) {
				kill_buffer (cur_bp);
				ok = find_file (ms);
			}
			return ok;
		},
		true,
		"""Find the file specified by the user, select its buffer, kill previous buffer.
If the current buffer now contains an empty file that you just visited
(presumably by mistake), use this command to visit the file you really want."""
		);

	new LispFunc (
		"switch-to-buffer",
		(uniarg, arglist) => {
			Buffer? bp = ((cur_bp.next != null) ? cur_bp.next : head_bp);

			bool ok = true;
			string? buf = str_init (ref arglist);
			if (buf == null) {
				Completion cp = make_buffer_completion ();
				buf = Minibuf.read_completion ("Switch to buffer (default %s): ",
											   "", cp, null, bp.name);

				if (buf == null)
					ok = funcall ("keyboard-quit");
			}
			if (buf == null)
				ok = false;

			if (ok) {
				if (buf != null && buf.length > 0) {
					bp = find_buffer (buf);
					if (bp == null) {
						bp = new Buffer ();
						bp.name = buf;
						bp.needname = true;
						bp.nosave = true;
					}
				}

				switch_to_buffer (bp);
			}

			return ok;
		},
		true,
		"""Select buffer BUFFER in the current window."""
		);

	new LispFunc (
		"insert-buffer",
		(uniarg, arglist) => {
			Buffer? def_bp = ((cur_bp.next != null) ? cur_bp.next : head_bp);

			if (warn_if_readonly_buffer ())
				return false;

			bool ok = true;
			string buf = str_init (ref arglist);
			if (buf == null) {
				Completion *cp = make_buffer_completion ();
				buf = Minibuf.read_completion ("Insert buffer (default %s): ",
											   "", cp, null, def_bp.name);
				if (buf == null)
					ok = funcall ("keyboard-quit");
			}
			if (buf == null)
				ok = false;

			if (ok) {
				Buffer? bp;

				if (buf != null && buf.length > 0) {
					bp = find_buffer (buf);
					if (bp == null) {
						Minibuf.error ("Buffer `%s' not found", buf);
						ok = false;
					}
				} else
					bp = def_bp;

				if (ok) {
					insert_buffer (bp);
					funcall ("set-mark-command");
				}
			}

			return ok;
		},
		true,
		"""Insert after point the contents of BUFFER.
Puts mark after the inserted text."""
		);

	new LispFunc (
		"insert-file",
		(uniarg, arglist) => {
			if (warn_if_readonly_buffer ())
				return false;

			bool ok = true;
			string? file = str_init (ref arglist);
			if (file == null) {
				file = Minibuf.read_filename ("Insert file: ", cur_bp.dir, null);
				if (file == null)
					ok = funcall ("keyboard-quit");
			}

			if (file == null || file.length == 0)
				ok = false;

			if (ok) {
				Estr *es = estr_readf (file);
				if (es != null) {
					insert_estr (es);
					funcall ("set-mark-command");
				} else {
					ok = false;
					Minibuf.error ("%s: %s", file, Posix.strerror (errno));
				}
			}
			return ok;
		},
		true,
		"""Insert contents of file FILENAME into buffer after point.
Set mark after the inserted text."""
		);

	new LispFunc (
		"save-buffer",
		(uniarg, arglist) => {
			return save_buffer (cur_bp);
		},
		true,
		"""Save current buffer in visited file if modified.  By default, makes the
previous version into a backup file if this is the first save."""
		);

	new LispFunc (
		"write-file",
		(uniarg, arglist) => {
			return write_buffer (cur_bp, true,
								 arglist != null && !(Flags.SET_UNIARG in lastflag),
								 null, "Write file: ");
		},
		true,
		"""Write current buffer into file FILENAME.
This makes the buffer visit that file, and marks it as not modified.

Interactively, confirmation is required unless you supply a prefix argument."""
		);

	new LispFunc (
		"save-some-buffers",
		(uniarg, arglist) => {
			bool noask = false;

			for (Buffer? bp = head_bp; bp != null; (bp = bp.next) != null) {
				if (bp.modified && !bp.nosave) {
					string fname = get_buffer_filename_or_name (bp);
					if (noask)
						save_buffer (bp);
					else
						for (;;) {
							Minibuf.write ("Save file %s? (y, n, !, ., q) ", fname);
							uint c = getkey (GETKEY_DEFAULT);
							Minibuf.clear ();

							if (c == KBD_CANCEL) {	/* C-g */
								funcall ("keyboard-quit");
								return false;
							} else if (c == 'q') {
								return true;
							} else if (c == '.') {
								save_buffer (bp);
								return true;
							} else if (c == '!') {
								noask = true;
								save_buffer (bp);
								break;
							} else if (c == ' ' || c == 'y') {
								save_buffer (bp);
								break;
							} else if (c == 'n' || c == KBD_RET || c == KBD_DEL)
								break;
							else {
								Minibuf.error ("Please answer y, n, !, . or q.");
								waitkey ();
							}
						}
				}
			}

			Minibuf.write ("(No files need saving)");
			return true;
		},
		true,
		"""Save some modified file-visiting buffers.  Asks user about each one."""
		);

	new LispFunc (
		"save-buffers-kill-emacs",
		(uniarg, arglist) => {
			if (!funcall ("save-some-buffers"))
				return false;

			for (Buffer? bp = head_bp; bp != null; bp = bp.next)
				if (bp.modified && !bp.needname) {
					for (;;) {
						int ans = Minibuf.read_yesno ("Modified buffers exist; exit anyway? (yes or no) ");
						if (ans == -1)
							return funcall ("keyboard-quit");
						else if (ans == 0)
							return false;
						break;
					}
					break; /* We have found a modified buffer, so stop. */
				}

			thisflag |= Flags.QUIT;
			return true;
		},
		true,
		"""Offer to save each buffer, then kill this Zile process."""
		);

	new LispFunc (
		"cd",
		(uniarg, arglist) => {
			bool ok = true;
			string? dir = str_init (ref arglist);
			if (arglist == leNIL)
				dir = Minibuf.read_filename ("Change default directory: ", cur_bp.dir, null);

			if (dir == null)
				ok = funcall ("keyboard-quit");
			else if (dir.length > 0) {
				if (!FileUtils.test (dir, IS_DIR)) {
					Minibuf.error ("`%s' is not a directory", dir);
					ok = false;
				} else if (chdir (dir) == -1) {
					Minibuf.write ("%s: %s", dir, Posix.strerror (errno));
					ok = false;
				}
			}
			return true;
		},
		true,
		"""Make DIR become the current buffer's default directory."""
		);
}
