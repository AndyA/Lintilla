package Lintilla::DB::Genome;

use Moose;

=head1 NAME

Lintilla::DB::Genome - Genome model

=cut

has dbh => ( is => 'ro', isa => 'DBI::db' );

sub _format_uuid {
  my ( $self, $uuid ) = @_;
  return join '-', $1, $2, $3, $4, $5
   if $uuid =~ /^ ([0-9a-f]{8}) -?
                  ([0-9a-f]{4}) -?
                  ([0-9a-f]{4}) -?
                  ([0-9a-f]{4}) -?
                  ([0-9a-f]{12}) $/xi;
  die "Bad UUID";
}

sub _strip_uuid {
  my ( $self, $uuid ) = @_;
  # Format to validate
  ( my $stripped = $self->_format_uuid($uuid) ) =~ s/-//g;
  return $stripped;
}

sub _group_by {
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

sub services {
  my $self = shift;
  return $self->_group_by(
    $self->dbh->selectall_arrayref(
      'SELECT title, type, _uuid AS uuid FROM genome_services ORDER BY title',
      { Slice => {} }
    ),
    'type'
  );
}

sub programme {
  my ( $self, $uuid ) = @_;
  return $self->dbh->selectrow_hashref(
    'SELECT * FROM genome_programmes_v2 WHERE _uuid=?',
    {}, $self->_format_uuid($uuid) );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
