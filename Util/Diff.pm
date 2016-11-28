package Lintilla::Util::Diff;

use strict;
use warnings;

use JSON ();
use List::Util qw( max );

require Exporter;

our @ISA       = qw( Exporter );
our @EXPORT_OK = qw( deep_diff same );

=head1 NAME

Lintilla::Util::Diff - Deep datastructure diff

=cut

sub deep_diff {
  my ( $a, $b, $tag_a, $tag_b ) = @_;
  return if same( $a, $b );

  $tag_a //= "a";
  $tag_b //= "b";

  unless ( ref $a && ref $b ) {
    return unless defined $a || defined $b;

    return { $tag_a => $a, $tag_b => $b }
     if !defined $a
     || !defined $b
     || ref $a
     || ref $b
     || $a ne $b;

    return;
  }

  return { $tag_a => $a, $tag_b => $b }
   unless ref $a eq ref $b;

  if ( "ARRAY" eq ref $a ) {
    my $lim = max $#$a, $#$b;
    my @out = ();
    for my $idx ( 0 .. $lim ) {
      my $diff = deep_diff( $a->[$idx], $b->[$idx], $tag_a, $tag_b );
      push @out, $diff;
    }
    return \@out;
  }

  if ( "HASH" eq ref $a ) {
    my %keys = map { $_ => 1 } keys %$a;
    $keys{$_}++ for keys %$b;
    my %out = ();
    for my $key ( keys %keys ) {
      my $diff = deep_diff( $a->{$key}, $b->{$key}, $tag_a, $tag_b );
      $out{$key} = $diff if defined $diff;
    }
    return \%out;
  }

  die "Can't compare ", ref $a;
}

sub same {
  my ( $a, $b ) = @_;
  return 1 unless defined $a || defined $b;
  return 0 unless defined $a && defined $b;
  my $json = JSON->new->utf8->allow_nonref->canonical;
  return $json->encode($a) eq $json->encode($b);
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
