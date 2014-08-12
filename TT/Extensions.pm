package Lintilla::TT::Extensions;

use strict;
use warnings;

use POSIX qw( strftime );
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

sub _conj_list {
  my ( $conj, @list ) = @_;
  my $last = pop @list;
  return $last unless @list;
  return join " $conj ", join( ', ', @list ), $last;
}

sub _singular_or_plural {
  my ( $conj, $singular, $plural, @list ) = @_;
  return join ' ', $singular, @list if @list < 2;
  return join ' ', $plural, _conj_list( $conj, @list );
}

for my $conj (qw( and or )) {
  $Template::Stash::LIST_OPS->{"${conj}_list"}
   = sub { _conj_list( $conj, @{ $_[0] } ) };
  $Template::Stash::LIST_OPS->{"${conj}_some"}
   = sub { _singular_or_plural( $conj, $_[1], $_[2], @{ $_[0] } ) };
}

$Template::Stash::SCALAR_OPS->{strip_uuid} = sub {
  ( my $uuid = shift ) =~ s/-//g;
  return $uuid;
};

sub _nth {
  my $x = shift;
  $x *= 1;

  return $x    if $x < 0;
  return '0th' if $x == 0;
  return '1st' if $x == 1;
  return '2nd' if $x == 2;
  return '3rd' if $x == 3;

  return int( $x / 10 ) . _nth( $x % 10 )
   if $x >= 20;

  return "${x}th";
}

$Template::Stash::SCALAR_OPS->{long_date} = sub {
  my $ds = shift;
  return $ds unless $ds =~ /^(\d+)-(\d+)-(\d+)/;
  my $pd = strftime "%A, %d %B %Y", 0, 0, 0, $3, $2 - 1, $1 - 1900;
  $pd =~ s/(\d+)/_nth($1)/e;
  return $pd;
};

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
