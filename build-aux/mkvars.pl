# Produce dotzile.sample
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

# Don't note where the contents of this file comes from or that it's
# auto-generated, because it's ugly in a user configuration file.
open OUT, ">src/dotzile.sample" or die;
print OUT <<EOF;
;;;; .$ENV{PACKAGE} configuration

;; Rebind keys with:
;; (global-set-key "key" 'func)

EOF

sub comment_for_lisp {
  my ($s) = @_;
  $s =~ s/\n/\n; /g;
  return $s;
}

# Parse tbl_vars.vala
sub false { 0; }
sub true { 1; }
my @varg;
sub init_builtin_var { @varg = @_; }

open IN, "<$ARGV[0]";
while (<IN>) {
  if (/init_builtin_var \(/) {
    eval $_ or die "Error evaluating:\n$_\n";
    my ($name, $defval, $local_when_set, $doc) = @varg;

    print OUT "; " . comment_for_lisp($doc) . "\n" .
      "; Default value is $defval.\n" .
        "(setq $name $defval)\n\n";
  }
}
