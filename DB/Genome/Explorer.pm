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

sub service_info {
  my $self = shift;

  my $rc = $self->dbh->selectall_arrayref(
    join( ' ',
      'SELECT s.*,',
      '    MIN(sd.`date`) AS `start_date`,',
      '    MAX(sd.`date`) AS `end_date`,',
      '    MIN(sd.`year`) AS `start_year`,',
      '    MAX(sd.`year`) AS `end_year`,',
      '    SUM(sd.`count`) AS `programmes`',
      '  FROM `labs_service_dates` AS sd, genome_services AS s',
      ' WHERE sd.`service` = s.`_uuid`',
      ' GROUP BY sd.`service`' ),
    { Slice => {} }
  );

  $_->{data} = $self->_decode_wide( $_->{data} ) for @$rc;

  return $rc;
}

sub service_year {
  my ( $self, $uuid, $year ) = @_;

  my $rc = $self->dbh->selectall_arrayref(
    join( ' ',
      'SELECT `listing`, `_uuid`, `title`, `when`, `duration`',
      '  FROM `genome_programmes_v2`',
      ' WHERE `year` = ?',
      '   AND `service` = ?',
      ' ORDER BY `when`' ),
    { Slice => {} },
    $year,
    $self->format_uuid($uuid)
  );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
