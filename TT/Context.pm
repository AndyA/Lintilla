package Lintilla::TT::Context;

use strict;
use warnings;

use JSON ();
use HTML::Tiny;

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

sub _comment {
  my ( $self, $str ) = @_;
  my $h = HTML::Tiny->new;
  return join ' ', '<!--', $h->entity_encode($str), '-->';
}

sub process {
  my ( $self, $template, @args ) = @_;
  my $name   = $self->_get_template_name($template);
  my $args   = JSON->new->canonical->encode( \@args );
  my $output = $self->SUPER::process( $template, @args );
  return join( "\n",
    $self->_comment("[START[$name, $args]]"),
    $output, $self->_comment("[END[$name]]") );
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
