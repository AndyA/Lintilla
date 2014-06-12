package Lintilla::Site::Data;

use Moose;

use Dancer ':syntax';
use Dancer::Plugin::Database;
use Sphinx::Search;

use Lintilla::DB::Genome;
use Lintilla::Filter qw( cook );

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
  my ( $start, $size ) = @_;
  $size = MAX_PAGE if $size > MAX_PAGE;
  database->selectall_arrayref(
    "SELECT * FROM elvis_image WHERE hash IS NOT NULL ORDER BY seq ASC LIMIT ?, ?",
    { Slice => {} }, $start, $size
  );
}

sub search {
  my ( $start, $size, $query ) = @_;
  $size = MAX_PAGE if $size > MAX_PAGE;

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

prefix '/data' => sub {
  get '/services' => sub {
    Lintilla::DB::Genome->new( dbh => database )->services;
  };
  get '/years' => sub {
    Lintilla::DB::Genome->new( dbh => database )->years;
  };
  get '/programme/:uuid' => sub {
    Lintilla::DB::Genome->new( dbh => database )->programme( param('uuid') );
  };
  get '/ref/index' => sub {
    return [sort keys %REF];
  };
  get '/ref/:name' => sub {
    return refdata( param('name') );
  };
  get '/page/:size/:start' => sub {
    return cook assets => page( param('start'), param('size') );
  };
  get '/search/:size/:start' => sub {
    return cook assets =>
     search( param('start'), param('size'), param('q') );
  };
};

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
