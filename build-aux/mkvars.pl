# Produce dotzile.sample
#
# Copyright (c) 2010 Free Software Foundation, Inc.
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

use Zile;

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

# Parse re-usable C headers
sub false { 0; }
sub true { 1; }
my @xarg;
sub X { @xarg = @_; }
my ($D, $O, $A);
$D = $O = $A = \&X;

open IN, "<$ARGV[0]";
while (<IN>) {
  if (/^X \(/) {
    eval $_ or die "Error evaluating:\n$_\n";
    my ($name, $defval, $local_when_set, $doc) = @xarg;

    print OUT "; " . comment_for_lisp($doc) . "\n" .
      "; Default value is $defval.\n" .
        "(setq $name $defval)\n\n";
  }
}
