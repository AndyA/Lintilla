package Lintilla::Filter;

use strict;
use warnings;

use base qw( Exporter );

our @EXPORT_OK = qw( filter cook );

my %FILTER = ();

=head1 NAME

Lintilla::Filter - Named data filters

=cut

sub filter {
  my ( $name, $filt ) = @_;
  push @{ $FILTER{$name} ||= [] }, $filt;
}

sub cook {
  my ( $name, $data ) = @_;
  for my $filt ( @{ $FILTER{$name} || [] } ) {
    $data = $filt->($data);
  }
  return $data;
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
