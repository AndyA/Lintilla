package Lintilla::Site::Data;

use Moose;

use Dancer ':syntax';
use Dancer::Plugin::Database;
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
  database->selectall_arrayref(
    "SELECT * FROM elvis_image WHERE hash IS NOT NULL ORDER BY seq ASC LIMIT ?, ?",
    { Slice => {} }, $start, $size
  );
}

sub jumble {
  my ( $seed, @list ) = @_;
  srand $seed;    # TODO are we depending on ranomness elsewhere?
  return shuffle @list;
}

sub random {
  my ( $size, $start, $seed ) = @_;
  $size = MAX_PAGE if $size > MAX_PAGE;
  my $ord = join ', ', jumble( $seed, map { "r.r$_" } 0 .. 7 );
  my $sql = join ' ',
   "SELECT i.* FROM elvis_image AS i, elvis_random AS r ",
   "WHERE i.hash IS NOT NULL AND i.acno=r.acno ORDER BY", $ord,
   "LIMIT ?, ?";

  database->selectall_arrayref( $sql, { Slice => {} }, $start, $size );
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
   = "SELECT * FROM elvis_image "
   . "WHERE acno IN ($ids) "
   . "ORDER BY FIELD(acno, $ids) ";

  database->selectall_arrayref( $sql, { Slice => {} } );
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
  get '/random/:size/:start/:seed' => sub {
    return cook assets =>
     random( param('size'), param('start'), param('seed') );
  };
  get '/search/:size/:start' => sub {
    return cook assets =>
     search( param('size'), param('start'), param('q') );
  };
};

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
