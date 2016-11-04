package Lintilla::Role::ErrorLog;

use Moose::Role;

use Genome::Sync::ErrorLog;

=head1 NAME

Lintilla::Role::ErrorLog - ErrorLog mixin

=cut

has error_log => (
  is      => 'ro',
  isa     => 'Genome::Sync::ErrorLog',
  lazy    => 1,
  builder => '_b_errorlog',
  handles => [qw( fatal error warn note debug )]
);

sub _b_errorlog { Genome::Sync::ErrorLog->new }

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
