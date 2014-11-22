package Lintilla::Role::Source;

use Moose::Role;

=head1 NAME

Lintilla::Role::Source - Source attribute

=cut

has source => (
  is       => 'ro',
  required => 1,
  default  => '70ba6e0c-c493-42bd-8c64-c9f4be994f6d',
);

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
