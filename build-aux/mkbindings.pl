# Generate tbl_bindings.vala
#
# Copyright (c) 2020 Free Software Foundation, Inc.
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

use Zile;

open OUT, ">src/tbl_bindings.vala" or die;
print OUT <<END;
/*
 * Automatically generated file: DO NOT EDIT!
 * $ENV{PACKAGE_NAME} keybindings.
 * Generated from tbl_bindings.pl.
 */

END

my %bindings = get_bindings($ARGV[0]);
print OUT "unowned string default_bindings = \"\"\"";
for my $key (keys %bindings) {
  foreach my $binding (@{$bindings{$key}}) {
    print OUT "(global-set-key \"$binding\" '$key)\n";
  }
}
print OUT "\"\"\";\n";
