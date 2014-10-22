package Lintilla::Tools::Role::ErrorLog;

use Moose::Role;

use Lintilla::Sync::ErrorLog;

=head1 NAME

Lintilla::Tools::Role::ErrorLog - ErrorLog mixin

=cut

has error_log => (
  is      => 'ro',
  isa     => 'Lintilla::Sync::ErrorLog',
  lazy    => 1,
  builder => '_b_errorlog',
  handles => [qw( fatal error warn note debug )]
);

sub _b_errorlog { Lintilla::Sync::ErrorLog->new }

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
