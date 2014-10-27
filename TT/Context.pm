package Lintilla::TT::Context;

use strict;
use warnings;

use JSON ();

=head1 NAME

Lintilla::TT::Context - Subclass and twiddle with Template::Context

=cut

use base qw( Template::Context );

sub _get_template_name {
  my ( $self, $template ) = @_;
  return $template unless ref $template;
  return $template->{name} if exists $template->{name};
  return "*** UNKNOWN ***";
}

sub process {
  my ( $self, $template, @args ) = @_;
  my $name   = $self->_get_template_name($template);
  my $args   = JSON->new->canonical->encode( \@args );
  my $output = $self->SUPER::process( $template, @args );
  return join "\n", "<!-- [START[$name, $args]] -->", $output,
   "<!-- [END[$name]] -->";
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
