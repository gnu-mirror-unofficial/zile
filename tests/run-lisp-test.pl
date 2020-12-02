# run-lisp-test
#
# Copyright (c) 2009-2020 Free Software Foundation, Inc.
#
# This file is part of GNU Zile.
#
# GNU Zile is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3, or (at your option)
# any later version.
#
# GNU Zile is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, see <https://www.gnu.org/licenses/>.

use strict;
use warnings;

use File::Basename;
use File::Copy;
use File::Path;


# N.B. Tests that use execute-kbd-macro must note that keyboard input
# is only evaluated once the script has finished running.

# The following are defined in the environment for a build
my $abs_srcdir = $ENV{abs_srcdir} || `pwd`;
chomp $abs_srcdir;
my $srcdir = $ENV{srcdir} || ".";
my $builddir = $ENV{builddir} || ".";
my $editor_name = $ENV{EDITOR_NAME};
my $editor_cmd = $ENV{EDITOR_CMD};

# Compute test filenames
my $test = shift;                       # Name is: ../tests/zile-only/backward_delete_char.el
$test =~ s/\.el$//;			# ../tests/zile-only/backward_delete_char
my $name = $test;
$name =~ s|^\Q$srcdir/tests/||;		# zile-only/backward_delete_char
my $edit_file = "$test.input";
$edit_file =~ s/^\Q$srcdir/$builddir/e;	# ./tests/zile-only/backward_delete_char.input
my $lisp_file = "$test.el";
$lisp_file =~ s/^\Q$srcdir/$abs_srcdir/e;

# Perform the test
mkpath(dirname($edit_file));
my $cmd = "$editor_cmd --no-init-file \"$edit_file\" --load \"$lisp_file\"";
copy("$srcdir/tests/test.input", $edit_file);
chmod 0644, $edit_file;
my $stderr_output = `$cmd 3>&1 1>&2 2>&3 3>&-`; # Swap stderr & stdout https://www.perlmonks.org/?node_id=730
die "$editor_name failed to run test `$name' with error code $?\n" unless $? == 0;
die "$editor_name produced output on stderr:\n$stderr_output\n" if $stderr_output;
system("diff", "$test.output", $edit_file) == 0 or die "$editor_name failed to produce correct output for test `$name'\n";
unlink $edit_file, "$edit_file~";
