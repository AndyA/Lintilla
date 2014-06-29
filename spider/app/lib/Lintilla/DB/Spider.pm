package Lintilla::DB::Spider;

use Moose;

use Dancer ':syntax';
use Dancer::Plugin::Database;
use Sphinx::Search;

=head1 NAME

Lintilla::DB::Spider - Spider model

=cut

with 'Lintilla::Role::Gatherer';

has dbh => ( is => 'ro', isa => 'DBI::db' );

use constant INDEX => 'spider_idx';

=head2 Search

=cut

sub _lookup {
  my ( $self, @matches ) = @_;

  return [] unless @matches;

  my $ids = join ', ', map { $_->{doc} } @matches;
  my $sql
   = "SELECT * FROM spider_page AS pa, spider_plain AS pl "
   . "WHERE pl.url_hash = pa.url_hash AND pl.id IN ($ids) "
   . "ORDER BY FIELD(id, $ids) ";

  return database->selectall_arrayref( $sql, { Slice => {} } );
}

sub search {
  my ( $self, $start, $size, $query ) = @_;
  #  $size = MAX_PAGE if $size > MAX_PAGE;

  my $sph = Sphinx::Search->new();
  $sph->SetMatchMode(SPH_MATCH_EXTENDED);
  $sph->SetSortMode(SPH_SORT_RELEVANCE);
  $sph->SetLimits( $start, $size );
  my $results = $sph->Query( $query, INDEX );

  return {
    results => $results,
    matches => $self->_lookup( @{ $results->{matches} } ),
  };
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
