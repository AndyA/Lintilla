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

sub format_uuid {
  my ( $self, $uuid ) = @_;
  return join '-', $1, $2, $3, $4, $5
   if $uuid =~ /^ ([0-9a-f]{8}) -?
                  ([0-9a-f]{4}) -?
                  ([0-9a-f]{4}) -?
                  ([0-9a-f]{4}) -?
                  ([0-9a-f]{12}) $/xi;
  die "Bad UUID";
}

sub strip_uuid {
  my ( $self, $uuid ) = @_;
  # Format to validate
  ( my $stripped = $self->format_uuid($uuid) ) =~ s/-//g;
  return $stripped;
}

sub is_uuid {
  my ( $self, $str ) = @_;
  return $str =~ /^ ([0-9a-f]{8}) -
                    ([0-9a-f]{4}) -
                    ([0-9a-f]{4}) -
                    ([0-9a-f]{4}) -
                    ([0-9a-f]{12}) $/xi;
}

sub group_by {
  my ( $self, $rows, @keys ) = @_;
  my $leaf = pop @keys;
  my $hash = {};
  for my $row (@$rows) {
    my $rr   = {%$row};    # clone
    my $slot = $hash;
    $slot = ( $slot->{ delete $rr->{$_} } ||= {} ) for @keys;
    push @{ $slot->{ delete $rr->{$leaf} } }, $rr;
  }
  return $hash;
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
