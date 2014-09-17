package Lintilla::Broadcast::Client;

use Moose;

use Socket qw(:all);

=head1 NAME

Lintilla::Broadcast::Client - Broadcast sender client

=cut

with 'Lintilla::Role::JSON';
with 'Lintilla::Broadcast::Role::Connection';

sub send {
  my ( $self, $msg ) = @_;

  my $enc = $self->_encode($msg);
  die "Message too large" if length $msg > $self->max_message;

  send( $self->_client_socket, $enc, 0, $self->_broadcast_addr )
   or die "Message send failed: $!";
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
