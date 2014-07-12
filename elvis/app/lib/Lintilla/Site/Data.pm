package Lintilla::Site::Data;

use Moose;

use Dancer ':syntax';
use Dancer::Plugin::Database;
use Geo::WKT;
use Sphinx::Search;

use Lintilla::Filter qw( cook );

use List::Util qw( shuffle );

=head1 NAME

Lintilla::Data - Data handlers

=cut

use constant MAX_PAGE => 500;

my %REF = map { $_ => 1 } qw(
 collection copyright_class copyright_holder format kind location
 news_restriction personality photographer subject
);

sub fix_lat_long {
  my $rs = shift;
  for my $rec (@$rs) {
    my $loc = delete $rec->{location};
    next unless $loc;
    my $pt = parse_wkt_point($loc);
    next unless $pt;
    @{$rec}{ 'latitude', 'longitude' } = $pt->latlong;
  }
  return $rs;
}

sub refdata {
  my $name = shift;
  die "Bad refdata name $name" unless $REF{$name};
  my $ref
   = database->selectall_hashref( "SELECT id, name FROM elvis_$name",
    'id' );
  $_ = $_->{name} for values %$ref;
  return $ref;
}

sub page {
  my ( $size, $start ) = @_;
  $size = MAX_PAGE if $size > MAX_PAGE;
  fix_lat_long(
    database->selectall_arrayref(
      "SELECT i.*, AsText(c.location) AS location FROM elvis_image AS i "
       . "LEFT JOIN elvis_coordinates AS c ON i.acno=c.acno "
       . "WHERE hash IS NOT NULL "
       . "ORDER BY seq ASC LIMIT ?, ?",
      { Slice => {} },
      $start,
      $size
    )
  );
}

sub by {
  my ( $size, $start, $field, $value ) = @_;
  $size = MAX_PAGE if $size > MAX_PAGE;
  return [] unless $field =~ /^\w+$/ && $REF{$field};
  fix_lat_long(
    database->selectall_arrayref(
      "SELECT i.*, AsText(c.location) AS location FROM elvis_image AS i "
       . "LEFT JOIN elvis_coordinates AS c ON i.acno=c.acno "
       . "WHERE hash IS NOT NULL AND `${field}_id` = ? LIMIT ?, ?",
      { Slice => {} },
      $value,
      $start,
      $size
    )
  );
}

sub search {
  my ( $size, $start, $query ) = @_;
  $size = MAX_PAGE if $size > MAX_PAGE;

  my $sph = Sphinx::Search->new();
  $sph->SetMatchMode(SPH_MATCH_EXTENDED);
  $sph->SetSortMode(SPH_SORT_RELEVANCE);
  $sph->SetLimits( $start, $size );
  my $results = $sph->Query( $query, 'elvis_idx' );

  my @ids = map { $_->{doc} } @{ $results->{matches} };
  return [] unless @ids;
  my $ids = join ', ', @ids;
  my $sql
   = "SELECT i.*, AsText(c.location) AS location FROM elvis_image AS i "
   . "LEFT JOIN elvis_coordinates AS c ON i.acno=c.acno "
   . "WHERE i.acno IN ($ids) "
   . "ORDER BY FIELD(i.acno, $ids) ";

  fix_lat_long( database->selectall_arrayref( $sql, { Slice => {} } ) );
}

sub bbox_to_polygon {
  wkt_polygon(
    [$_[1], $_[0]],
    [$_[3], $_[0]],
    [$_[3], $_[2]],
    [$_[1], $_[2]],
    [$_[1], $_[0]]
  );
}

sub region {
  my ( $size, $start, @bbox ) = @_;

  $size = MAX_PAGE if $size > MAX_PAGE;
  my $sql = join ' ',
   "SELECT i.*, AsText(c.location) AS location FROM elvis_image AS i, elvis_coordinates AS c",
   "WHERE i.acno=c.acno",
   "AND Contains(GeomFromText(?), c.location)",
   "LIMIT ?, ?";

  return fix_lat_long(
    database->selectall_arrayref(
      $sql, { Slice => {} },
      bbox_to_polygon(@bbox), $start, $size
    )
  );
}

sub keywords {
  my @acno = @_;
  my @bad = grep { !/^\d+$/ } @acno;
  die "Bad acno: ", join( ', ', @bad ) if @bad;
  my $sql = join ' ',
   'SELECT ik.acno, k.id, k.name, COUNT(ik2.acno) AS freq',
   'FROM elvis_keyword AS k, elvis_image_keyword AS ik, elvis_image_keyword AS ik2',
   'WHERE ik.acno IN (', join( ', ', map { "?" } @acno ), ')',
   'AND ik.id=k.id',
   'AND ik2.id=k.id',
   'GROUP BY ik2.id',
   'ORDER BY acno, freq DESC';
  my $rs = database->selectall_arrayref( $sql, { Slice => {} }, @acno );
  my $by_acno = {};
  for my $row (@$rs) {
    my $acno = delete $row->{acno};
    push @{ $by_acno->{$acno} }, $row;
  }
  return $by_acno;
}

sub tag {
  my ( $size, $start, $id ) = @_;
  $size = MAX_PAGE if $size > MAX_PAGE;
  fix_lat_long(
    database->selectall_arrayref(
      "SELECT i.*, AsText(c.location) AS location FROM elvis_image AS i "
       . "LEFT JOIN elvis_coordinates AS c ON i.acno=c.acno, "
       . "elvis_image_keyword AS ik "
       . "WHERE hash IS NOT NULL AND ik.acno=i.acno AND ik.id=? LIMIT ?, ?",
      { Slice => {} },
      $id,
      $start,
      $size
    )
  );
}

prefix '/data' => sub {
  get '/ref/index' => sub {
    return [sort keys %REF];
  };
  get '/ref/:name' => sub {
    return refdata( param('name') );
  };
  get '/page/:size/:start' => sub {
    return cook assets => page( param('size'), param('start') );
  };
  get '/tag/:size/:start/:id' => sub {
    return cook assets => tag( param('size'), param('start'), param('id') );
  };
  get '/keywords/:acnos' => sub {
    return cook keywords => keywords( split /,/, param('acnos') );
  };
  get '/search/:size/:start' => sub {
    return cook assets =>
     search( param('size'), param('start'), param('q') );
  };
  get '/by/:size/:start/:field/:value' => sub {
    return cook assets =>
     by( param('size'), param('start'), param('field'), param('value') );
  };
  get '/region/:size/:start/:bbox' => sub {
    return cook assets =>
     region( param('size'), param('start'), split /,/, param('bbox') );
  };
};

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
