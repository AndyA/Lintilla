package Lintilla::Broadcast::Role::Connection;

use Moose::Role;

use Socket qw(:all);

=head1 NAME

Lintilla::Broadcast::Role::Connection - Connection details

=cut

has port        => ( is => 'ro', required => 1,     default => 8924 );
has max_message => ( is => 'ro', isa      => 'Num', default => 8192 );

has _client_socket => (
  is        => 'ro',
  lazy      => 1,
  predicate => '_has_client_socket',
  builder   => '_b_client_socket',
);

has _server_socket => (
  is        => 'ro',
  lazy      => 1,
  predicate => '_has_server_socket',
  builder   => '_b_server_socket',
);

has _any_addr => (
  is      => 'ro',
  lazy    => 1,
  builder => '_b_any_addr',
);

has _broadcast_addr => (
  is      => 'ro',
  lazy    => 1,
  builder => '_b_broadcast_addr',
);

sub DEMOLISH {
  my $self = shift;
  close $self->_client_socket if $self->_has_client_socket;
  close $self->_server_socket if $self->_has_server_socket;
}

sub _udp_socket {
  my $self = shift;
  socket( my $sock, PF_INET, SOCK_DGRAM, getprotobyname('udp') )
   or die "Can't create socket $!";
  select( ( select($sock), $| = 1 )[0] );

  setsockopt( $sock, SOL_SOCKET, SO_BROADCAST, 1 )
   or die "setsockopt SO_BROADCAST: $!";

  return $sock;
}

sub _b_client_socket { shift->_udp_socket }

sub _b_server_socket {
  my $self = shift;
  my $sock = $self->_udp_socket;

  setsockopt( $sock, SOL_SOCKET, SO_REUSEADDR, 1 )
   or die "setsockopt SO_REUSEADDR: $!";

  return $sock;
}

sub _b_any_addr { sockaddr_in( shift->port, INADDR_ANY ) }

sub _b_broadcast_addr {
  sockaddr_in( shift->port, INADDR_BROADCAST );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
