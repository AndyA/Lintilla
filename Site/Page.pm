package Lintilla::Site::Page;

use Dancer ':syntax';
use Lintilla::Image::PDF2PNG;
use Lintilla::Magic::Asset;
use Path::Class;

=head1 NAME

Lintilla::Site::Page - Serve pages extracted from PDF

=cut

=head3 Page handler

Given a request for

  /page/1940/1943/1009/1009/1.png

serves page 1 of

  /asset/1940/1943/1009/1009.pdf

=cut

sub our_uri_for {
  my $sn = delete request->env->{SCRIPT_NAME};
  my $uri = request->uri_for( join '/', '', @_ );
  request->env->{SCRIPT_NAME} = $sn;
  return $uri;
}

sub cook_uri {
  my $u = URI->new(shift);
  if ( defined( my $base_host = config->{base_host} ) ) {
    $u->host($base_host);
  }
  if ( defined( my $base_port = config->{base_port} ) ) {
    $u->port($base_port);
  }
  return $u;
}

get '/page/**' => sub {
  my ($path) = splat;

  my @loc = ( 'page', @$path );

  ( my $page = pop @$path ) =~ s/\.png$//;

  die "Bad page number"
   unless $page =~ /^\d+$/ && $page > 0 && $page < 500;

  my $out_file = file setting('public'), @loc;
  my $self = our_uri_for(@loc) . '?' . rand();

  my $pdf_url
   = cook_uri( our_uri_for( join( '/', 'asset', @$path ) . '.pdf' ) );

  my $p2p = Lintilla::Image::PDF2PNG->new(
    in_url   => $pdf_url,
    out_file => $out_file,
    page     => $page - 1
  );

  my $magic = Lintilla::Magic::Asset->new(
    filename => $out_file,
    timeout  => 60,
    provider => $p2p
  );

  $magic->render or die "Can't render";

  return redirect $self, 307;
};

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
