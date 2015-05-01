package Lintilla::Role::DB;

use Moose::Role;

use Carp qw( confess );

=head1 NAME

Lintilla::Role::DB - Database trait

=cut

has dbh => ( is => 'ro', isa => 'DBI::db' );

has in_transaction => ( is => 'rw', isa => 'Bool', default => 0 );

sub transaction {
  my $self = shift;
  my $cb   = shift;
  if ( $self->in_transaction ) {
    $cb->();
  }
  else {
    my $dbh = $self->dbh;
    $dbh->do('START TRANSACTION');
    $self->in_transaction(1);
    eval { $cb->() };
    $self->in_transaction(0);
    if ( my $err = $@ ) {
      $dbh->do('ROLLBACK');
      confess $err;
    }
    $dbh->do('COMMIT');
  }
}

sub _group_by {
  my ( $self, $del, $rows, @keys ) = @_;
  return $rows unless @keys;
  my $leaf = pop @keys;
  my $hash = {};
  for my $row (@$rows) {
    my $rr   = {%$row};    # clone
    my $slot = $hash;
    if ($del) {
      $slot = ( $slot->{ delete $rr->{$_} } ||= {} ) for @keys;
      push @{ $slot->{ delete $rr->{$leaf} } }, $rr;
    }
    else {
      $slot = ( $slot->{ $rr->{$_} } ||= {} ) for @keys;
      push @{ $slot->{ $rr->{$leaf} } }, $rr;
    }
  }
  return $hash;

}

sub group_by { return shift->_group_by( 1, @_ ) }
sub stash_by { return shift->_group_by( 0, @_ ) }

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
