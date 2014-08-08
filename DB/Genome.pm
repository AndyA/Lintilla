package Lintilla::DB::Genome;

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

sub service_start_date {
  my ( $self, $service ) = @_;
  return (
    $self->dbh->selectrow_array(
      'SELECT MIN(`date`) FROM `genome_listings_v2` WHERE `service_key` = ?',
      {}, $service
    )
  )[0];
}

sub listing_for_schedule {
  my ( $self, $date, $service ) = @_;

  my $sql = join ' ',
   'SELECT l.*, i.*, ',
   'l.`_uuid` AS `_uuid`, ',
   'l.`_created` AS `_created`, ',
   'l.`_modified` AS `modified`, ',
   'l.`_key` AS `_key`, ', 'l.`issue` AS `issue`, ',
   'i.`_uuid` AS `issue_uuid`, ',
   'i.`_created` AS `issue_created`, ',
   'i.`_modified` AS `issue_modified`, ',
   'i.`_key` AS `issue_key`, ',
   'i.`_parent` AS `issue_parent`, ',
   'i.`issue` AS `issue_issue` ',
   'FROM `genome_listings_v2` AS l, `genome_issues` AS i ',
   'WHERE l.`source` = ? AND l.`service` = ? AND l.`date` = ? AND i.`_uuid` = l.`issue` ',
   'ORDER BY l.`issue_key` ASC, l.`page` ASC';

  my $rows = $self->dbh->selectall_arrayref( $sql, { Slice => {} },
    $self->source, $service, $date );

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
