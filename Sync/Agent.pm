package Lintilla::Sync::Agent;

use Moose;

use LWP::UserAgent;
use URI;

=head1 NAME

Lintilla::Sync::Agent - Sync agent

=cut

has sync_base => ( is => 'ro', required => 1, isa => 'Str' );
has ['sync_user', 'sync_pass'] => ( is => 'ro', isa => 'Maybe[Str]' );

has _ua => (
  is      => 'ro',
  isa     => 'LWP::UserAgent',
  lazy    => 1,
  builder => '_b_ua',
);

sub _netloc {
  my $self = shift;
  my $u    = URI->new( $self->sync_base );
  return join ':', $u->host, $u->port;
}

sub _b_ua {
  my $self = shift;
  my $ua   = LWP::UserAgent->new;
  $ua->credentials( $self->_netloc, 'Genome Sync', $self->sync_user,
    $self->sync_pass );
}

sub get_changes {
  my ( $self, $since ) = @_;
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
