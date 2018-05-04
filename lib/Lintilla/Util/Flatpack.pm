package Lintilla::Util::Flatpack;

use strict;
use warnings;

require Exporter;

our @ISA       = qw( Exporter );
our @EXPORT_OK = qw( flatpack unflatpack );

=head1 NAME

Lintilla::Util::Flatpack - Pack array of hashes

=cut

sub flatpack {
  my $ar   = shift;
  my %seen = ();
  my @keys = ();
  my @rows = ();

  for my $row (@$ar) {
    push @keys, grep { !$seen{$_}++ } sort keys %$row;
    push @rows, [@{$row}{@keys}];
  }
  return { keys => \@keys, rows => \@rows };
}

sub unflatpack {
  my $fp   = shift;
  my @keys = @{ $fp->{keys} };
  my @rows = ();

  for my $row ( @{ $fp->{rows} } ) {
    my %h = ();
    @h{@keys} = @$row;
    push @rows, {%h};
  }

  return \@rows;
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
