package Lintilla::Tools::Role::EditDB;

use Moose::Role;

=head1 NAME

Lintilla::Tools::Role::EditDB - do something

=cut

has edit_db => (
  is      => 'ro',
  isa     => 'Lintilla::DB::Genome::Edit',
  handles => [qw( dbh transaction group_by )]
);

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
