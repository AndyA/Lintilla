package Lintilla::Role::DB;

use Moose::Role;

use Carp qw( confess );
use Encode qw( encode );
use JSON;

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
  return $rows unless @keys;
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

sub _json { JSON->new->utf8->allow_nonref->canonical }

sub _encode {
  my ( $self, $data ) = @_;
  return $self->_json->encode($data);
}

sub _decode {
  my ( $self, $data ) = @_;
  return $self->_json->decode( encode( 'UTF-8', $data ) );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
