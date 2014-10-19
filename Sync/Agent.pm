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
  $ua->credentials(
    $self->_netloc,   'RT Infax Bridge',
    $self->sync_user, $self->sync_pass
  ) if defined $self->sync_user || defined $self->sync_pass;
  return $ua;
}

sub _b_json { JSON->new->utf8 }

sub _decode {
  my ( $self, $resp ) = @_;
  die $resp->status_line, $resp->content if $resp->is_error;
  return $self->_json->decode( $resp->content );
}

sub _cb {
  my ( $self, $uri ) = @_;
  my $u = URI->new($uri);
  my $q = $u->query_form;
  $q->{_cb} = time();
  $u->query_form($q);
  return "$u";
}

sub _get {
  my $self = shift;
  $self->_decode( $self->_ua->get( $self->_cb( $self->_endpoint(@_) ) ) );
}

sub _post {
  my ( $self, @part ) = @_;
  my $data = pop @part;
  my $uri  = $self->_endpoint(@part);
  my $body = $self->_json->encode($data);
  my $req  = HTTP::Request->new( 'POST', $uri );
  $req->header( 'Content-Type' => 'application/json' );
  $req->content($body);
  return $self->_decode( $self->_ua->request($req) );
}

sub get_changes {
  my ( $self, $since ) = @_;
  return $self->_get( changes => $since );
}

sub get_history {
  my ( $self, $since ) = @_;
  return $self->_get( history => $since );
}

sub put_edits {
  my ( $self, $edits ) = @_;
  return $self->_post( 'edits', $edits );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
