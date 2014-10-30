package Lintilla::DB::Genome::Stats;

use v5.10;

use Moose;

use Carp qw( confess );
use List::Util qw( sum );

=head1 NAME

Lintilla::DB::Genome::Stats - Access edit stats

=cut

with 'Lintilla::Role::DB';

use constant CHUNK   => 100;
use constant QUANTUM => 3600;

has states => (
  is      => 'ro',
  isa     => 'ArrayRef',
  lazy    => 1,
  builder => '_b_states',
);

has quantum => (
  is       => 'ro',
  isa      => 'Int',
  required => 1,
  default  => QUANTUM,
);

has _cache => ( is => 'ro', isa => 'HashRef', default => sub { {} } );

has limits => (
  is      => 'ro',
  isa     => 'HashRef',
  lazy    => 1,
  builder => '_b_limits'
);

sub _b_states {
  [ sort @{
      shift->dbh->selectcol_arrayref(
        'SELECT DISTINCT(`state`) FROM genome_editstats ORDER BY `state`') }
  ];
}

sub _b_limits {
  my $self = shift;
  my ( $min, $max )
   = $self->dbh->selectrow_array(
    'SELECT UNIX_TIMESTAMP(MIN(`slot`)), UNIX_TIMESTAMP(MAX(`slot`)) FROM genome_editstats'
   );
  my $quant = $self->_quantum;
  return {
    min => $self->_quantize( $min, $quant ),
    max => $self->_quantize( $max, $quant ) };
}

sub _quantize {
  my ( $self, $slot, $quantum ) = @_;
  $quantum //= $self->_quantum;
  return $quantum * int( $slot / $quantum );
}

sub _quantum {
  my $self = shift;
  my $qq = $self->_quantize( $self->quantum, QUANTUM );
  confess "Bad quantum" if $qq < QUANTUM;
  return $qq;
}

sub _by_slot {
  my ( $self, $rows ) = @_;
  my $out = {};
  for my $row (@$rows) {
    $out->{ $row->{slot} }{ $row->{state} } = $row->{count} * 1;
  }
  my %dflt = map { $_ => 0 } @{ $self->states };
  return [
    map {
      { slot  => $_ * 1,
        total => sum( values %{ $out->{$_} } ),
        %dflt,
        %{ $out->{$_} },
      }
    } sort { $a <=> $b } keys %$out
  ];
}

sub range {
  my ( $self, $from, $to ) = @_;

  my $quant = $self->_quantum;
  my $cache = $self->_cache;

  my @slot = map { $_ * $quant }
   int( $from / $quant ) .. int( ( $to - 1 ) / $quant );
  my @need = grep { !exists $cache->{$_} } @slot;

  while (@need) {
    my @chunk = splice @need, 0, CHUNK;
    my $in = join ', ', map { 'FROM_UNIXTIME(?)' } @chunk;
    my $batch = $self->_by_slot(
      $self->dbh->selectall_arrayref(
        join( ' ',
          'SELECT UNIX_TIMESTAMP(`slot`) AS `slot`, `state`, `count`',
          'FROM genome_editstats',
          "WHERE `slot` IN ($in)" ),
        { Slice => {} },
        @chunk
      )
    );
    $cache->{ $_->{slot} } = $_ for @$batch;
  }

  $cache->{$_}{slot} = $_ for @slot;    # Fill slot on missing items

  return [@{$cache}{@slot}];
}

sub columns { [@{ shift->states }, 'total'] }

sub delta {
  my ( $self, $from, $to ) = @_;
  my $range = $self->range( $from - $self->_quantum, $to );
  my $prev  = undef;
  my $cols  = $self->columns;
  my @out   = ();
  for my $row (@$range) {
    if ( defined $prev ) {
      my $rec = { slot => $row->{slot} };
      $rec->{$_} = ( $row->{$_} // 0 ) - ( $prev->{$_} // 0 ) for @$cols;
      push @out, $rec;
    }
    $prev = $row;
  }
  return \@out;
}

sub _as_series {
  my ( $self, $rows ) = @_;

  my %kk = ();
  %kk = ( %kk, %$_ ) for grep defined, @$rows;
  my $out = {};
  for my $key ( keys %kk ) {
    $out->{$key} = [map { $_->{$key} // 0 } @$rows];
  }
  return $out;
}

sub range_series {
  my $self = shift;
  return $self->_as_series( $self->range(@_) );
}

sub delta_series {
  my $self = shift;
  return $self->_as_series( $self->delta(@_) );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
