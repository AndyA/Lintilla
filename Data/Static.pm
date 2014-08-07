package Lintilla::Data::Static;

use Moose;
use JSON;
use Path::Class;

=head1 NAME

Lintilla::Data::Static - Static JSON backed data

=cut

has store => ( is => 'ro', required => 1 );

sub get {
  my ( $self, $key ) = @_;
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
