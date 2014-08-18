package Lintilla::DB::Genome::Search;

use List::Util qw( min max );
use Moose;
use Sphinx::Search;
use URI;

=head1 NAME

Lintilla::DB::Genome::Search - A Genome search

=cut

has ['start', 'size'] => ( is => 'ro', isa => 'Num', required => 1 );

has ['query', 'index'] => ( is => 'ro', isa => 'Str', required => 1 );

has search => ( is => 'ro', lazy => 1, builder => '_do_search' );

sub total { shift->search->{total_found} }

sub pages {
  my $self = shift;
  return int( ( $self->total + $self->size - 1 ) / $self->size );
}

sub page {
  my $self = shift;
  return int( $self->start / $self->size );
}

sub page_link {
  my ( $self, $page ) = @_;
  return if $page < 0 || $page >= $self->pages;
  my $uri
   = URI->new( sprintf '/search/%d/%d', $page * $self->size, $self->size );
  $uri->query_form( q => $self->query );
  return "$uri";
}

sub pagination {
  my ( $self, $window ) = @_;
  my $cur   = $self->page;
  my $first = max( $cur - int( $window / 2 ), 0 );
  my $last  = min( $first + $window, $self->pages ) - 1;
  return [
    map {
      { page   => $_ + 1,
        link   => $self->page_link($_),
        offset => $_ - $cur,
      }
    } ( $first .. $last )
  ];
}

sub _do_search {
  my $self = shift;
  my $sph  = Sphinx::Search->new();
  $sph->SetMatchMode(SPH_MATCH_EXTENDED);
  $sph->SetSortMode(SPH_SORT_RELEVANCE);
  $sph->SetLimits( $self->start, $self->size );
  return $sph->Query( $self->query, $self->index );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
