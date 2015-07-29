package Lintilla::DB::Genome::Search::Options;

use v5.10;

use Moose;

use List::Util qw( min max );
use Scalar::Util qw( looks_like_number );
use URI;

with 'Lintilla::Role::Gatherer';

=head1 NAME

Lintilla::DB::Genome::Search::Options - Parameters for searches

=cut

use constant PASSTHRU => qw(
 q order adv media yf yt tf tt co
 sun mon tue wed thu fri sat svc mf mt
);

# Based on ENUM values from DB
use constant SERVICE_TV    => 1;
use constant SERVICE_RADIO => 2;

has time_quantum => (
  is       => 'ro',
  isa      => 'Num',
  required => 1,
  default  => 15,
);

has start => ( is => 'ro', isa => 'Num', required => 1, default => 0 );
has size  => ( is => 'ro', isa => 'Num', required => 1, default => 20 );
has q     => ( is => 'ro', isa => 'Str', required => 1, default => '' );

has order => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
  default  => 'rank'
);

has mf => ( is => 'ro', isa => 'Num', default => 1 );
has mt => ( is => 'ro', isa => 'Num', default => 12 );
has yf => ( is => 'ro', default => 1923 );
has yt => ( is => 'ro', default => 2009 );

has ['tf', 'tt'] => ( is => 'ro', isa => 'Str', default => '00:00' );

has media => ( is => 'ro', isa => 'Str', default => 'all' );

has ['adv', 'co'] => ( is => 'ro', isa => 'Bool', default => 0 );

has svc => ( is => 'ro', isa => 'Maybe[Str]' );

has ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'] =>
 ( is => 'ro', isa => 'Bool', default => 0 );

has uri_format => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
  default  => '/search/%d/%d#search'
);

sub _uri {
  my ( $self, $page ) = @_;
  my $size = $self->size;
  return URI->new( sprintf $self->uri_format, $page * $size, $size );
}

sub _cmp {
  my ( $a, $b ) = @_;
  return 0 unless defined $a || defined $b;
  return -1 unless defined $a;
  return 1  unless defined $b;
  return $a cmp $b;
}

sub is_valid {
  my $self = shift;
  if ( $self->adv ) {
    return unless looks_like_number( $self->yf );
    return unless looks_like_number( $self->yt );
    return unless $self->yf <= $self->yt;
  }
  return 1;
}

sub form {
  my $self = shift;
  return { $self->gather(PASSTHRU) };
}

sub persist {
  my $self = shift;
  my $ref  = __PACKAGE__->new;
  my $form = $self->form;
  my $out  = {};
  while ( my ( $key, $vv ) = each %$form ) {
    my $dv = $ref->$key;
    $out->{$key} = $vv if defined $vv && _cmp( $vv, $dv );
  }
  return $out;
}

sub page {
  my $self = shift;
  return int( $self->start / $self->size );
}

sub page_link {
  my ( $self, $page ) = @_;
  my $uri = $self->_uri($page);
  $uri->query_form( $self->persist );
  return "$uri";
}

sub self_link {
  my $self = shift;
  return $self->page_link( $self->page );
}

sub order_link {
  my ( $self, $order ) = @_;
  my $uri = $self->_uri(0);
  my $p   = $self->persist;
  $p->{order} = $order;
  $uri->query_form($p);
  return "$uri";
}

sub service_link {
  my ( $self, @svc ) = @_;
  my $uri = $self->_uri(0);
  my $p   = $self->persist;
  if (@svc) { $p->{svc} = join ',', @svc }
  else      { delete $p->{svc} }
  $uri->query_form($p);
  return "$uri";
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

sub day_filter {
  my $self = shift;
  my @day  = qw( sun mon tue wed thu fri sat );
  my @set  = ();
  for my $idx ( 0 .. $#day ) {
    my $dn = $day[$idx];
    push @set, $idx + 1 if $self->$dn;
  }
  return @set;
}

sub month_filter {
  my $self = shift;
  my ( $mf, $mt ) = ( $self->mf, $self->mt );
  return if $mf < 1 || $mf > 12 || $mt < 1 || $mt > 12;
  return if $mf == 1 && $mt == 12;
  return ( $mt + 1, $mf - 1, 1 ) if $mt < $mf;
  return ( $mf, $mt, 0 );
}

sub time_filter {
  my $self = shift;
  my ( $tfs, $tts ) = ( $self->tfs, $self->tts );
  return if $tfs == $tts;
  return ( $tts, $tfs, 1 ) if $tts < $tfs;
  return ( $tfs, $tts, 0 );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
