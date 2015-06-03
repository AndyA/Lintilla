package Lintilla::DB::Genome::Explorer;

use Moose;

use DateTime;
use DateTime::Format::MySQL;
use POSIX qw( floor );

use Lintilla::Util::Flatpack qw( flatpack );

=head1 NAME

Lintilla::DB::Genome::Explorer - Schedule explorer data

=cut

with 'Lintilla::Role::DB';
with 'Lintilla::Role::UUID';
with 'Lintilla::Role::JSON';
with 'Lintilla::Role::Source';

sub _uniq_group {
  my ( $self, $grp ) = @_;
  for ( values %$grp ) {
    die unless 1 == @$_;
    $_ = $_->[0];
  }
  return $grp;
}

sub service_info {
  my $self = shift;

  my $rc = $self->dbh->selectall_arrayref(
    join( ' ',
      'SELECT s.*,',
      '    MIN(sd.`date`) AS `start_date`,',
      '    MAX(sd.`date`) AS `end_date`,',
      '    MIN(sd.`year`) AS `start_year`,',
      '    MAX(sd.`year`) AS `end_year`,',
      '    SUM(sd.`count`) AS `count`',
      '  FROM `genome_services` AS s',
      '  LEFT JOIN `labs_service_dates` AS sd',
      '    ON sd.`service` = s.`_uuid`',
      ' GROUP BY s.`_uuid`' ),
    { Slice => {} }
  );

  my %by_key = map { $_->{_key} => $_->{_uuid} } @$rc;
  for my $svc (@$rc) {
    my $data = $self->_decode_php_object( $svc->{data} );
    $data->{incorporates}
     = [map { $by_key{$_} // die "No service for $_" }
       @{ $data->{incorporates} }]
     if $data && $data->{incorporates};
    $svc->{data} = $data;
  }

  return $self->_uniq_group( $self->group_by( $rc, '_uuid' ) );
}

sub service_years {
  my ( $self, $uuid ) = @_;

  return $self->dbh->selectall_arrayref(
    join( ' ',
      'SELECT `year`,',
      '    MIN(`date`) AS start_date,',
      '    MAX(`date`) AS end_date,',
      '    SUM(`count`) AS `count`',
      '  FROM `labs_service_dates`',
      ' WHERE `service` = ?',
      ' GROUP BY `year`',
      ' ORDER BY `year`' ),
    { Slice => {} },
    $self->format_uuid($uuid)
  );
}

sub service_year {
  my ( $self, $uuid, $year ) = @_;

  my $rc = $self->dbh->selectall_arrayref(
    join( ' ',
      'SELECT `listing`, `_uuid`, `title`, `when`, `duration`',
      '  FROM `genome_programmes_v2`',
      ' WHERE `year` = ?',
      '   AND `service` = ?',
      '   AND `source` = ?',
      ' ORDER BY `when`' ),
    { Slice => {} },
    $year,
    $self->format_uuid($uuid),
    $self->source
  );

  $_->{duration} *= 1 for @$rc;

  return flatpack $rc;
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
