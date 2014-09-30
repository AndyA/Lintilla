package Lintilla::Personality;

use Moose;

use URI;

=head1 NAME

Lintilla::Personality - Determine site personality from hostname

=cut

has url     => ( is => 'ro', required => 1 );
has rules   => ( is => 'ro', isa      => 'ArrayRef', required => 1 );
has default => ( is => 'ro', default  => 'external' );

has _host_map => ( is => 'ro', lazy => 1, builder => '_b_host_map' );
has _current  => ( is => 'ro', lazy => 1, builder => '_b_current' );

has personality => (
  is      => 'ro',
  lazy    => 1,
  builder => '_b_personality',
);

has switcher => (
  is      => 'ro',
  lazy    => 1,
  builder => '_b_switcher',
);

sub _wild {
  my ( $self, $wild ) = @_;
  my $re = join '\.', map { $_ eq '*' ? '.+' : quotemeta $_ } split /\./,
   $wild;
  return qr{^$re$};
}

sub _b_current {
  my $self = shift;
  my $host = $self->_uri->host;
  for my $rule ( @{ $self->rules } ) {
    my $for = $rule->{for};
    for my $hp ( ref $for ? @$for : $for ) {
      my $re = $self->_wild($hp);
      return $rule->{rules} if $host =~ $re;
    }
  }
  die "Can't map $host to a rule";
}

sub _b_host_map {
  my $self = shift;
  my $rev  = {};
  while ( my ( $personality, $host ) = each %{ $self->_current } ) {
    $rev->{$_} = $personality for ref $host ? @$host : $host;
  }
  return $rev;
}

sub _uri { URI->new( shift->url ) }

sub _b_personality {
  my $self = shift;
  my $hm   = $self->_host_map;
  my $u    = $self->_uri;
  return $hm->{ $u->host } // $self->default;
}

sub _b_switcher {
  my $self = shift;

  my $r = $self->rules;

  my $switcher = {};

  while ( my ( $personality, $host ) = each %{ $self->_current } ) {
    my $u = $self->_uri;
    $u->host( ref $host ? $host->[0] : $host );
    $switcher->{$personality} = "$u";
  }

  return $switcher;
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
