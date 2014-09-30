package Lintilla::Sync::Agent;

use Moose;

use LWP::UserAgent;
use URI;

=head1 NAME

Lintilla::Sync::Agent - Sync agent

=cut

has sync_base => ( is => 'ro', required => 1, isa => 'Str' );
has ['sync_user', 'sync_pass'] => ( is => 'ro', isa => 'Maybe[Str]' );
has _ua   => ( is => 'ro', lazy => 1, builder => '_b_ua', );
has _json => ( is => 'ro', lazy => 1, builder => '_b_json', );

sub _netloc {
  my $self = shift;
  my $u    = URI->new( $self->sync_base );
  return join ':', $u->host, $u->port;
}

sub _endpoint {
  my ( $self, @part ) = @_;
  ( my $base = $self->sync_base ) =~ s@/$@@;
  return join '/', $base, @part;
}

sub _b_ua {
  my $self = shift;
  my $ua   = LWP::UserAgent->new;
  $ua->credentials( $self->_netloc, 'RT Infax Bridge', $self->sync_user,
    $self->sync_pass );
  return $ua;
}

sub _b_json { JSON->new->utf8 }

sub get_changes {
  my ( $self, $since ) = @_;
  my $resp = $self->_ua->get( $self->_endpoint( changes => $since ) );
  die $resp->status_line if $resp->is_error;
  return $self->_json->decode( $resp->content );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
