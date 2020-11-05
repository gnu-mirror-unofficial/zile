# Zile-specific library functions
#
# Copyright (c) 2010-2020 Free Software Foundation, Inc.
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

sub get_bindings {
  my ($file) = @_;
  open IN, "<$file";
  my $bindings = do { local $/ = undef; <IN> };
  return eval $bindings;
}

sub expand_keystrokes {
  my ($doc, $bindings) = @_;
  $doc =~ s/\\\\\[([a-z-]+)\]/@{$bindings->{$1}}[0]/ge;
  return escape_for_C($doc);
}

sub escape_for_C {
  my ($s) = @_;
  $s =~ s/\\/\\\\/g;
  $s =~ s/\n/\\n/g;
  $s =~ s/\"/\\\"/g;
  return $s;
}


1;
