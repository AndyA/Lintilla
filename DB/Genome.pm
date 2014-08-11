package Lintilla::DB::Genome;

use JSON;
use Moose;
use Sphinx::Search;

=head1 NAME

Lintilla::DB::Genome - Genome model

=cut

use constant YEAR_START => 1923;
use constant YEAR_END   => 2009;

with 'Lintilla::Role::Gatherer';

has dbh => ( is => 'ro', isa => 'DBI::db' );

has source => (
  is      => 'ro',
  default => '70ba6e0c-c493-42bd-8c64-c9f4be994f6d',
);

has years    => ( is => 'ro', lazy => 1, builder => '_build_years' );
has decades  => ( is => 'ro', lazy => 1, builder => '_build_decades' );
has services => ( is => 'ro', lazy => 1, builder => '_build_services' );

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

=head2 Reference Data

=cut

sub _build_services {
  my $self = shift;
  my $sql  = join ' ',
   'SELECT * FROM `genome_002`.`genome_services` ',
   'WHERE `_parent` IS NULL ',
   'ORDER BY `order` IS NULL, `order` ASC, `title` ASC';

  return $self->_group_by(
    $self->dbh->selectall_arrayref( $sql, { Slice => {} } ), 'type' );
}

sub _build_years {
  shift->dbh->selectcol_arrayref(
    'SELECT DISTINCT `year` FROM `genome_programmes_v2`'
     . ' WHERE `year` BETWEEN ? AND ? ORDER BY `year`',
    {}, YEAR_START, YEAR_END
  );
}

sub _build_decades {
  my $self = shift;
  my %dec  = ();
  $dec{ int( $_ / 10 ) * 10 }++ for @{ $self->years };
  return [sort { $a <=> $b } keys %dec];
}

sub _decade_years {
  my ( $self, $first, $last ) = @_;
  my ( $fd, $ld )
   = map { 10 * int( $_ / 10 ) } ( $first, $last );
  my @dy = ();
  for ( my $decade = $fd; $decade <= $ld; $decade += 10 ) {
    push @dy,
     {decade => sprintf( '%02d', $decade % 100 ),
      years  => [
        map { $_ >= $first && $_ <= $last ? $_ : undef }
         ( $decade .. $decade + 9 )
      ] };
  }
  return \@dy;
}

sub decade_years {
  my $self = shift;
  return $self->_decade_years( YEAR_START, YEAR_END );
}

=head2 Dynamic Data

=cut

sub programme {
  my ( $self, $uuid ) = @_;
  return $self->dbh->selectrow_hashref(
    'SELECT * FROM `genome_programmes_v2` WHERE `_uuid`=?',
    {}, $self->_format_uuid($uuid) );
}

sub service_defaults {
  my ( $self, $service, @got ) = @_;
  my $sql = join ' ',
   'SELECT sd.date, s._uuid, s.has_outlets',
   'FROM genome_service_dates AS sd, genome_services AS s',
   'WHERE sd.service=s._uuid AND s._key=?',
   'ORDER BY date LIMIT 1';
  my $rec = $self->dbh->selectrow_hashref( $sql, {}, $service );
  die unless defined $rec;
  # Simple case
  return ( $rec->{date} ) unless $rec->{has_outlets} eq 'Y';

  if ( @got < 1 ) {
    # Find default outlet
    my $outlet = join ' ',
     'SELECT subkey FROM genome_services',
     'WHERE _parent=?',
     'ORDER BY `order` IS NULL, `order` ASC, `title` ASC';
    my $orec = $self->dbh->selectrow_hashref( $outlet, {}, $rec->{_uuid} );
    push @got, $orec->{subkey};
  }

  push @got, $rec->{date} if @got < 2;
  return @got;
}

sub service_start_date {
  my ( $self, $service ) = @_;
  my $sql = join ' ',
   'SELECT sd.date',
   'FROM genome_service_dates AS sd, genome_services AS s',
   'WHERE sd.service=s._uuid AND s._key=?',
   'ORDER BY date LIMIT 1';
  return ( $self->dbh->selectrow_array( $sql, {}, $service ) )[0];
}

sub resolve_service {
  my ( $self, $service, @spec ) = @_;
  my $rec = $self->dbh->selectrow_hashref(
    join( ' ',
      'SELECT _uuid, has_outlets',
      'FROM genome_services',
      'WHERE _key=?',
      'LIMIT 1' ),
    {},
    $service
  );
  return $rec->{_uuid} unless $rec->{has_outlets} eq 'Y';
  die unless @spec;
  my @row
   = $self->dbh->selectrow_array(
    'SELECT _uuid FROM genome_services WHERE _parent=? AND subkey=?',
    {}, $rec->{_uuid}, $spec[0] );
  die unless @row;
  return $row[0];
}

sub decode_date {
  my ( $self, $date ) = @_;
  die unless $date =~ /^(\d+)-(\d+)-(\d+)/;
  return ( $1, $2, $3 );
}

sub decode_time {
  my ( $self, $time ) = @_;
  die unless $time =~ /(\d+):(\d+):(\d+)$/;
  return ( $1, $2, $3 );
}

sub clean_id {
  my ( $self, $uuid ) = @_;
  $uuid =~ s/-//g;
  return $uuid;
}

sub _add_programme_details {
  my ( $self, $rows ) = @_;
  my @uids = map { $_->{_uuid} } @$rows;
  my $sql
   = 'SELECT * FROM genome_contributors WHERE _parent IN ('
   . join( ', ', map '?', @uids )
   . ') ORDER BY _parent, `index` ASC';
  my $contrib
   = $self->dbh->selectall_arrayref( $sql, { Slice => {} }, @uids );
  my %by_parent = ();
  push @{ $by_parent{ $_->{_parent} }{ $_->{group} } }, $_ for @$contrib;
  for my $row (@$rows) {
    $row->{contrib} = $by_parent{ $row->{_uuid} } || [];
    $row->{time} = sprintf '%d.%02d', $self->decode_time( $row->{when} );
    $row->{link} = $self->clean_id( $row->{_uuid} );
  }
  return $rows;
}

sub listing_for_schedule {
  my ( $self, @spec ) = @_;

  my ( $year, $month, $day ) = $self->decode_date( pop @spec );
  my $service = $self->resolve_service(@spec);

  my $sql = join ' ',
   'SELECT * FROM genome_programmes_v2',
   'WHERE `source` = ?',
   'AND `service` = ?',
   'AND `year` = ?',
   'AND `month` = ?',
   'AND `day` = ?',
   'ORDER BY `when` ASC';

  my $rows = $self->dbh->selectall_arrayref( $sql, { Slice => {} },
    $self->source, $service, $year, $month, $day );

  return $self->_add_programme_details($rows);
}

sub stash {
  my ( $self, $name ) = @_;
  my @row
   = $self->dbh->selectrow_array(
    'SELECT stash FROM genome_stash WHERE name=?',
    {}, $name );
  return unless @row;
  return JSON->new->utf8->allow_nonref->decode( $row[0] );
}

=head2 Search

=cut

sub search {
  my ( $start, $size, $query ) = @_;
  #  $size = MAX_PAGE if $size > MAX_PAGE;

  my $sph = Sphinx::Search->new();
  $sph->SetMatchMode(SPH_MATCH_EXTENDED);
  $sph->SetSortMode(SPH_SORT_RELEVANCE);
  $sph->SetLimits( $start, $size );
  my $results = $sph->Query( $query, 'elvis_idx' );

  my $ids = join ', ', map { $_->{doc} } @{ $results->{matches} };
  my $sql
   = "SELECT * FROM elvis_image "
   . "WHERE acno IN ($ids) "
   . "ORDER BY FIELD(acno, $ids) ";

  database->selectall_arrayref( $sql, { Slice => {} } );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
