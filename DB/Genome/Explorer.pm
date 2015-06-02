package Lintilla::DB::Genome::Explorer;

use Moose;

use DateTime;
use DateTime::Format::MySQL;
use POSIX qw( floor );

=head1 NAME

Lintilla::DB::Genome::Explorer - Schedule explorer data

=cut

with 'Lintilla::Role::DB';
with 'Lintilla::Role::UUID';
with 'Lintilla::Role::JSON';
with 'Lintilla::Role::Source';

use constant DAY     => 24 * 60 * 60;
use constant WEEK    => DAY * 7;
use constant CHUNK   => 100;
use constant QUANTUM => WEEK * CHUNK;

sub epoch_to_chunk {
  my ( $self, $ts ) = @_;
  floor( $ts / QUANTUM );
}

sub chunk_to_epoch {
  my ( $self, $chunk ) = @_;
  QUANTUM * $chunk;
}

sub date_to_epoch {
  my ( $self, $date ) = @_;
  DateTime::Format::MySQL->parse_date($date)->epoch;
}

sub epoch_to_date {
  my ( $self, $ts ) = @_;
  DateTime::Format::MySQL->format_date(
    DateTime->from_epoch( epoch => $ts ) );
}

sub date_to_chunk {
  my ( $self, $date ) = @_;
  $self->epoch_to_chunk( $self->date_to_epoch($date) );
}

sub chunk_to_date {
  my ( $self, $chunk ) = @_;
  $self->epoch_to_date( $self->chunk_to_epoch($chunk) );
}

sub services {
  shift->dbh->selectall_arrayref( 'SELECT * FROM `genome_services`',
    { Slice => {} } );
}

sub service_spans {
  my $self = shift;

  my $rc = $self->dbh->selectall_arrayref(
    join( ' ',
      'SELECT `service`, MIN(`date`) AS `start_date`, MAX(`date`) AS `end_date`',
      'FROM `genome_listings_v2`',
      'WHERE `source` = ?',
      'GROUP BY `service`' ),
    { Slice => {} },
    $self->source
  );

  for my $row (@$rc) {
    $row->{start_chunk} = $self->date_to_chunk( $row->{start_date} );
    $row->{end_chunk}   = $self->date_to_chunk( $row->{end_date} );
  }

  return $rc;
}

sub service_info {
  my $self = shift;

  my $svc = $self->services;
  my $spans = $self->group_by( $self->service_spans, 'service' );

  for my $row (@$svc) {
    my $sp = delete $spans->{ $row->{_uuid} };
    $row->{spans} = $sp->[0];
  }

  return $svc;
}

sub service_chunk {
  my ( $self, $uuid, $chunk ) = @_;

  my $min_date = $self->chunk_to_date($chunk);
  my $max_date = $self->chunk_to_date( $chunk + 1 );

  my $rc = $self->dbh->selectall_arrayref(
    join( ' ',
      'SELECT `listing`, `_uuid`, `title`, `when`, `duration`',
      'FROM `genome_programmes_v2`',
      'WHERE `broadcast_date` >= ? AND `broadcast_date` < ?',
      '  AND `service` = ?',
      'ORDER BY `when`' ),
    { Slice => {} },
    $min_date,
    $max_date,
    $self->format_uuid($uuid)
  );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
