# Generate tbl_funcs.h
#
# Copyright (c) 2010-2011 Free Software Foundation, Inc.
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
# along with GNU Zile; see the file COPYING.  If not, write to the
# Free Software Foundation, Fifth Floor, 51 Franklin Street, Boston,
# MA 02111-1301, USA.

use File::Copy;

use Zile;

my %bindings = get_bindings(shift);
my $dir = shift;

open OUT, ">src/tbl_funcs.h" or die;

print OUT <<END;
/*
 * Automatically generated file: DO NOT EDIT!
 * $ENV{PACKAGE_NAME} command to C function bindings and docstrings.
 * Generated from C sources.
 */

END

foreach my $file (@ARGV) {
  open IN, "<$dir/$file" or die;
  while (<IN>) {
    if (/^DEFUN/) {
      /"(.+?)"/;
      my $name = $1;
      die "invalid DEFUN syntax `$_'\n" unless $name;

      my $interactive = !/^DEFUN_NONINTERACTIVE/;
      my $doc = "";
      my $state = 0;
      while (<IN>) {
        if ($state == 1) {
          if (m|^\+\*/|) {
            $state = 0;
            last;
          }
          $doc .= $_;
        } elsif (m|^/\*\+|) {
          $state = 1;
        }
      }

      die "no docstring for $name\n" if $doc eq "";
      die "unterminated docstring for $name\n" if $state == 1;

      my $cname = $name;
      $cname =~ s/-/_/g;
      $doc =~ s/\n/\\n\\\n/g;
      $doc = expand_keystrokes($doc, \%bindings);
      print OUT "X(\"$name\", $cname, " . ($interactive ? "true" : "false") . ", \"\\\n$doc\")\n";
    }
  }
}
