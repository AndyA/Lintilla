package Lintilla::Broadcast::Server;

use Moose;

use IO::Select;
use Socket qw(:all);

=head1 NAME

Lintilla::Broadcast::Server - Broadcast listener server

=cut

has _select => (
  is      => 'ro',
  lazy    => 1,
  builder => '_b_select',
);

with qw(
 Fenchurch::Core::Role::Logger
 Fenchurch::Core::Role::JSON
 Lintilla::Broadcast::Role::Connection
);

sub _b_select { IO::Select->new( shift->_server_socket ) }

sub listen {
  my $self = shift;

  my $sock = $self->_server_socket;
  my $addr = $self->_any_addr;

  bind( $sock, $addr ) or die "bind failed: $!\n";
  return $self;
}

sub poll {
  my ( $self, $timeout ) = @_;
  my $sel = $self->_select;
  my @r   = $sel->can_read($timeout);
  return unless @r;
  my $sock = $self->_server_socket;
  my $addr = recv( $sock, my $msg, $self->max_message, 0 );
  return $self->json_decode($msg);
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
