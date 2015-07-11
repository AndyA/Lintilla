package Lintilla::DB::Genome::Search::Sphinx;

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

Lintilla::DB::Genome::Search::Sphinx - A Sphinx search

=cut

use constant MAX_MATCHES => 20_000;

has index => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
  default  => 'prog_idx',
);

has source => (
  is       => 'ro',
  required => 1,
  default  => 1,
);

has options => (
  is       => 'ro',
  isa      => 'Lintilla::DB::Genome::Search::Options',
  required => 1
);

has _sphinx => ( is => 'ro', lazy => 1, builder => '_build_sphinx' );
has _search => ( is => 'ro', lazy => 1, builder => '_do_search' );

sub total { shift->search->{total_found} // 0 }

sub _day_filter {
  my $self = shift;
  my @df   = $self->options->day_filter;
  return [1 .. 7] unless @df;
  return \@df;
}

sub _set_filter {
  my ( $self, $sph ) = @_;

  my $opt = $self->options;

  $sph->SetFilter( source => [$self->source] );

  if ( $opt->adv ) {
    $sph->SetFilterRange( year => $opt->yf, $opt->yt );
    $sph->SetFilter( weekday => $self->_day_filter );
    my @mfilt = $opt->month_filter;
    $sph->SetFilterRange( month => @mfilt ) if @mfilt;
    my @tfilt = $opt->time_filter;
    $sph->SetFilterRange( timeslot => @tfilt ) if @tfilt;
    given ( $opt->media ) {
      when ('all') { }
      when ('tv') {
        $sph->SetFilter( service_type => [$opt->SERVICE_TV] );
      }
      when ('radio') {
        $sph->SetFilter( service_type => [$opt->SERVICE_RADIO] );
      }
      when ('playable') {
        $sph->SetFilter( has_media => [1] );
      }
      default {
        die;
      }
    }
  }
}

sub _build_sphinx {
  my $self = shift;
  my $sph  = Sphinx::Search->new();

  my $host = config->{sphinx_host} // 'localhost';
  my $port = config->{sphinx_port} // '9312';

  $sph->SetServer( $host, $port );
}

sub _is_valid {
  my $self = shift;
  my $opt  = $self->options;
  return unless length $opt->q || config->{empty_search};
  if ( $opt->adv ) {
    return unless looks_like_number( $opt->yf );
    return unless looks_like_number( $opt->yt );
    return unless $opt->yf <= $opt->yt;
  }
  return 1;
}

sub _do_search {
  my $self = shift;
  my $opt  = $self->options;

  return { qq => {}, svc => {}, kws => [] }
   unless $self->_is_valid;

  my $sph = $self->_sphinx;
  $sph->Open;
  $sph->SetMatchMode(SPH_MATCH_EXTENDED);
  $sph->SetSortMode(SPH_SORT_RELEVANCE);
  $sph->SetFieldWeights( { title => 2 } );

  $self->_set_filter($sph);

  if ( defined( my $svc = $opt->svc ) ) {
    $sph->SetFilter( 'service_id', [split /,/, $svc] );
  }

  given ( $opt->order ) {
    when ('rank') { }
    when ('asc')  { $sph->SetSortMode( SPH_SORT_ATTR_ASC, 'when' ) }
    when ('desc') { $sph->SetSortMode( SPH_SORT_ATTR_DESC, 'when' ) }
    default       { die }
  }

  $sph->SetLimits( $opt->start, $opt->size, MAX_MATCHES );

  my $query
   = $opt->adv && $opt->co
   ? '@people "' . $opt->q . '"'
   : $opt->q;

  my $qq = $sph->Query( $query, $self->index );
  die $sph->GetLastError unless $qq;
  my $kws = $sph->BuildKeywords( $query, $self->index, 0 );
  die $sph->GetLastError unless $kws;

  $sph->ResetFilters;
  $self->_set_filter($sph);

  # Enumerate services
  $sph->SetSelect('service_id');
  $sph->SetGroupBy( 'service_id', SPH_GROUPBY_ATTR, 'service_id asc' );
  $sph->SetGroupDistinct('service_id');
  $sph->SetLimits( 0, 1000 );
  my $svc = $sph->Query( $query, $self->index );
  die $sph->GetLastError unless $svc;

  $sph->Close;

  return { qq => $qq, svc => $svc, kws => $kws };
}

sub search   { shift->_search->{qq} }
sub services { shift->_search->{svc} }

sub keyword_map {
  my $self = shift;
  my $kws  = $self->_search->{kws};
  return { map { $_->{normalized} => $_->{tokenized} } @$kws };
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
