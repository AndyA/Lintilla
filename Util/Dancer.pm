package Lintilla::Util::Dancer;

use strict;
use warnings;

use Dancer ':syntax';

use base qw( Exporter );

our @EXPORT_OK = qw( our_uri_for );
our %EXPORT_TAGS = ( all => [@EXPORT_OK] );

=head1 NAME

Lintilla::Util::Dancer - Dancer related utilities

=cut

sub our_uri_for {
  my $sn = delete request->env->{SCRIPT_NAME};
  my $uri = request->uri_for( join '/', '', @_ );
  request->env->{SCRIPT_NAME} = $sn;
  return $uri;
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
