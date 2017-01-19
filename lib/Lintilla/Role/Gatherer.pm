package Lintilla::Role::Gatherer;

use Moose::Role;

=head1 NAME

Lintilla::Role::Gatherer - Gather properties

=cut

sub gather {
  my ( $self, @keys ) = @_;
  return map { $_ => $self->$_() } @keys;
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
