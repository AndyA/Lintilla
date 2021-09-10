package Lintilla::Util::Dancer;

use strict;
use warnings;

use Dancer ':syntax';
use URI;
use URI::QueryParam;

use base qw( Exporter );

our @EXPORT_OK   = qw( our_uri_for cache_bust );
our %EXPORT_TAGS = ( all => [@EXPORT_OK] );

=head1 NAME

Lintilla::Util::Dancer - Dancer related utilities

=cut

sub _our_uri_for {
  my $sn   = delete request->env->{SCRIPT_NAME};
  my $path = join '/', '', @_;
  $path =~ s!^//!/!;
  my $uri = request->uri_for($path);
  request->env->{SCRIPT_NAME} = $sn;
  return $uri;
}

sub our_uri_for {
  my $uri = _our_uri_for(@_);

  # public_uri override
  my $public_uri        = config->{public_uri};
  my $public_uri_scheme = config->{public_uri_scheme};

  if ( defined $public_uri ) {
    my $pu = URI->new($public_uri);
    $pu->path_query( $uri->path_query );
    return $pu;
  }

  if ( defined $public_uri_scheme ) {
    my $pu = URI->new($uri);
    $pu->scheme($public_uri_scheme);
    return $pu;
  }

  return $uri;

}

sub cache_bust {
  my $uri = URI->new( $_[0] );
  $uri->query_param_append( cache_bust => rand );
  return $uri;
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
