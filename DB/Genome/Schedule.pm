package Lintilla::DB::Genome::Schedule;

use Moose;

use Dancer ':syntax';
use POSIX qw( strftime );
use Path::Class;
use Time::Local;

=head1 NAME

Lintilla::DB::Genome::Schedule - Build /labs/ schedule chunks

=cut

with 'Lintilla::Role::DB';
with 'Lintilla::Role::UUID';
with 'Lintilla::Role::JSON';
with 'Lintilla::Role::Source';

use constant DAY => 60 * 60 * 24;

has out_file => ( is => 'ro', required => 1 );
has slot     => ( is => 'ro', isa      => 'Str' );
has size     => (
  is       => 'ro',
  isa      => 'Int',
  required => 1,
  default  => 7
);

sub _parse_date {
  die "Bad date" unless $_[1] =~ /^(\d\d\d\d)-?(\d\d)-?(\d\d)$/;
  my ( $y, $m, $d ) = ( $1, $2, $3 );
  return timegm 0, 0, 0, $d, $m - 1, $y;
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

  return [] unless @ids;

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

sub _date_range {
  my $self = shift;
  my ( $min, $max )
   = map { $self->_sql_date( $self->_quantise( $self->_parse_date($_) ) ) }
   $self->dbh->selectrow_array(
    'SELECT MIN(`date`), MAX(`date`) FROM genome_programmes_v2');
  s/-//g for $min, $max;
  return { min => $min, max => $max, step => $self->size };
}

sub _span { shift->size * DAY }

sub _quantise {
  my ( $self, $epoch ) = @_;
  my $offset = DAY * 365 * 100;
  my $span   = $self->_span;
  return int( ( $epoch + $offset ) / $span ) * $span - $offset;
}

sub _range {
  my $self  = shift;
  my $slot  = $self->_parse_date( $self->slot );
  my $qslot = $self->_quantise($slot);
  die "Quantised up!" if $qslot > $slot;
  die "Bad slot" unless $slot == $qslot;
  return ( $slot, $self->_span );
}

sub _create_json {
  my ( $self, $data ) = @_;
  my $out_file = $self->out_file;
  my $tmp_file = "$out_file.tmp.json";
  my $fh       = file($tmp_file)->openw;
  print $fh $self->_encode($data);
  rename $tmp_file, $out_file or die $!;
}

sub create_week {
  my $self = shift;
  $self->_create_json( $self->_data_for_slot( $self->_range ) );
}

sub create_range {
  my $self = shift;
  $self->_create_json( $self->_date_range );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
