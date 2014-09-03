package Lintilla::Role::DB;

use Moose::Role;

=head1 NAME

Lintilla::Role::DB - Database trait

=cut

has dbh => ( is => 'ro', isa => 'DBI::db' );

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
