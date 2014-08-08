package Lintilla::TT::Extensions;

use strict;
use warnings;

use Template::Stash;

=head1 NAME

Lintilla::TT::Extensions - Extension functions for TT

=cut

$Template::Stash::LIST_OPS->{chunk} = sub {
  my ( $list, $slots ) = @_;
  my @in   = @$list;
  my $each = int( @in / $slots );
  my $rem  = @in - ( $each * $slots );
  return [map { [splice @in, 0, $each + ( $rem-- > 0 ? 1 : 0 )] }
     1 .. $slots];
};

$Template::Stash::LIST_OPS->{distribute} = sub {
  my ( $list, $slots ) = @_;
  my @in = @$list;
  my @out = map [], 1 .. $slots;
  while (@in) {
    push @$_, grep defined, shift @in for @out;
  }
  return \@out;
};

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
## Please see file perltidy.ERR
