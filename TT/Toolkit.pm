package Lintilla::TT::Toolkit;

use v5.10;

use strict;
use warnings;

use Lintilla::TT::Context;

=head1 NAME

Lintilla::TT::Toolkit - Overide TT

=cut

use Lintilla::TT::Context;

use base qw( Template );

=for later

sub new {
  my $class = shift;
  $Template::Config::CONTEXT = 'Lintilla::TT::Context';
  #  my $config = shift // {};
  #  $config->{CONTEXT} = Lintilla::TT::Context->new;
  #  use Data::Dumper;
  #  print Dumper($config);
  my $self = $class->SUPER::new(@_);
  return bless $self, $class;
}

=cut

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
