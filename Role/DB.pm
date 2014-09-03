package Lintilla::Role::DB;

use Moose::Role;

=head1 NAME

Lintilla::Role::DB - Database trait

=cut

has dbh => ( is => 'ro', isa => 'DBI::db' );

sub transaction {
  my $self = shift;
  my $cb   = shift;
  my $dbh  = $self->dbh;
  $dbh->do('START TRANSACTION');
  eval { $cb->() };
  if ( my $err = $@ ) {
    $dbh->do('ROLLBACK');
    die $err;
  }
  $dbh->do('COMMIT');
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
