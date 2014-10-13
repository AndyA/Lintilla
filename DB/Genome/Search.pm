package Lintilla::DB::Genome::Search;

use v5.10;

use Dancer qw( config );
use List::Util qw( min max );
use Moose;
use Sphinx::Search;
use URI;

with 'Lintilla::Role::Gatherer';

no if $] >= 5.018, warnings => "experimental::smartmatch";

=head1 NAME

Lintilla::DB::Genome::Search - A Genome search

=cut

use constant MAX_MATCHES => 20_000;

use constant PASSTHRU => qw(
 q order adv media yf yt tf tt co
 sun mon tue wed thu fri sat svc mf mt
);

# Based on ENUM values from DB
use constant SERVICE_TV    => 1;
use constant SERVICE_RADIO => 2;

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

has time_quantum => (
  is       => 'ro',
  isa      => 'Num',
  required => 1,
  default  => 15,
);

has start => ( is => 'ro', isa => 'Num', required => 1, default => 0 );
has size  => ( is => 'ro', isa => 'Num', required => 1, default => 20 );
has q     => ( is => 'ro', isa => 'Str', required => 1, default => '' );

has order =>
 ( is => 'ro', isa => 'Str', required => 1, default => 'rank' );

has mf => ( is => 'ro', isa => 'Num', default => 1 );
has mt => ( is => 'ro', isa => 'Num', default => 12 );
has yf => ( is => 'ro', isa => 'Num', default => 1923 );
has yt => ( is => 'ro', isa => 'Num', default => 2009 );

has ['tf', 'tt'] => ( is => 'ro', isa => 'Str', default => '00:00' );

has media => ( is => 'ro', isa => 'Str', default => 'all' );

has ['adv', 'co'] => ( is => 'ro', isa => 'Bool', default => 0 );

has svc => ( is => 'ro', isa => 'Maybe[Str]' );

has ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'] =>
 ( is => 'ro', isa => 'Bool', default => 0 );

has _sphinx => ( is => 'ro', lazy => 1, builder => '_build_sphinx' );
has _search => ( is => 'ro', lazy => 1, builder => '_do_search' );

sub _cmp {
  my ( $a, $b ) = @_;
  return 0 unless defined $a || defined $b;
  return -1 unless defined $a;
  return 1  unless defined $b;
  return $a cmp $b;
}

sub form {
  my $self = shift;
  return { $self->gather(PASSTHRU) };
}

sub persist {
  my $self = shift;
  my $ref  = __PACKAGE__->new;
  my $out  = {};
  for my $key (PASSTHRU) {
    my $dv = $ref->$key;
    my $vv = $self->$key;
    $out->{$key} = $vv if defined $vv && _cmp( $vv, $dv );
  }
  return $out;
}

sub total { shift->search->{total_found} // 0 }

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
  $uri->query_form( $self->persist );
  return "$uri";
}

sub order_link {
  my ( $self, $order ) = @_;
  my $uri = URI->new( sprintf '/search/%d/%d', 0, $self->size );
  my $p = $self->persist;
  $p->{order} = $order;
  $uri->query_form($p);
  return "$uri";
}

sub service_link {
  my ( $self, @svc ) = @_;
  my $uri = URI->new( sprintf '/search/%d/%d', 0, $self->size );
  my $p = $self->persist;
  if (@svc) { $p->{svc} = join ',', @svc }
  else      { delete $p->{svc} }
  $uri->query_form($p);
  return "$uri";
}

sub pagination {
  my ( $self, $window ) = @_;
  my $cur   = $self->page;
  my $first = max( $cur - int( $window / 2 ), 0 );
  my $last  = min( $first + $window, $self->pages ) - 1;
  my $from  = $self->start + 1;
  my $to    = min( $from + $self->size - 1, $self->total );
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
    order => { map { $_ => $self->order_link($_) } qw( rank asc desc ) },
    info  => { from => $from, to => $to },
    pages => [
      map {
        { page   => $_ + 1,
          link   => $self->page_link($_),
          offset => $_ - $cur,
        }
      } ( $first .. $last )
    ],
    ( defined $self->svc ? ( all => $self->service_link ) : () ),
  };
}

sub timelist {
  my $self  = shift;
  my $quant = $self->time_quantum;
  my @tm    = ();
  for ( my $td = 0; $td < 24 * 60; $td += $quant ) {
    push @tm, sprintf '%02d:%02d', int( $td / 60 ), $td % 60;
  }
  return \@tm;
}

sub _parse_seconds {
  my ( $self, $tm ) = @_;
  die unless $tm =~ /^(\d+):(\d+)$/;
  return ( $1 * 60 + $2 ) * 60;
}

sub tfs { my $self = shift; return $self->_parse_seconds( $self->tf ) }
sub tts { my $self = shift; return $self->_parse_seconds( $self->tt ) }

sub _day_filter {
  my $self = shift;
  my @day  = qw( sun mon tue wed thu fri sat );
  my @set  = ();
  for my $idx ( 0 .. $#day ) {
    my $dn = $day[$idx];
    push @set, $idx + 1 if $self->$dn;
  }
  @set = ( 1 .. 7 ) unless @set;
  return \@set;
}

sub _month_filter {
  my $self = shift;
  my ( $mf, $mt ) = ( $self->mf, $self->mt );
  return if $mf < 1 || $mf > 12 || $mt < 1 || $mt > 12;
  return if $mf == 1 && $mt == 12;
  return ( $mt + 1, $mf - 1, 1 ) if $mt < $mf;
  return ( $mf, $mt, 0 );
}

sub _time_filter {
  my $self = shift;
  my ( $tfs, $tts ) = ( $self->tfs, $self->tts );
  return if $tfs == $tts;
  return ( $tts, $tfs, 1 ) if $tts < $tfs;
  return ( $tfs, $tts, 0 );
}

sub _set_filter {
  my ( $self, $sph ) = @_;
  $sph->SetFilter( source => [$self->source] );

  if ( $self->adv ) {
    $sph->SetFilterRange( year => $self->yf, $self->yt );
    $sph->SetFilter( weekday => $self->_day_filter );
    my @mfilt = $self->_month_filter;
    $sph->SetFilterRange( month => @mfilt ) if @mfilt;
    my @tfilt = $self->_time_filter;
    $sph->SetFilterRange( timeslot => @tfilt ) if @tfilt;
    given ( $self->media ) {
      when ('all')   { }
      when ('tv')    { $sph->SetFilter( service_type => [SERVICE_TV] ) }
      when ('radio') { $sph->SetFilter( service_type => [SERVICE_RADIO] ) }
      default        { die }
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
  return unless length $self->q;
  if ( $self->adv ) {
    return unless $self->yf <= $self->yt;
  }
  return 1;
}

sub _do_search {
  my $self = shift;

  return { qq => {}, svc => {}, kws => [] }
   unless $self->_is_valid;

  my $sph = $self->_sphinx;
  $sph->Open;
  $sph->SetMatchMode(SPH_MATCH_EXTENDED);
  $sph->SetSortMode(SPH_SORT_RELEVANCE);
  $sph->SetFieldWeights( { title => 2 } );

  $self->_set_filter($sph);

  if ( defined( my $svc = $self->svc ) ) {
    $sph->SetFilter( 'service_id', [split /,/, $svc] );
  }

  given ( $self->order ) {
    when ('rank') { }
    when ('asc')  { $sph->SetSortMode( SPH_SORT_ATTR_ASC, 'when' ) }
    when ('desc') { $sph->SetSortMode( SPH_SORT_ATTR_DESC, 'when' ) }
    default       { die }
  }

  $sph->SetLimits( $self->start, $self->size, MAX_MATCHES );

  my $query
   = $self->adv && $self->co
   ? '@people "' . $self->q . '"'
   : $self->q;

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
