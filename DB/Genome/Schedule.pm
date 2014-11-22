package Lintilla::DB::Genome::Schedule;

use Moose;

use Dancer ':syntax';
use POSIX qw( strftime );
use Path::Class;

=head1 NAME

Lintilla::DB::Genome::Schedule - Build /labs/ schedule chunks

=cut

with 'Lintilla::Role::DB';
with 'Lintilla::Role::JSON';
with 'Lintilla::Role::Source';

has out_file => ( is => 'ro', required => 1 );
has slot => ( is => 'ro', isa => 'Int', required => 1 );
has size => (
  is       => 'ro',
  isa      => 'Int',
  required => 1,
  default  => 60 * 60 * 24 * 7
);

sub _sane {
  my $self  = shift;
  my $qslot = int( $self->slot / $self->size ) * $self->size;
  die "Bad schedule slot" unless $self->slot == $qslot;
}

sub _sql_date { strftime '%Y-%m-%d', gmtime $_[1] }

sub _programmes_for_slot {
  my ( $self, $slot, $size ) = @_;

  my $progs = $self->dbh->selectall_arrayref(
    join( ' ',
      'SELECT `_uuid`, `service`, `title`, `when`',
      'FROM genome_programmes_v2',
      'WHERE `source`=?',
      'AND `date` BETWEEN ? AND ?',
      'ORDER BY `when` ASC' ),
    { Slice => {} },
    $self->source,
    $self->_sql_date($slot),
    $self->_sql_date( $slot + $size - 1 )
  );

  return $progs;
}

sub _load_services {
  my ( $self, $kf, @ids ) = @_;

  my $services = $self->dbh->selectall_arrayref(
    join( ' ',
      'SELECT',
      '  s._uuid, ',
      '  s.type AS service_type,',
      '  s._key AS service_key,',
      '  s2._key AS parent_key,',
      '  s._uuid AS service_uuid,',
      '  s2._uuid AS parent_uuid,',
      '  s.title AS service_name,',
      '  s2.title AS service_sub,',
      '  s.subkey AS subkey,',
      '  s.data AS stash',
      'FROM genome_services AS s',
      'LEFT JOIN genome_services AS s2 ON s2._uuid = s._parent',
      "WHERE s.$kf IN (",
      join( ', ', map '?', @ids ),
      ')' ),
    { Slice => {} },
    @ids
  );

  for my $svc (@$services) {
    $svc->{data} = $self->_decode_wide( delete $svc->{stash} )
     if defined $svc->{stash};

    $svc->{name} = join ' ', grep defined,
     @{$svc}{ 'service_sub', 'service_name' };
    $svc->{root_key} = $svc->{parent_key} // $svc->{service_key};
    $svc->{outlet} = join '/', grep defined, $svc->{root_key},
     $svc->{subkey};
    $svc->{_key} = $svc->{service_key};
  }

  return $services;
}

sub _services_for_uuids {
  my ( $self, @uuids ) = @_;

  my $services
   = $self->group_by( $self->_load_services( _uuid => @uuids ), '_uuid' );

  debug 'services: ', $services;

  for my $uuid ( keys %$services ) {
    my $svcs = $services->{$uuid};
    next unless $svcs->[0]{service_type} eq 'pseudo';
    $services->{$uuid}
     = $self->_load_services( _key => @{ $svcs->[0]{data}{incorporates} } );
  }

  return $services;
}

sub _unique(@) {
  my %seen = ();
  grep { !$seen{$_}++ } @_;
}

sub _data_for_slot {
  my ( $self, $slot, $size ) = @_;

  my $progs = $self->_programmes_for_slot( $slot, $size );
  my @svc_uuids        = _unique( map { $_->{service} } @$progs );
  my $services         = $self->_services_for_uuids(@svc_uuids);
  my $progs_by_service = $self->group_by( $progs, 'service' );

  my $stash = {};
  for my $uuid (@svc_uuids) {
    $stash->{$uuid} = {
      services   => delete $services->{$uuid},
      programmes => delete $progs_by_service->{$uuid} };
  }

  return $stash;
}

sub create_week {
  my $self = shift;
  $self->_sane;
  my $fh = file( $self->out_file )->openw;
  print $fh $self->_encode(
    $self->_data_for_slot( $self->slot, $self->size ) );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
