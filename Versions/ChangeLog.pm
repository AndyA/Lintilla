package Lintilla::Versions::ChangeLog;

use v5.10;

use Moose;
use Storable qw( freeze );

=head1 NAME

Lintilla::Versions::ChangeLog - Construct versions from changelog, data

=cut

with 'Lintilla::Role::ErrorLog';

has data => ( is => 'ro', isa => 'HashRef',  required => 1 );
has log  => ( is => 'ro', isa => 'ArrayRef', required => 1 );

has data_version => (
  is       => 'ro',
  isa      => 'Int',
  required => 1,
  lazy     => 1,
  builder  => '_d_data_version'
);

has ['_min_version', '_max_version'] => (
  is       => 'rw',
  isa      => 'Int',
  required => 1,
  lazy     => 1,
  builder  => '_b_min_max'
);

has _version_cache => (
  is      => 'ro',
  isa     => 'ArrayRef',
  lazy    => 1,
  builder => '_b_version_cache'
);

has _sane => (
  is      => 'ro',
  isa     => 'Bool',
  lazy    => 1,
  builder => '_b_sane'
);

sub _d_data_version { shift->length }
sub _b_min_max      { shift->data_version }

sub _b_version_cache {
  my $self = shift;
  my $vc   = [];
  $vc->[$self->length]       = undef;
  $vc->[$self->data_version] = $self->_patch( $self->data );
  return $vc;
}

sub _eq {
  my ( $a, $b ) = @_;
  return 1 unless defined $a || defined $b;
  return 0 unless defined $a && defined $b;
  return $a eq $b unless ref $a || ref $b;
  return 0 unless ref $a && ref $b && ref $a eq ref $b;
  local $Storable::canonical = 1;
  return freeze($a) eq freeze($b);
}

# Deep comparison but don't consider missing keys to be a mismatch
sub _deep_eq {
  my ( $a, $b ) = @_;
  return _eq( $a, $b ) unless ref $a && ref $b;
  return 0 unless ref $a eq ref $b;

  if ( 'ARRAY' eq ref $a ) {
    my $la = $#$a;
    my $lb = $#$b;
    return 0 unless $la == $lb;
    for my $i ( 0 .. $la ) {
      return 0 unless _deep_eq( $a->[$i], $b->[$i] );
    }
    return 1;
  }

  if ( 'HASH' eq ref $a ) {
    while ( my ( $k, $v ) = each %$a ) {
      return 0 if exists $b->{$k} && !_deep_eq( $v, $b->{$k} );
    }
    return 1;
  }

  return 0;
}

sub _b_sane {
  my $self = shift;
  my (%cur);

  for my $ev ( @{ $self->log } ) {
    unless ( _deep_eq( \%cur, $ev->{old_data} ) ) {
      $self->error( 'changelog.sanity', 'History',
        "new_data <=> old_data mismatch, new_data: ",
        \%cur, ', old_data: ', $ev->{old_data} );
    }
    %cur = ( %cur, %{ $ev->{new_data} } );
  }

  my $data = $self->data;
  my $dv   = $self->data_version;
  my $log  = $self->log;
  my $ref  = $dv == 0 ? $log->[0]{old_data} : $log->[$dv - 1]{new_data};

  unless ( _deep_eq( $ref, $data ) ) {
    $self->error( 'changelog.sanity', 'Record Data',
      "data <=> patch mismatch, data: ",
      $data, ', patch: ', $ref );
  }

  return !$self->error_log->at_least('ERROR');
}

sub _check_sane { shift->_sane || confess "Inconsitent state" }

sub _patch {
  my ( $self, @patch ) = @_;
  return { map { %$_ } @patch };
}

sub _make_version {
  my ( $self, $version ) = @_;
  my $vc  = $self->_version_cache;
  my $log = $self->log;
  if ( $version < $self->_min_version ) {
    my $data = $vc->[$self->_min_version];
    for ( my $ver = $self->_min_version - 1; $ver >= $version; $ver-- ) {
      $vc->[$ver] = $data = $self->_patch( $data, $log->[$ver]{old_data} );
    }
    $self->_min_version($version);
  }
  elsif ( $version > $self->_max_version ) {
    my $data = $vc->[$self->_max_version];
    for ( my $ver = $self->_max_version + 1; $ver <= $version; $ver++ ) {
      $vc->[$ver] = $data = $self->_patch( $data, $log->[$ver - 1]{new_data} );
    }
    $self->_max_version($version);
  }
  else {
    confess "Asked for $version which we should have";
  }
}

sub length { scalar @{ shift->log } }

sub at {
  my ( $self, $version ) = @_;
  $self->_check_sane;
  confess "Version out of range"
   if $version < 0 || $version > $self->length;
  my $vc = $self->_version_cache;
  $self->_make_version($version) unless defined $vc->[$version];
  return $vc->[$version];
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
