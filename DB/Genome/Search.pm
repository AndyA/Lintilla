package Lintilla::DB::Genome::Search;

use List::Util qw( min max );
use Moose;
use Sphinx::Search;
use URI;

with 'Lintilla::Role::Gatherer';

=head1 NAME

Lintilla::DB::Genome::Search - A Genome search

=cut

use constant PASSTHRU => qw(
 q adv media yf yt tf tt co
 sun mon tue wed thu fri sat
);

has index => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
  default  => 'prog_idx',
);

has start => ( is => 'ro', isa => 'Num', required => 1, default => 0 );
has size  => ( is => 'ro', isa => 'Num', required => 1, default => 20 );
has q     => ( is => 'ro', isa => 'Str', required => 1, default => '' );

has yf => ( is => 'ro', isa => 'Num', default => 1923 );
has yt => ( is => 'ro', isa => 'Num', default => 2009 );

has ['tf', 'tt'] => ( is => 'ro', isa => 'Str', default => '00:00' );

has media => ( is => 'ro', isa => 'Str', default => 'all' );

has ['adv', 'co'] => ( is => 'ro', isa => 'Bool', default => 0 );

has ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'] =>
 ( is => 'ro', isa => 'Bool', default => 1 );

has search => ( is => 'ro', lazy => 1, builder => '_do_search' );

sub persist {
  my $self = shift;
  return { $self->gather(PASSTHRU) };
}

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
  $uri->query_form( q => $self->q );
  return "$uri";
}

sub pagination {
  my ( $self, $window ) = @_;
  my $cur   = $self->page;
  my $first = max( $cur - int( $window / 2 ), 0 );
  my $last  = min( $first + $window, $self->pages ) - 1;
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
    pages => [
      map {
        { page   => $_ + 1,
          link   => $self->page_link($_),
          offset => $_ - $cur,
        }
      } ( $first .. $last )
    ] };
}

sub _day_filter {
  my $self = shift;
  my @day  = qw( sun mon tue wed thu fri sat );
  my @set  = ();
  for my $idx ( 0 .. $#day ) {
    my $dn = $day[$idx];
    push @set, $idx + 1 if $self->$dn;
  }
  return \@set;
}

sub _do_search {
  my $self = shift;
  my $sph  = Sphinx::Search->new();
  $sph->SetMatchMode(SPH_MATCH_EXTENDED);
  $sph->SetSortMode(SPH_SORT_RELEVANCE);
  $sph->SetFieldWeights( { title => 2 } );

  if ( $self->adv ) {
    $sph->SetFilterRange( 'year', $self->yf, $self->yt );
#    $sph->SetFilterRange( 'weekday', $self->_day_filter );
  }

  $sph->SetLimits( $self->start, $self->size );
  return $sph->Query( $self->q, $self->index );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
