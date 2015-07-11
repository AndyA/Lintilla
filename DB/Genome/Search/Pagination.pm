package Lintilla::DB::Genome::Search::Pagination;

use v5.10;

use Dancer qw( config );
use List::Util qw( min max );
use Moose;

use Scalar::Util qw( looks_like_number );
use Sphinx::Search;
use URI;

with 'Lintilla::Role::Gatherer';

no if $] >= 5.018, warnings => "experimental::smartmatch";

=head1 NAME

Lintilla::DB::Genome::Search::Pagination - Results pagination

=cut

has options => (
  is       => 'ro',
  isa      => 'Lintilla::DB::Genome::Search::Options',
  required => 1
);

has window => (
  is      => 'ro',
  isa     => 'Num',
  default => 10
);

has total => (
  is       => 'ro',
  isa      => 'Num',
  required => 1
);

sub pages {
  my $self = shift;
  my $opt  = $self->options;
  return int( ( $self->total + $opt->size - 1 ) / $opt->size );
}

sub page_link {
  my ( $self, $page ) = @_;
  return if $page < 0 || $page >= $self->pages;
  return $self->options->page_link($page);
}

sub pagination {
  my $self = shift;

  my $window = $self->window;
  my $opt    = $self->options;
  my $cur    = $opt->page;
  my $first  = max( $cur - int( $window / 2 ), 0 );
  my $last   = min( $first + $window, $self->pages ) - 1;
  my $from   = $opt->start + 1;
  my $to     = min( $from + $opt->size - 1, $self->total );

  return {
    ( $cur > 0
      ? (
        prev => {
          page   => $cur,
          link   => $self->page_link( $cur - 1 ),
          offset => -1,
        }
       )
      : ()
    ),
    ( $cur < $self->pages - 1
      ? (
        next => {
          page   => $cur + 2,
          link   => $self->page_link( $cur + 1 ),
          offset => 1,
        }
       )
      : ()
    ),
    order => { map { $_ => $opt->order_link($_) } qw( rank asc desc ) },
    info  => { from => $from, to => $to },
    pages => [
      map {
        { page   => $_ + 1,
          link   => $self->page_link($_),
          offset => $_ - $cur,
        }
      } ( $first .. $last )
    ],
    ( defined $opt->svc ? ( all => $opt->service_link ) : () ),
  };
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
